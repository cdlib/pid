require 'uri'
require 'net/http'

class PidException < Exception
end

class PidVersion < ActiveRecord::Base
  belongs_to :pid

  validates :deactivated, inclusion: { in: [true, false] } # presence: true
  validates :change_category, presence: true, length: { maximum: 20 }, format: { with: /[a-zA-Z_]+/ }
  validates :url, presence: true, length: { maximum: 2000 }, format: { with: URI::DEFAULT_PARSER.make_regexp }
  validates :username, presence: true, length: { maximum: 20 }, format: { with: /[a-z]{3,20}/ }
  validates :group, length: { maximum: 20 }
  validates :created_at, presence: true
  validates :notes, length: { maximum: 250 }
  validates :host, length: { maximum: 30 }
end

class Pid < ActiveRecord::Base
  has_many :pid_versions
  has_many :interesteds
  belongs_to :group
  belongs_to :invalid_url_report, optional: true
  belongs_to :duplicate_url_report, optional: true

  validates :deactivated, inclusion: { in: [true, false] } # TODO: Default value false, index, db migration?
  validates :change_category, presence: true, length: { maximum: 20 }, format: { with: /[a-zA-Z_]+/ }
  validates :url, presence: true, length: { maximum: 2000 }, format: { with: URI::DEFAULT_PARSER.make_regexp }
  validates :username, presence: true, length: { maximum: 50 }, format: { with: /[a-z\s]{3,50}/ }
  validates :created_at, presence: true # TODO: Index
  validates :modified_at, presence: true # TODO: Index
  validates :notes, length: { maximum: 250 }
  validates :host, length: { maximum: 30 }

  before_save :check_mutable
  before_update :check_mutable
  before_destroy :prevent_destroy

  attr_accessor :mutable

  @@shorty = Shortcake.new('pid', { host: PidApp::APP_CONFIG['redis_host'], port: PidApp::APP_CONFIG['redis_port'], ssl: PidApp::APP_CONFIG['redis_use_ssl'] })

  def revise(params)
    begin
      current_attributes = self.attributes.clone.transform_keys(&:to_sym)
      # If we're seeding, it's okay for the modified_at to come through as a param
      # When merging, the argument hash overrides values for matching keys in current_attributes hash.

      if !params[:notes].nil? && params[:notes].empty?
        params[:notes] = nil
      end
      
      if params[:is_seed]
        params = current_attributes.merge(params)
      else
        params = current_attributes.merge({ notes: nil}.merge(params)).except(:modified_at, :created_at)
      end
      
      Pid.create_or_update(params)
  
    rescue Exception => e
      raise e
    end
  end  

  def self.create_or_update(params)
    is_seed = params[:is_seed].present? ? params[:is_seed] : false
    dead_pid_url = params[:dead_pid_url]
    params.delete(:is_seed)
    params.delete(:dead_pid_url)

    ActiveRecord::Base.transaction do
      begin
        now = Time.now

        # If an ID was specified, then we're updating or inserting (if this is the DB seed)
        if params[:id]
          pid = find_by(id: params[:id])

          # If we're seeding the DB and the ID doesn't exist
          if pid.nil? && is_seed
            pid = new(params)
          # If we're not seeding and the ID is missing, exit
          elsif pid.nil?
            return nil
          # Otherwise we're updating, so set the modified_at to now
          else
            revise_params = {
              change_category: params[:change_category],
              url: params[:url],
              username: params[:username],
              notes: params[:notes],
              deactivated: params[:deactivated],
              group: params[:group]
            }
            pid.attributes = revise_params.merge(modified_at: is_seed ? params[:modified_at] : now)
          end
        # Otherwise we're creating a new PID
        else
          pid = new(params.merge(created_at: now, modified_at: now))
          params = params.merge(pid.attributes.transform_keys(&:to_sym))
        end

        pid.mutable = true

        if pid.valid?
          pid.save!
          @@shorty.create_or_update(pid.id.to_s, (pid.deactivated ? dead_pid_url : pid.url.to_s))
        else
          raise Exception.new("Failure saving Pid: #{pid.errors.full_messages.join('\n')}")
        end

        pid.mutable = false

        # Save the version
        version_params = {
          pid: pid,
          change_category: params[:change_category],
          url: params[:url],
          username: params[:username],
          notes: params[:notes],
          deactivated: params[:deactivated],
          group: params[:group].id
        }

        ver = if is_seed
                PidVersion.new(version_params.merge(created_at: pid.modified_at))
              else
                PidVersion.new(version_params.merge(created_at: now))
              end

        # If the version has errors that are not just "Pid must not be blank" (happens with a new PID record), raise an exception
        if (ver.errors.count == 1 && ver.errors.full_messages.first != "Pid must not be blank") || ver.errors.count > 1
          raise Exception.new("Failure saving version: #{ver.errors.full_messages.join('\n')}")
        else
          ver.save!
        end

        pid
      rescue Exception => e
        raise PidException, e.message
      end
    end
  end
  
  def verify_url
    skip = false
  
    # Make sure the domain isn't designated as one we cannot scan
    SkipCheck.find_each { |it| skip = true if url.downcase.include?(it.domain.downcase) }
  
    if !skip
      begin
        # Test to make sure this is a valid URL
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.open_timeout = 5 # seconds
        http.read_timeout = 5 # seconds

        request = Net::HTTP::Get.new(uri)
        response = http.request(request)

        if response.code.to_i >= 300 && response.code.to_i != 302
          self.invalid_url_report = InvalidUrlReport.create(http_code: response.code.to_i, last_checked: Time.now)
        else
          self.invalid_url_report = nil
        end
  
        self.mutable = true
        self.save
        self.mutable = false
  
        response.code.to_i
  
      rescue Exception => e
        msg = "Failure verifying URL #{e.message} - #{url}"
        $stdout.puts msg
        404
      end
    else
      200
    end
  end
  
  def self.mint(params)
    Pid.create_or_update(params)
  end

  def self.flush!
    Pid.flush_shortcake!
    Pid.flush_db!
  end

  def self.flush_shortcake!
    @@shorty.flushall!
  end

  def self.flush_db!
    # ActiveRecord::Base.connection.tables.each do |table_name|  
    #   ActiveRecord::Base.connection.execute("DELETE FROM #{table_name}")
    # end
    require_relative '../db/migrate/reset_database.rb'
    migration = CreateTables.new
    migration.down
    migration.up
  end

  def self.reconcile
    Pid.count == @@shorty.dbsize
  end

  def self.shorty
    @@shorty
  end
  
  private

  def check_mutable
    # Restriction for saving and updating. Ensure handling through create_or_update for shortcake syncing.
    throw(:abort) unless mutable
  end

  def prevent_destroy
    # Pids are immutable, so prevent destroying.
    throw(:abort)
  end
end
