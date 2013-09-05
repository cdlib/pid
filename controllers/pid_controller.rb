require 'json'

class PidApp < Sinatra::Application
# ---------------------------------------------------------------
# Display the new PID form
# ---------------------------------------------------------------  
  get '/link/new' do
    @failures = {}
    @successes = []
    @interested = []
    erb :new_pid
  end
  
# ---------------------------------------------------------------
# Display the PIDs search form
# ---------------------------------------------------------------  
  get '/link/search' do
    @json = [].to_json
    @params = get_search_defaults({})
    
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
    
    erb :edit_pid
  end
  
# ---------------------------------------------------------------
# Display the reports page
# ---------------------------------------------------------------  
  get '/link/report' do
    erb :reports
  end

# ---------------------------------------------------------------
# Display the specified purl
# ---------------------------------------------------------------  
  get '/link/:id' do
    @pid = Pid.get(params[:id])
    user = current_user
    
    if @pid
      if user.group == @pid.group || !Maintainer.first(:group => @pid.group, :user => user).nil? || user.super
        @groups = Group.all if user.super
        @group = user.group

        @interested = Interested.all(:pid => @pid)

        if params[:ajax] == "true"
          erb :edit_pid_form, :layout => false
        else
          erb :show_pid
        end

      else
        401
      end
    else
      404
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
    
    args[:id.gte] = @params[:pid_low]
    args[:id.lte] = @params[:pid_high]
  
    args[:modified_at.gte] = "#{@params[:modified_low]} 00:00:00"
    args[:modified_at.lte] = "#{@params[:modified_high]} 23:59:59"
  
    args[:created_at.gte] = "#{@params[:created_low]} 00:00:00" 
    args[:created_at.lte] = "#{@params[:created_high]} 23:59:59"
    
    # Filter the results to the user's group unless the user is an admin
    if !Maintainer.all(:user => current_user).empty?
      Maintainer.all(:user => current_user).each{ |maintainer| (Pid.all(args) & Pid.all(:group => maintainer.group)).each{ |pid| results << pid } }
    else
      args[:group] = current_user.group unless current_user.super
      
      results = Pid.all(args)
    end
      
    @json = results.to_json
      
    status 404 if results.empty?
    
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
      if @pid.group == user.group || !Maintainer.first(:group => @pid.group, :user => user).nil? || user.super
        # Don't save if nothing has changed!
        if @pid.url != params[:url] || @pid.group.id != params[:group] || (@pid.deactivated != ((params[:active] == "on") ? false : true))
            
          begin
            dups = hasDuplicate(params[:url], @pid.id)
            
            # If there is already a PID out there using the specified url
            if !dups.empty?
              @msg = MESSAGE_CONFIG['pid_duplicate_url'].gsub('{?}', "<a href='#{hostname}link/#{dups[0]}'>#{dups[0]}</a>")
            
            else
              notify_interested_parties(@pid, params[:url]) if (@pid.url != params[:url] || params[:active] != "on")
            
              @pid.revise({:url => params[:url], 
                           :deactivated => (params[:active] == "on") ? false : true,
                           :group =>  params[:group],
                           :username => user.login,
                           :modified_at => Time.now,
                           :dead_pid_url => DEAD_PID_URL,
                           :host => request.ip})
        
              # Check to see if the PID's URL is valid, if not WARN the user
              if verify_url(url) != 200
                @msg = MESSAGE_CONFIG['pid_revise_dead_url'].gsub('{?}', @pid.id) 

              else
                @msg = MESSAGE_CONFIG['pid_update_success']
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
        401
        @msg = MESSAGE_CONFIG['pid_unauthorized']
      end
    else
      @msg = MESSAGE_CONFIG['pid_not_found']
      404
    end
  end
  
# ---------------------------------------------------------------
# Mint PID(s)
# ---------------------------------------------------------------
  post '/link' do
    fatal = false
    @successes = []
    @interested = []
    @failures = {}
    
    params[:new_urls].lines do |line|
      
      change_category = (request.referrer == "#{hostname}link/new") ? 'User_Entered' : 'REST_API'
      notes = MESSAGE_CONFIG['pid_mint_default_note'].gsub('{?ip?}', request.ip).gsub('{?}', url) if request.referrer != "#{hostname}link/new"
      
      url = line.strip.gsub("\r\n", '').gsub("\n", '')
      
      unless url.empty?
        if url =~ URI_REGEX
      
          dups = hasDuplicate(url, nil)
          
          if !dups.empty?            
            existing = Pid.get(dups[0])
            Interested.new(:pid => existing, :group => current_user.group).save if Interested.first(:pid => existing, :group => current_user.group).nil?
            
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
              @successes << pid
          
              # Check to see if the PID's URL is valid, if not WARN the user
              @failures[line.strip] = MESSAGE_CONFIG['pid_mint_dead_url'].gsub('{?}', pid.id.to_s) if verify_url(url) != 200

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
    
    if fatal                      # If any 500s were returned we should flag it with a 500
      response.status = 500
    elsif @failures.count - (@successes.count + @interested.count) > 0     # If we had at least one failure return a 400 (inactive URLs are in here so check against success count!)
      response.status = 400
    else                          # We had no failures 302 (per PURL spec for success minting)
      response.status = 302
    end
    
    erb :new_pid
  end

# ---------------------------------------------------------------
# Security checks
# ---------------------------------------------------------------
  before '/link' do
    redirect '/user/login', {:msg => MESSAGE_CONFIG['session_expired']} unless logged_in?
  end
  
  before '/link/*' do
    redirect '/user/login', {:msg => MESSAGE_CONFIG['session_expired']} unless logged_in?
  end
  

private
  def notify_interested_parties(pid, new_url)
    if pid
      interested = Interested.all(:pid => pid)
    
      # Email all of the Interested parties about the change
      if interested.size > 0
        target = "#{hostname}link/#{pid.id}"

        subject = MESSAGE_CONFIG['notify_interested_subject'].gsub('{?}', pid.id.to_s)
      
        body = MESSAGE_CONFIG['notify_interested_change'].gsub('{?}', "<a href='#{target}'>#{target}</a>")
        body += "\n#{MESSAGE_CONFIG['notify_interested_url_change'].gsub("{?old?}", pid.url).gsub("{?new?}", new_url)}" unless pid.url == new_url
        body += "\n#{MESSAGE_CONFIG['notify_interested_deactivation']}" if new_url.nil?
    
        interested.each do |link|  
          # send an email 
          # TODO: send an email
        end
      end
    end
  end
end