require 'json'

class PidApp < Sinatra::Application
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
        @groups = Group.all if current_user.super
        @group = current_user.group

        @interested = Interested.all(:pid => @pid)

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
    
    if !params[:csv].empty?
      if params[:csv][:type] == 'text/csv'

        begin
          # Loop through the items in the CSV
          CSV.foreach(params[:csv][:tempfile], :field_size_limit => APP_CONFIG['max_upload_csv_size']) do |row| 
            id, url, cat, note = row
            
            dups = hasDuplicate(url, id)
            
            # If the url is already being used by another PID, add it to the interested array
            if !dups.empty?
              @interested << Pid.get(dups[0])
              
            # Otherwise go ahead and mint/revise the PID
            else
              # If the PID id is null they would like to mint the PID
              if id.nil?
                # Make sure the URL is not missing
                if !url.nil?
                  begin
                    pid = Pid.mint(:url => url, 
                                   :username => current_user.login,
                                   :group => current_user.group,
                                   :change_category => cat,
                                   :notes => note)

                    @mints << pid
                  rescue Exception => e
                    @failures << "#{MESSAGE_CONFIG['batch_process_mint_failure'].gsub('{?}', id)} #{e.message}"
                  end
                else
                  @failures << MESSAGE_CONFIG['batch_process_mint_inactive']
                end
            
              # We are updating an existing PID
              else
                pid = Pid.get(id)
          
                # If the PID was found and its in the same group as the user or the user is an admin
                if !pid.nil?

                  if pid.group == current_user.group || !Maintainer.first(:group => pid.group, :user => current_user).nil? || current_user.super
                    begin 
                    
                      notify_interested_parties(pid, url) if (pid.url != url || url.nil?)
                    
                      pid.revise({:url => url.nil? ? pid.url : url, 
                                  :change_category => cat,
                                  :notes => note,
                                  :deactivated => url.nil? ? true : false,
                                  :group =>  current_user.group,
                                  :username => current_user.login,
                                  :modified_at => Time.now,
                                  :dead_pid_url => DEAD_PID_URL})
                             
                      @revisions << Pid.get(pid.id)
                    rescue Exception => e
                      @failures << "#{MESSAGE_CONFIG['batch_process_revise_failure'].gsub('{?}', id)} - #{e.message}"
                    end
                  else
                    @failures << MESSAGE_CONFIG['batch_process_revise_wrong_group'].gsub('{?}', id)
                  end
                else
                  @failures << MESSAGE_CONFIG['batch_process_revise_missing'].gsub('{?}', id)
                end
              end
          
            end # dups.empty
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
    
    @params = get_search_defaults(params)

    # Limit the search results based on the value in the config
    args = {}
    
    # Set the search criteria based on the user's input
    args[:url.like] = '%' + @params[:url] + '%' unless @params[:url].empty?
    args[:username] = User.get(@params[:userid]).login unless @params[:userid].empty?
  
    args[:deactivated] = (@params[:active] == '0') ? true : false unless @params[:active].empty?
    
    args[:id.gte] = @params[:pid_low] unless @params[:pid_low].empty?
    args[:id.lte] = @params[:pid_high] unless @params[:pid_high].empty?
  
    args[:modified_at.gte] = "#{@params[:modified_low]} 00:00:00" unless @params[:modified_low].empty?
    args[:modified_at.lte] = "#{@params[:modified_high]} 23:59:59" unless @params[:modified_high].empty?
  
    args[:created_at.gte] = "#{@params[:created_low]} 00:00:00" unless @params[:created_low].empty?
    args[:created_at.lte] = "#{@params[:created_high]} 23:59:59" unless @params[:created_high].empty?
    
    # Filter the results to the user's group unless the user is an admin
    if !Maintainer.all(:user => current_user).empty?
      Maintainer.all(:user => current_user).each{ |maintainer| (Pid.all(args) & Pid.all(:group => maintainer.group)).each{ |pid| results << pid } }
    else
      args[:group] = current_user.group unless current_user.super
      
      results = Pid.all(args)
    end

    Interested.all(:group => current_user.group).each do |interest|
      results << interest.pid
    end

puts args.inspect
      
    @json = results.to_json
      
    @msg = MESSAGE_CONFIG['pid_search_not_found'] if results.empty?
    
    erb :search_pid
  end

# ---------------------------------------------------------------
# Edit PID
# ---------------------------------------------------------------
  put '/link/:id' do
    @pid = Pid.get(params[:id])
    user = current_user
    @msg = "blah"
    
    if @pid
      # User can only edit their own PIDs, PIDs of groups they maintain, or if they are a super admin
      if @pid.group == user.group || !Maintainer.first(:group => @pid.group, :user => user).nil? || user.super
        
        # Don't save if nothing has changed!
        if @pid.url != params[:url] || @pid.group.id != params[:group] || (@pid.deactivated != ((params[:active] == "on") ? false : true))
            
          begin
            dups = hasDuplicate(params[:url], @pid.id)
            
            # If there is already a PID out there using the specified url
            if !dups.empty?
              # Set the user's group as an Interested Party
              existing = Pid.get(dups[0])
              Interested.new(:pid => existing, :group => current_user.group).save if Interested.first(:pid => existing, :group => current_user.group).nil?
              
              @msg = MESSAGE_CONFIG['pid_duplicate_url'].gsub('{?}', "<a href='#{hostname}link/#{dups[0]}'>#{dups[0]}</a>")
            
            else
              url = params[:url]
              # Strip off the last slash, the REGEX 
              url = url[0..(url.size())] if url[url.size() -1] == '/'
              
              if url =~ URI_REGEX
                notify_interested_parties(@pid, params[:url]) if (@pid.url != params[:url] || params[:active] != "on")
                
                @pid.revise({:url => params[:url], 
                             :deactivated => (params[:active] == "on") ? false : true,
                             :group =>  (params[:group].nil?) ? @pid.group : params[:group],
                             :username => user.login,
                             :modified_at => Time.now,
                             :dead_pid_url => DEAD_PID_URL,
                             :host => request.ip})
        
                # Check to see if the PID's URL is valid, if not WARN the user
                if verify_url(params[:url]) != 200
                  @msg = MESSAGE_CONFIG['pid_revise_dead_url'].gsub('{?}', @pid.id.to_s) 
                else
                  @msg = MESSAGE_CONFIG['pid_update_success']
                end
              else
                @msg = MESSAGE_CONFIG['pid_update_invalid_url']
              end
            end
          rescue Exception => e
            @msg = MESSAGE_CONFIG['pid_update_failure'] 
            @msg += e.message
          end
        
        end
      
        @groups = Group.all if user.super
        @group = user.group
          
        @interested = Interested.all(:pid => @pid)
          
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
      
      change_category = (request.referrer == "#{hostname}link/new") ? 'User_Entered' : 'REST_API'
      notes = MESSAGE_CONFIG['pid_mint_default_note'].gsub('{?ip?}', request.ip).gsub('{?}', url) if request.referrer != "#{hostname}link/new"
      
      # Strip off the line breaks from the form
      url = line.strip.gsub("\r\n", '').gsub("\n", '')
      # Strip off the last slash, the REGEX 
      url = url[0..(url.size())] if url[url.size() -1] == '/'
      
      unless url.empty?
        if url =~ URI_REGEX
      
          dups = hasDuplicate(url, nil)
          
          if !dups.empty?            
            existing = Pid.get(dups[0])
            
            # If the Interested Party does not already exist
            if Interested.first(:pid => existing, :group => current_user.group).nil?
              interested = Interested.new(:pid => existing, :group => current_user.group)
              
              # Don't save the Interested record if the user's group already owns the PID!!!
              interested.save if existing.group != current_user.group
            end
            
            @interested << existing
          
          # Otherwise go ahead and mint the pid
          else
      
            begin
              pid = Pid.mint(:url => url, 
                             :username => current_user.login,
                             :group => current_user.group,
                             :change_category => change_category,
                             :notes => notes,
                             :host => request.ip)
                             
              # Check to see if the PID's URL is valid, if not WARN the user
              if verify_url(url) != 200
                @dead_urls << pid
              else
                @successes << pid
              end

            rescue Exception => e
              fatal = true 
              @failures[line.strip] = "#{MESSAGE_CONFIG['pid_mint_failure'].gsub('{?}', url)} - #{e.message}"
            end
          end
          
        else
          @failures[line.strip] = MESSAGE_CONFIG['pid_mint_invalid_url'].gsub('{?}', url) 
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
  before '/link/*' do
    halt(401) unless logged_in?
  end
  
# --------------------------------------------------------------------------------------------------------------
  after '/link/*' do
    session[:msg] = nil
  end

# --------------------------------------------------------------------------------------------------------------
  not_found do
    @msg = MESSAGE_CONFIG['pid_not_found']
    @msg if request.xhr?
    erb :not_found unless request.xhr?
  end

# --------------------------------------------------------------------------------------------------------------
  error 401 do
    erb :login
  end

# --------------------------------------------------------------------------------------------------------------
  error 403 do
    @msg = MESSAGE_CONFIG['pid_unauthorized']
    @msg if request.xhr?
    erb :unauthorized unless request.xhr?
  end


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
end