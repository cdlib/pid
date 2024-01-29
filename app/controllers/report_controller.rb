require 'json'

class PidApp < Sinatra::Base
  
# ---------------------------------------------------------------
# Display the reports page
# ---------------------------------------------------------------  
  get '/report' do
    erb :reports
  end
    
# ---------------------------------------------------------------
# Get the list of inactive PIDs
# ---------------------------------------------------------------
  get '/report/inactive' do
    pids = []
    
    @groups = Group.all
    @json = [].to_json
    @msg = ""
    
    erb :report_inactive
  end
    
# ---------------------------------------------------------------
# Get the list of inactive PIDs for the group specified
# ---------------------------------------------------------------
  post '/report/inactive' do
    begin
      args = { group_id: params[:groupid], deactivated: true }
      args[:modified_at] = "#{params[:modified_low]} 00:00:00" unless params[:modified_low].empty?
  
      pids = Pid.where(args)
  
    rescue Exception => e
      @msg = "#{MESSAGE_CONFIG['reports_failure']} - #{e.message}"
      @msg += " - #{e.message}" if current_user.super
  
      logger.error "#{current_user.login} - #{@msg}: #{e.message}"
    end
  
    @groups = Group.all
    @json = pids.to_json
  
    erb :report_inactive
  end  

# ---------------------------------------------------------------
# Get the invalid URL report
# ---------------------------------------------------------------
  # get '/report/invalid' do
  #   @moved = [].to_json
  #   @not_found = [].to_json
  #   @error = [].to_json
  
  #   @groups = Group.all
  #   @skips = SkipCheck.all
  
  #   @last_edit_invalid = InvalidUrlReport.where.not(last_checked: nil).first
  #   @last_updated_invalid = @last_edit_invalid.last_checked.to_s.gsub(/\s.+/, '')
  
  #   @msg = ""
  
  #   erb :report_invalid
  # end

# ---------------------------------------------------------------
# Get the list of PIDs with invalid URLs for the specified group
# ---------------------------------------------------------------
  # post '/report/invalid' do
  #   pids = []
  #   moved = []
  #   not_found = []
  #   error = []
  #   @msg = ""
  
  #   begin
  #     group = Group.find_by(id: params[:groupid])
  
  #     if group
  #       pids = Pid.includes(:invalid_url_report).where(group: group).where.not(invalid_url_report: nil)
  
  #       pids.each do |pid|
  #         begin
  #           if pid.invalid_url_report
  #             # Check the URLs for each of the PIDs
  #             case pid.invalid_url_report.http_code
  #             when 300..399
  #               moved << pid
  #             when 400..499
  #               not_found << pid
  #             when 500..999
  #               error << pid
  #             end
  #           end
  #         rescue Exception => e
  #           error << pid
  #         end
  #       end
  #     else
  #       @msg += "#{MESSAGE_CONFIG['reports_failure']} - Group not found"
  #       logger.error "#{current_user.login} - #{@msg}"
  #     end
  #   rescue Exception => e
  #     @msg += "#{MESSAGE_CONFIG['reports_failure']} - #{e.message}"
  #     @msg += " - #{e.message}" if current_user.super
  #     logger.error "#{current_user.login} - #{@msg}: #{e.message}"
  #   end
  
  #   @moved = moved.to_json
  #   @not_found = not_found.to_json
  #   @error = error.to_json
  
  #   @groups = Group.all
  #   @skips = SkipCheck.all
  
  #   @last_edit_invalid = InvalidUrlReport.where.not(last_checked: nil).first
  #   @last_updated_invalid = @last_edit_invalid.last_checked.to_s.gsub(/\s.+/, '') 

  #   erb :report_invalid
  # end
  
# ---------------------------------------------------------------
# Get a list of duplicate PIDs
# ---------------------------------------------------------------
  get '/report/duplicate' do
    @json = {}.to_json
    @msg = ""
    @groups = Group.all
  
    @last_edit = DuplicateUrlReport.where.not(last_checked: nil).first
    @last_updated = @last_edit.last_checked.to_s.gsub(/\s.+/, '') 

    erb :report_duplicate
  end
  

# ---------------------------------------------------------------
# Get a list of duplicate PIDs for the specified group
# ---------------------------------------------------------------
  post '/report/duplicate' do
    pids = []
  
    begin
      group = Group.find_by(id: params[:groupid])
      if group
        pids = Pid.includes(:duplicate_url_report)
                  .where(group_id: group.id)
                  .where.not(duplicate_url_report_id: nil)
  
        dups = {}
        pids.each do |pid|
          dups[pid.url] = pid.duplicate_url_report.other_pids if pid.duplicate_url_report
        end
      else
        @msg = "#{MESSAGE_CONFIG['reports_failure']} - Group not found"
      end
    rescue Exception => e
      @msg = "#{MESSAGE_CONFIG['reports_failure']} - #{e.message}"
      @msg += " - #{e.message}" if current_user.super
      logger.error "#{current_user.login} - #{@msg}: #{e.message}"
    end
    
    @json = dups.to_json
    @groups = Group.all
    @last_edit = DuplicateUrlReport.where.not(last_checked: nil).first
    @last_updated = @last_edit.last_checked.to_s.gsub(/\s.+/, '') 

    erb :report_duplicate
  end
  
# ---------------------------------------------------------------
# Get the stats report page
# ---------------------------------------------------------------
  get '/report/stats' do
    @json = [].to_json

    erb :report_stats
  end
  
# ---------------------------------------------------------------
# Process the stats report
# ---------------------------------------------------------------
  post '/report/stats' do
    results = []
  
    start_date = params[:start_date].empty? ? nil : "#{params[:start_date]} 00:00:00"
    end_date = params[:end_date].empty? ? "#{Time.now}" : "#{params[:end_date]} 23:59:59"
  
    if !start_date.nil?
      Group.find_each do |group|
        results << {
          group: group.id,
          modified: Pid.where(group: group)
                       .where("modified_at >= ? AND modified_at <= ?", start_date, end_date)
                       .count,
          created: Pid.where(group: group)
                      .where("created_at >= ? AND created_at <= ?", start_date, end_date)
                      .count,
          deactivated: Pid.where(group: group)
                          .where("modified_at >= ? AND modified_at <= ? AND deactivated = ?", start_date, end_date, true)
                          .count
        }
      end
    end
  
    @json = results.to_json
    erb :report_stats
  end  

# ---------------------------------------------------------------
# Get the modification details report
# ---------------------------------------------------------------
  get '/report/mods' do
    @json = [].to_json
    @groups = Group.all
    
    erb :report_mods
  end
  
# ---------------------------------------------------------------
# Get the modification details report for the specified criteria
# ---------------------------------------------------------------
  post '/report/mods' do
    results = []
  
    start_date = params[:start_date].empty? ? nil : "#{params[:start_date]} 00:00:00"
    end_date = params[:end_date].empty? ? "#{Time.now.to_s}" : "#{params[:end_date]} 23:59:59"
  
    if !start_date.nil?
      pids = Pid.where(group_id: params[:groupid])
                .where('modified_at >= ?', start_date)
                .where('modified_at <= ?', end_date)
  
      pids.each do |pid|
        prior = pid.pid_versions[-2]
  
        # Skip items that only had their note changed!
        if pid.url != prior.url || pid.deactivated != prior.deactivated || pid.group_id != prior.group
          types = ''
          types = 'URL change<br />' if pid.url != prior.url
          types += "Moved from group #{prior.group}<br/>" if pid.group_id != prior.group
          types += 'deactivation' if pid.deactivated != prior.deactivated && pid.deactivated
  
          # If there is only 1 version then this was minted during the time period specified
          types = 'minted' if pid.pid_versions.length == 1
  
          results << {
            id: pid.id,
            modified_on: pid.modified_at,
            username: pid.username,
            types: types,
            current_url: pid.url,
            prior_url: prior.url,
            active: pid.deactivated ? 'No' : 'Yes'
          }
        end
      end
    end
  
    @json = results.to_json
    @groups = Group.all
  
    erb :report_mods
  end

# ---------------------------------------------------------------
# Reload the default criteria for the reports
# ---------------------------------------------------------------
  get '/report/defaults' do
    get_search_defaults({}).to_json 
  end

# --------------------------------------------------------------------------------------------------------------
  before '/report' do
    halt(401) unless logged_in?
    
    # If the user has a readonly account prevent them accessing anything
    halt(403) if current_user.read_only
  end
      
# --------------------------------------------------------------------------------------------------------------
  before '/report/*' do
    halt(401) unless logged_in?
    
    # If the user has a readonly account prevent them accessing anything
    halt(403) if current_user.read_only
  end
  
end
