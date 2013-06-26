class PidApp < Sinatra::Application
  
  get '/link/new' do
    erb :new_pid
  end
  
  post '/link' do
    @pid = Pid.mint(:url => params[:url], :username => 'placeholder', :change_category => 'User_Entered')

    return 500 if @pid.nil?    

    if @pid && @pid.valid?
      status 201
      erb :show_pid
    else
      status 400
      erb :new_pid
    end
  end
  
  get '/link/:id' do
    @pid = Pid.get(params[:id])
    if @pid
      erb :show_pid
    else
      404
    end
  end

end