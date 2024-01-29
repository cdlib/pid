require 'csv'

class PidApp < Sinatra::Base
# -------------------------------------------------------------------------------------------------------------- 
# Dead PID page
# --------------------------------------------------------------------------------------------------------------  
  get '/link/dead' do    
    @hide_nav = true
    erb :dead_pid
  end
  
  get '/link/inactive' do
    @hide_nav = true
    erb :dead_pid
  end
  
# ---------------------------------------------------------------
# Display the new PID form
# ---------------------------------------------------------------  
  get '/link/new' do
    @failures = {}
    @successes = []
    @interested = []
    @dead_urls = []
    erb :new_pid
  end
  
# ---------------------------------------------------------------
# Display the PIDs search form
# ---------------------------------------------------------------
  get '/link/search' do
    @json = [].to_json
    @params = get_search_defaults({})
  
    @params[:pid_low] = ""
    @params[:pid_high] = ""
  
    @params[:created_low] = ""
    @params[:created_high] = ""
  
    @params[:modified_low] = ""
    @params[:modified_high] = ""
  
    @has_interesteds = !Interested.find_by(group: current_user.group).nil?
  
    erb :search_pid
  end  
  
# ---------------------------------------------------------------
# Display the batch edit page
# ---------------------------------------------------------------  
  get '/link/edit' do
    @failures = [] 
    @mints = [] 
    @revisions = []
    @interested = []
    @dead_urls = []
    
    erb :edit_pid
  end

# ---------------------------------------------------------------
# Display the specified purl
# ---------------------------------------------------------------
  get '/link/:id' do
    @pid = Pid.find_by(id: params[:id])
  
    if @pid
      @groups = current_user.super ? Group.all.to_a : []

      unless current_user.super
        # Maintainer.where(user: current_user).each { |maintain| @groups << maintain.group } 
        Group.joins(:maintainers).where(maintainers: { user_id: current_user.id }).each { |group| @groups << group }
      end
      
      @group = current_user.group
  
      @interested = Interested.where(pid: @pid)
  
      @is_owner = current_user.group == @pid.group
      @is_owner = true if Maintainer.where(user: current_user, group: @pid.group).exists? || current_user.super
      @is_owner = false if current_user.read_only
  
      @owner = User.find_by(login: @pid.username)

      if params[:ajax] == 'true'
        erb :edit_pid_form, layout: false
      else
        erb :show_pid
      end
    else
      halt(404)
    end
  end  
  
# ---------------------------------------------------------------
# Display the main menu
# ---------------------------------------------------------------  
  ['/link/index', '/link', '/link/'].each do |path|
    get path do
      erb :index
    end
  end

# ---------------------------------------------------------------
# Process the PIDs batch edit form
# ---------------------------------------------------------------  
  post '/link/edit' do
    @msg = ''
    @failures = [] 
    @mints = []
    @revisions = []
    @interested = []
  
    if !params[:csv].nil?
      # if params[:csv][:type] == 'text/csv'
      begin
        # Loop through the items in the CSV
        CSV.foreach(params[:csv][:tempfile], row_sep: :auto, col_sep: ',') do |row|
          id, url, note = row

          # Strip off the last slash if it exists
          if !url.nil?
            url = url.chomp('/')
          end
  
          # If the PID id is nil, they would like to mint the PID
          if id.nil?
            # Make sure the URL is not missing
            if !url.nil?
              result = mint_pid(url, 'Batch Minted', note, request.ip)
  
              # If we successfully minted the PID
              if result[:saved?]
                @mints << result[:pid]
              else
                if result[:msg].include?(MESSAGE_CONFIG['pid_mint_failure'])
                  @failures << "URL: #{url} - #{result[:msg]}"
                elsif result[:msg] == MESSAGE_CONFIG['pid_mint_invalid_url']
                  @failures << "URL: #{url} - #{result[:msg]}"
                else
                  @interested << result[:pid]
                end
              end
            else
              @failures << "URL: #{url} - #{MESSAGE_CONFIG['batch_process_mint_inactive']}"
            end
          else
            pid = Pid.find_by(id: id)
  
            # If the PID was found and it's in the same group as the user or the user is an admin
            if !pid.nil?
              # Attempt to revise the PID
              revision = revise_pid(pid, (url.nil?) ? pid.url : url, 'Batch Modified', note, current_user.group, (url.nil?) ? "off" : "on")
  
              # If the revision was successful, add it to the list; otherwise, record it as a failure
              if revision[:saved?]
                @revisions << Pid.find_by(id: pid.id)
              else
                @failures << "PID: #{id} - #{revision[:msg]}"
              end
            else
              @failures << MESSAGE_CONFIG['batch_process_revise_missing'].gsub('{?}', id)
            end
          end
        end # CSV.foreach
  
        @msg = MESSAGE_CONFIG['batch_process_success']
  
      rescue Exception => e
        @msg = "#{MESSAGE_CONFIG['batch_process_failure']}<br /><br />#{e.message}"
      end
  
      # else
      #   @msg = MESSAGE_CONFIG['invalid_file_type']
      # end
    else
      @msg = MESSAGE_CONFIG['no_file_selected']
    end
  
    erb :edit_pid
  end
  

# ---------------------------------------------------------------
# Process the PIDs search form
# ---------------------------------------------------------------  
  post '/link/search' do
    results = []
    @interesteds = []
  
    @params = get_search_defaults(params)
    # Limit the search results based on the value in the config
    args = {}
    
    if @params[:pid_set].empty?
      # Set the search criteria based on the user's input
      args[:url] = ['%', @params[:url], '%'].join if @params[:url].present?
      args[:group_id] = @params[:groupid] if @params[:groupid].present?
      args[:username] = User.find_by(id: @params[:userid]).login unless @params[:userid].empty?
  
      args[:deactivated] = (@params[:active] == '0') if @params[:active].present?
  
      # args[:modified_at] = (@params[:modified_low].empty? ? nil : "#{@params[:modified_low]} 00:00:00")..(@params[:modified_high].empty? ? nil : "#{@params[:modified_high]} 23:59:59")
      if @params[:modified_low].present? && @params[:modified_high].present?
        # start_time = DateTime.parse("#{@params[:modified_low]} 00:00:00")
        # end_time = DateTime.parse("#{@params[:modified_high]} 23:59:59")
        start_time = @params[:modified_low].to_datetime
        end_time = @params[:modified_high].to_datetime.end_of_day
        args[:modified_at] = [start_time, end_time]
      end

      # args[:created_at] = (@params[:created_low].empty? ? nil : "#{@params[:created_low]} 00:00:00")..(@params[:created_high].empty? ? nil : "#{@params[:created_high]} 23:59:59")
      if @params[:created_low].present? && @params[:created_high].present?
        # start_time = DateTime.parse("#{@params[:created_low]} 00:00:00")
        # end_time = DateTime.parse("#{@params[:created_high]} 23:59:59")
        start_time = @params[:created_low].to_datetime
        end_time = @params[:created_high].to_datetime.end_of_day
        args[:created_at] = [start_time, end_time]
      end

      # If the user specified that they want to see only the interested party items
      if @params[:interesteds].to_s == '1'
        pid_ids = []
        # Determine the starting and ending pid ids

        where_condition, values = generate_where_condition_and_values(args)
        relevant_pids = Pid.where(where_condition, *values)
        first = @params[:pid_low].empty? ? relevant_pids.order(id: :asc).first&.id : @params[:pid_low]
        last = @params[:pid_high].empty? ? relevant_pids.order(id: :desc).first&.id : @params[:pid_high]
        # Loop through the interested parties
        Interested.where(group: current_user.group).each do |interest|
          # If the user specified a pid range, we need to adhere to it
          pid_ids << interest.pid.id if interest.pid.id >= first.to_i && interest.pid.id <= last.to_i
        end
  
        # Loop through the collected pids
        pid_ids.each do |pid_id|
          args[:id] = pid_id
          where_condition, values = generate_where_condition_and_values(args)
          watched = Pid.where(where_condition, *values).first
          # Add the pid to the results if it was found
          results << watched unless watched.nil?
        end
      else
        args[:id] = [@params[:pid_low], @params[:pid_high]] if params[:pid_low].present? && params[:pid_high].present?
        # Do not allow searches that are too broad.
        if @params[:url].length > 4 || !@params[:userid].empty? || !@params[:modified_low].empty? || !@params[:modified_high].empty? ||
           !@params[:created_low].empty? || !@params[:created_high].empty? || !@params[:pid_low].empty? || !@params[:pid_high].empty?

          where_condition, values = generate_where_condition_and_values(args)
          results = Pid.where(where_condition, *values)
          @msg = MESSAGE_CONFIG['pid_search_not_found'] if results.empty?
        else
          @msg = MESSAGE_CONFIG['pid_search_not_enough_criteria']
        end
      end
    else
      params[:pid_set].lines do |line|
        pid = line.gsub("\r\n", '').gsub("\n", '')
        rslt = Pid.find_by(id: pid.gsub(' ', ''))
        results << rslt unless rslt.nil?
      end
      @msg = MESSAGE_CONFIG['pid_search_not_found'] if results.empty?
    end

    @has_interesteds = Interested.where(group: current_user.group).exists?
    @json = results.to_json
    @manages = Maintainer.where(user: current_user).pluck(:group_id)
    erb :search_pid
  end  

# ---------------------------------------------------------------
# Edit PID
# ---------------------------------------------------------------
  put '/link/:id' do
    @pid = Pid.find_by(id: params[:id])
    @group = current_user.group
    @msg = ""
  
    url = params[:url]
    # Strip off the last slash, the REGEX
    url = url[0..(url.size())] if url[url.size() - 1] == '/'

    if !@pid.nil?
      # User can only edit their own PIDs, PIDs of groups they maintain, or if they are a super admin
      if @pid.group == @group || !Maintainer.find_by(group: @pid.group, user: current_user).nil? || current_user.super
  
        # Don't save if nothing has changed!
        if @pid.url != url || @pid.group.id != params[:group] || @pid.notes != params[:notes] ||
           (@pid.deactivated != ((params[:active] == 'on') ? false : true))
  
          # If the group passed in cannot be found, just use the PID's existing group
          group = (Group.find_by(id: params[:group]).nil?) ? @pid.group : Group.find_by(id: params[:group])
  
          revision = revise_pid(@pid, url, 'User Modified', params[:notes], group, params[:active])
          @msg = revision[:msg]
        end
  
        @groups = (current_user.super) ? Group.all : []
        Maintainer.where(user: current_user).each { |maintain| @groups << maintain.group } unless current_user.super
  
        @interested = Interested.where(pid: @pid)
  
        @is_owner = current_user.group == @pid.group
        @is_owner = true if Maintainer.find_by(user: current_user, group: @pid.group) || current_user.super
        @is_owner = false if current_user.read_only
  
        @owner = User.find_by(login: @pid.username)
  
        # Reload the PID before passing it to the erb
        @pid = Pid.find_by(id: params[:id])
        erb :show_pid
  
      # User is not authorized to modify this PID!
      else
        halt(403)
      end
    else
      halt(404)
    end
  end  
  
# ---------------------------------------------------------------
# Mint PID(s)
# ---------------------------------------------------------------
post '/link' do
  fatal = false
  @successes = []
  @interested = []
  @dead_urls = []
  @failures = {}

  params[:new_urls].lines do |line|
    # Strip off the line breaks from the form
    url = line.strip.gsub("\r\n", '').gsub("\n", '')
    # Strip off the last slash, the REGEX
    url = url[0..(url.size())] if url[url.size() - 1] == '/'

    unless url.empty?
      result = mint_pid(url, 'User Minted', nil, request.ip)

      # If we successfully minted the PID
      if result[:saved?]
        if result[:msg] == MESSAGE_CONFIG['pid_mint_success']
          @successes << result[:pid]
        else
          @dead_urls << result[:pid]
        end

      # We were unable to mint the PID
      else
        if result[:msg].include?(MESSAGE_CONFIG['pid_mint_failure'])
          @failures[line.strip] = result[:msg]
        elsif result[:msg] == MESSAGE_CONFIG['pid_mint_invalid_url']
          @failures[line.strip] = result[:msg]
        else
          @interested << result[:pid]
        end
      end

    else
      @failures[line.strip] = MESSAGE_CONFIG['pid_mint_empty_url']
    end

  end

  fatal = true if @failures.count > 0 && (@successes.count + @interested.count + @dead_urls.count) <= 0

  if fatal
    response.status = 500
  # elsif @failures.count - (@successes.count + @interested.count) > 0 # If we had at least one failure, return a 400 (inactive URLs are in here so check against the success count!)
  elsif @failures.count > 0
    response.status = 206
  else # We had no failures, return 302 (per PURL spec for success minting)
    response.status = 200
  end

  erb :new_pid
end
  
# ---------------------------------------------------------------
# Display the PIDs search form
# ---------------------------------------------------------------  
  get '/public/search' do
    @json = [].to_json
    @groups = Group.all
    @hide_nav = true
    
    erb :public_search_pid
  end
    
# ---------------------------------------------------------------  
# Process the public search form
# ---------------------------------------------------------------
  post '/public/search' do
    results = []
  
    # Limit the search results based on the value in the config
    args = {}
    
    if params[:pid_set].empty?
  
      # Set the search criteria based on the user's input
      args[:url] = "%#{params[:url]}%" if params[:url].present?
      args[:group_id] = params[:groupid] if params[:groupid].present?
      args[:deactivated] = (params[:active] == '0') if params[:active].present?
  

      args[:id] = [@params[:pid_low], @params[:pid_high]] if params[:pid_low].present? && params[:pid_high].present?
      
      # Do not allow searches that are too broad.
      if params[:url].length > 4 || (params[:pid_low].present? && params[:pid_high].present?)
        where_condition, values = generate_where_condition_and_values(args)
        results = Pid.where(where_condition, *values)
        @msg = MESSAGE_CONFIG['pid_search_not_found'] if results.empty?
      else
        @msg = MESSAGE_CONFIG['pid_search_not_enough_criteria']
      end
  
    else
      params[:pid_set].lines do |line|
        pid = line.gsub("\r\n", '').gsub("\n", '')
  
        rslt = Pid.find_by(id: pid.gsub(' ', ''))
        results << rslt unless rslt.nil?
      end
  
      @msg = MESSAGE_CONFIG['pid_search_not_found'] if results.empty?
    end
  
    @json = results.to_json
    @groups = Group.all
    @hide_nav = true
  
    erb :public_search_pid
  end
  
# ---------------------------------------------------------------
# Display the specified PID for a public audience
# ---------------------------------------------------------------
  get '/public/:id' do
    @pid = Pid.find_by(id: params[:id])
  
    if @pid
      @user = User.find_by(login: @pid.username)
      @hide_nav = true
  
      erb :public_show_pid
    else
      halt(404)
    end
  end  

# --------------------------------------------------------------------------------------------------------------
# Security checks
# --------------------------------------------------------------------------------------------------------------
  before '/link' do
    halt(401) unless logged_in?
  end
  
# --------------------------------------------------------------------------------------------------------------
  before do
    if request.path_info.match(%r{^/link/(?!dead|inactive)})
      halt(401) unless logged_in?

      if ['POST', 'PUT', 'DELETE'].include?(request.request_method) && current_user.read_only
        halt(403)
      end
  
      if ['/link/edit', '/link/new'].include?(request.path_info) && current_user.read_only
        halt(403)
      end
    end
  end
  
# --------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------- 
  private

  def notify_interested_parties(pid, new_url)
    if pid
      interested = Interested.where(pid: pid)
    
      # Email all of the Interested parties about the change
      if interested.size > 0
        target = "#{hostname}/link/#{pid.id}"

        subject = MESSAGE_CONFIG['notify_interested_subject'].gsub('{?}', pid.id.to_s)
      
        body = MESSAGE_CONFIG['notify_interested_change'].gsub('{?}', "#{target}")
        body += "\n#{MESSAGE_CONFIG['notify_interested_url_change'].gsub("{?old?}", pid.url).gsub("{?new?}", new_url)}" unless pid.url == new_url
        body += "\n#{MESSAGE_CONFIG['notify_interested_deactivation']}" if new_url.nil?
    
        interested.each do |link|  
          maintainers = Maintainer.where(group: link.group)
          recipients = []
          
          maintainers.each do |maintainer|
            recipients << maintainer.user.email
          end
          
          # Send an email
          # Commented out email sending for now, you can implement it if needed.
          # send_email(recipients.join(";"), subject, body)
        end
      end
    end
  end

  def revise_pid(pid, url, change_category, notes, group, active)
    saved = false
    
    # Replace comma with semicolon in notes, 
    # comma causes notes to split into extra columns when downloading
    notes = notes.gsub(',', ';') unless notes.nil?
  
    # If the PID belongs to the current user's group or the current user is a Maintainer of the PID's group or the current user is a super admin
    if pid.group == current_user.group || !Maintainer.find_by(group: pid.group, user: current_user).nil? || current_user.super

      # If the URL is even valid
      if url =~ URI_REGEX || url.nil?
        begin
          # Notify any interested parties if the URL changed or the PID was deactivated
          notify_interested_parties(pid, url) if (pid.url != url || active != "on")
          
          pid.revise(url: (url.nil?) ? pid.url : url,
                     deactivated: active != 'on',
                     change_category: (change_category.nil?) ? pid.change_category : change_category,
                     notes: (notes.nil?) ? pid.notes : notes,
                     group: (group.nil?) ? pid.group : group,
                     username: current_user.login,
                     modified_at: Time.now,
                     dead_pid_url: DEAD_PID_URL,
                     host: request.ip)
                     
          # Only search for duplicates if the URL has changed!
          dups = (url != pid.url) ? hasDuplicate(url, pid.id) : []
  
          # If there is already a PID out there using that URL
          if !dups.empty? 
            msg = MESSAGE_CONFIG['pid_duplicate_url_warn'].gsub('{?}', "<a href='#{hostname}/link/#{dups[0]}'>#{dups[0]}</a>")
          
          else
            # Check to see if the PID's URL is returning an HTTP 200
            good_url = pid.verify_url
            if good_url >= 400
              msg = MESSAGE_CONFIG['pid_revise_dead_url'].gsub('{?}', good_url.to_s)
            else
              msg = MESSAGE_CONFIG['pid_update_success']
            end  
          end  
          
          saved = true
        
        rescue Exception => e
          msg = MESSAGE_CONFIG['pid_update_failure']
          msg += e.message
      
          logger.error "#{current_user.login} - #{msg}\n#{e.message}"
        end
      
      # The URL is an invalid format
      else
        msg = MESSAGE_CONFIG['pid_update_invalid_url']
      end
    
      # The user does not have permission to revise the PID!
    else
      msg = MESSAGE_CONFIG['pid_unauthorized']
    end
    
    { saved?: saved, msg: msg, pid: pid }
  end
  
# --------------------------------------------------------------------------------------------------------------
  def mint_pid(url, change_category, notes, host)
    saved = false
    
    # Replace comma with semicolon in notes, 
    # comma causes notes to split into extra columns when downloading
    notes = notes.gsub(',', ';') unless notes.nil?
  
    # If the URL is even valid
    if url =~ URI_REGEX
      begin
        dups = hasDuplicate(url, nil)
        
        if !dups.empty?
          pid = Pid.find_by(id: dups[0])
  
          # If the Interested Party does not already exist
          if Interested.find_by(pid: pid, group: current_user.group).nil?
            interested = Interested.new(pid: pid, group: current_user.group)
  
            # Don't save the Interested record if the user's group already owns the PID!!!
            interested.save if pid.group != current_user.group
          end
          
          msg = MESSAGE_CONFIG['pid_duplicate_url'].gsub('{?}', "<a href='#{hostname}/link/#{pid.id}'>#{pid.id}</a>")

        # The URL doesn't exist
        else
          pid = Pid.mint(url: url,
                         username: current_user.login,
                         group: current_user.group,
                         change_category: change_category,
                         notes: notes,
                         host: host)
                       
          # Check to see if the PID's URL is returning an HTTP 200
          good_url = pid.verify_url
          if good_url >= 400 || !pid.invalid_url_report.nil?
            msg = MESSAGE_CONFIG['pid_revise_dead_url'].gsub('{?}', good_url.to_s)
          else
            msg = MESSAGE_CONFIG['pid_mint_success']
          end 
                        
          saved = true
        end
      
      rescue Exception => e
        msg = MESSAGE_CONFIG['pid_mint_failure'].gsub('{?}', url) 
        msg += e.message
      
        logger.error "#{current_user.login} - #{msg}\n#{e.message}"
      end
      
    # The URL is an invalid format
    else
      msg = MESSAGE_CONFIG['pid_mint_invalid_url']
    end 
    
    { saved?: saved, msg: msg, pid: pid }
  end

  # TODO: Do this in ActiveRecord
  def generate_where_condition_and_values(args)
    conditions = []
    values = []
    args.each do |key, value|
      if key == :url
        conditions << "#{key} LIKE ?"
        values << value
      elsif value.is_a?(Array) # [:id, :created_at, :modified_at].include?(key)
        conditions << "#{key} BETWEEN ? AND ?"
        values.concat(value)
      else
        conditions << "#{key} = ?"
        values << value
      end
    end
    where_condition = conditions.join(" AND ")
    [where_condition, values]
  end
end