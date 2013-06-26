class PidApp < Sinatra::Application
  
  get '/PID/:id' do
    @pid = Pid.get(params[:id])
    if @pid
      erb :pid
    else
      404
    end
  end
  
end