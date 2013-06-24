class PidApp < Sinatra::Application
  
  get '/pid/:id' do
    @pid = Pid.get(params[:id])
    if @pid
      erb :pid
    else
      404
    end
  end
  
end