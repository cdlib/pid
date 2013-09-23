require 'json'

class PidApp < Sinatra::Application
# -------------------------------------------------------------------------------------------------------------- 
# Dead PID page
# --------------------------------------------------------------------------------------------------------------  
  get '/link/dead' do    
    erb :dead_pid, :layout => false
  end
  
  get '/link/inactive' do
    erb :dead_pid, :layout => false
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
    
    @has_interesteds = !Interested.first(:group => current_user.group).nil?
    
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
    @pid = Pid.get(params[:id])
    
    if @pid
      # If the user's group owns the PID, the user is a super admin, 
      #      the user is a maintainer of the PID's group, or the user's group is an Interested Party
      if current_user.group == @pid.group || current_user.super || 
                                  !Maintainer.first(:group => @pid.group, :user => current_user).nil? ||
                                  !Interested.first(:group => current_user.group, :pid => @pid).nil?

        @groups = (current_user.super) ? Group.all : []
        Maintainer.all(:user => current_user).each{ |maintain| @groups << maintain.group } unless current_user.super
        @group = current_user.group

        @interested = Interested.all(:pid => @pid)
        
        @is_owner = Interested.first(:group => current_user.group, :pid => @pid).nil? ? true : false
        @is_owner = true if Maintainer.first(:user => current_user, :group => @pid.group) || current_user.super
        @is_owner = false if current_user.read_only
        
        @owner = User.first(:login => @pid.username)

        if params[:ajax] == "true"
          erb :edit_pid_form, :layout => false
        else
          erb :show_pid
        end

      else        
        halt(403)
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
      if params[:csv][:type] == 'text/csv'

        begin
          # Loop through the items in the CSV
          CSV.foreach(params[:csv][:tempfile], :field_size_limit => APP_CONFIG['max_upload_csv_size']) do |row| 
            id, url, cat, note = row

            # Strip off the last slash, the REGEX 
            if !url.nil?
              url = url[0..(url.size())] if url[url.size() -1] == '/'
            end

            # If the PID id is null they would like to mint the PID
            if id.nil?
              # Make sure the URL is not missing
              if !url.nil?
              
                result = mint_pid(url, 'Batch', note, request.ip)
              
                # If we successfully minted the PID
                if result[:saved?]
                 @mints << result[:pid]
                 
                  # We were unable to mint the pid
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
            
            # We are updating an existing PID
            else
              pid = Pid.get(id)
          
              # If the PID was found and its in the same group as the user or the user is an admin
              if !pid.nil?

                # Attempt to revise the PID
                revision = revise_pid(pid, (url.nil?) ? pid.url : url, note, current_user.group, (url.nil?) ? "off" : "on")
                      
                # If the revision was successful add it to the list otherwise record it as a failure
                if revision[:saved?]
                  @revisions << Pid.first(:id => pid.id)
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

      else
        @msg = MESSAGE_CONFIG['invalid_file_type']
      end
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
    
    # Set the search criteria based on the user's input
    args[:url.like] = '%' + @params[:url] + '%' unless @params[:url].empty?
    args[:username] = User.get(@params[:userid]).login unless @params[:userid].empty?
  
    args[:deactivated] = (@params[:active] == '0') ? true : false unless @params[:active].empty?
  
    args[:modified_at.gte] = "#{@params[:modified_low]} 00:00:00" unless @params[:modified_low].empty?
    args[:modified_at.lte] = "#{@params[:modified_high]} 23:59:59" unless @params[:modified_high].empty?
  
    args[:created_at.gte] = "#{@params[:created_low]} 00:00:00" unless @params[:created_low].empty?
    args[:created_at.lte] = "#{@params[:created_high]} 23:59:59" unless @params[:created_high].empty?

    # If the user specified that they want to see only the interested party items
    if @params[:interesteds].to_s == '1'
      pids = []
    
      # Determine the starting and ending pid ids
      first = !@params[:pid_low].empty? ? @params[:pid_low] : Pid.first(args).id
      last = !@params[:pid_high].empty? ? @params[:pid_high] : Pid.last(args).id
      
      # Loop through the interested parties
      Interested.all(:group => current_user.group).each do |interest|
        # If the user specified a pid range we need to adhere to it
        pids << interest.pid.id if interest.pid.id >= first.to_i and interest.pid.id <= last.to_i
      end

      # Loop through the collected pids
      pids.each do |pid|
        args[:id] = pid
    
        watched = Pid.first(args)
        
        # Add the pid to the results if it was found
        results << watched unless watched.nil?
      end
            
    else
      args[:id.gte] = @params[:pid_low] unless @params[:pid_low].empty?
      args[:id.lte] = @params[:pid_high] unless @params[:pid_high].empty?

      # Filter the results to the user's group unless the user is an admin
      if !Maintainer.all(:user => current_user).empty? and !current_user.super
        Maintainer.all(:user => current_user).each{ |maintainer| (Pid.all(args) & Pid.all(:group => maintainer.group)).each{ |pid| results << pid } }
      else
        args[:group] = current_user.group unless current_user.super
      
        results = Pid.all(args)
      end
    end
    
    @has_interesteds = !Interested.first(:group => current_user.group).nil?
    
    @json = results.to_json
      
    @msg = MESSAGE_CONFIG['pid_search_not_found'] if results.empty?
    
    erb :search_pid
  end

# ---------------------------------------------------------------
# Edit PID
# ---------------------------------------------------------------
  put '/link/:id' do
    @pid = Pid.get(params[:id])
    @group = current_user.group
    @msg = "blah"
    
    url = params[:url]
    # Strip off the last slash, the REGEX 
    url = url[0..(url.size())] if url[url.size() -1] == '/'
    
    if !@pid.nil?
      # User can only edit their own PIDs, PIDs of groups they maintain, or if they are a super admin
      if @pid.group == @group || !Maintainer.first(:group => @pid.group, :user => current_user).nil? || current_user.super
        
        # Don't save if nothing has changed!
        if @pid.url != url || @pid.group.id != params[:group] || @pid.notes != params[:notes] || 
                                              (@pid.deactivated != ((params[:active] == "on") ? false : true))
          
          # If the group passed in cannot be found just use the PID's existing group
          group = (Group.first(:id => params[:group]).nil?) ? @pid.group : Group.first(:id => params[:group])
          
          revision = revise_pid(@pid, url, params[:notes], group, params[:active])
          @msg = revision[:msg]
        end
      
        @groups = (current_user.super) ? Group.all : []
        Maintainer.all(:user => current_user).each{ |maintain| @groups << maintain.group } unless current_user.super
          
        @interested = Interested.all(:pid => @pid)
        
        @is_owner = Interested.first(:group => current_user.group, :pid => @pid).nil? ? true : false
        @is_owner = true if Maintainer.first(:user => current_user, :group => @pid.group) || current_user.super
        @is_owner = false if current_user.read_only
        
        @owner = User.first(:login => @pid.username)
        
        #reload the pid before we pass it to the erb
        @pid = Pid.get(params[:id])
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
      
      change_category = (request.referrer == "#{hostname}link/new") ? 'User_Entered' : 'Batch'
      notes = MESSAGE_CONFIG['pid_mint_default_note'].gsub('{?ip?}', request.ip).gsub('{?}', url) if request.referrer != "#{hostname}link/new"
      
      # Strip off the line breaks from the form
      url = line.strip.gsub("\r\n", '').gsub("\n", '')
      # Strip off the last slash, the REGEX 
      url = url[0..(url.size())] if url[url.size() -1] == '/'
      
      unless url.empty?
        
        result = mint_pid(url, change_category, notes, request.ip)
        
        # If we successfully minted the PID
        if result[:saved?]
          if result[:msg] == MESSAGE_CONFIG['pid_mint_success']
            @successes << result[:pid]
          else
            @dead_urls << result[:pid]
          end
          
        # We were unable to mint the pid
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
    
    fatal = true if @failures.count > 0 and (@successes.count + @interested.count + @dead_urls.count) <= 0
    
    if fatal
      response.status = 500
#    elsif @failures.count - (@successes.count + @interested.count) > 0     # If we had at least one failure return a 400 (inactive URLs are in here so check against success count!)
    elsif @failures.count > 0 
      response.status = 206
    else                          # We had no failures 302 (per PURL spec for success minting)
      response.status = 200
    end

    erb :new_pid
  end

# --------------------------------------------------------------------------------------------------------------
# Security checks
# --------------------------------------------------------------------------------------------------------------
  before '/link' do
    halt(401) unless logged_in?
  end
  
# --------------------------------------------------------------------------------------------------------------
  before /^\/link\/(?!(dead|inactive))/ do
    halt(401) unless logged_in?
    
    # If the user has a readonly account prevent them from running the post/put/delete commands!
    halt(403) if ['post', 'put', 'delete'].include?(request.request_method) && current_user.read_only
  end

# --------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------- 
private
  def notify_interested_parties(pid, new_url)
    if pid
      interested = Interested.all(:pid => pid)
    
      # Email all of the Interested parties about the change
      if interested.size > 0
        target = "#{hostname}link/#{pid.id}"

        subject = MESSAGE_CONFIG['notify_interested_subject'].gsub('{?}', pid.id.to_s)
      
        body = MESSAGE_CONFIG['notify_interested_change'].gsub('{?}', "#{target}")
        body += "\n#{MESSAGE_CONFIG['notify_interested_url_change'].gsub("{?old?}", pid.url).gsub("{?new?}", new_url)}" unless pid.url == new_url
        body += "\n#{MESSAGE_CONFIG['notify_interested_deactivation']}" if new_url.nil?
    
        interested.each do |link|  
          maintainers = Maintainer.all(:group => link.group)
          recipients = []
          
          maintainers.each do |maintainer|
            recipients << maintainer.user.email
          end
          
          # send an email 
          send_email(recipients.join(";"), subject, body)
        end
      end
    end
  end
  
# --------------------------------------------------------------------------------------------------------------
  def revise_pid(pid, url, notes, group, active)
    saved = false
    
    # If the pid belongs to the current user's group or the current user is a Maintainer of the Pid's group or the current user is a super admin
    if pid.group == current_user.group || !Maintainer.first(:group => pid.group, :user => current_user).nil? || current_user.super
      
      # If the URL is even valid
      if url =~ URI_REGEX || url.nil?
        begin
          # Notify any interested parties if the URL changed or the PID was deactivated
          notify_interested_parties(pid, url) if (pid.url != url || active != "on")
          
          pid.revise({:url => (url.nil?) ? pid.url : url,
                      :deactivated => (active == "on") ? false : true,
                      :notes => (notes.nil?) ? pid.notes : notes,
                      :group => (group.nil?) ? pid.group : group,
                      :username => current_user.login,
                      :modified_at => Time.now,
                      :dead_pid_url => DEAD_PID_URL,
                      :host => request.ip})
                       
          # Only search for duplicates if the URL has changed!
          dups = (url != pid.url) ? hasDuplicate(url, pid.id) : []

          # If there is already a PID out there using that URL
          if !dups.empty? 
            msg = MESSAGE_CONFIG['pid_duplicate_url_warn'].gsub('{?}', "<a href='#{hostname}link/#{dups[0]}'>#{dups[0]}</a>")
          
          else
            # Check to see if the PID's URL is retuirning an http 200
            good_url = verify_url(url)
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
    
    {:saved? => saved, :msg => msg, :pid => pid}
  end
  
# --------------------------------------------------------------------------------------------------------------
  def mint_pid(url, change_category, notes, host)
    saved = false
    
    # If the URL is even valid
    if url =~ URI_REGEX
      begin
        
        dups = hasDuplicate(url, nil)
      
        if !dups.empty?
          pid = Pid.first(:id => dups[0])

          # If the Interested Party does not already exist
          if Interested.first(:pid => pid, :group => current_user.group).nil?
            interested = Interested.new(:pid => pid, :group => current_user.group)
        
            # Don't save the Interested record if the user's group already owns the PID!!!
            interested.save if pid.group != current_user.group
          end
          
          msg = MESSAGE_CONFIG['pid_duplicate_url'].gsub('{?}', "<a href='#{hostname}link/#{pid.id}'>#{pid.id}</a>")
        
        # The URL doesn't exist
        else
          pid = Pid.mint(:url => url, 
                         :username => current_user.login,
                         :group => current_user.group,
                         :change_category => change_category,
                         :notes => notes,
                         :host => host)
                       
          # Check to see if the PID's URL is retuirning an http 200
          good_url = verify_url(url)
          if good_url >= 400
            msg = MESSAGE_CONFIG['pid_revise_dead_url'].gsub('{?}', good_url.to_s)
          else
            msg = MESSAGE_CONFIG['pid_mint_success']
          end 
                        
          saved = true
        end
      
      rescue Exception => e
        msg = MESSAGE_CONFIG['pid_mint_failure'] 
        msg += e.message
      
        logger.error "#{current_user.login} - #{msg}\n#{e.message}"
      end
      
    # The URL is an invalid format
    else
      msg = MESSAGE_CONFIG['pid_mint_invalid_url']
    end 
    
    {:saved? => saved, :msg => msg, :pid => pid}
  end
  
end