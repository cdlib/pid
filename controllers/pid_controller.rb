class PidApp < Sinatra::Application
  
  get '/pid/:id' do
    pid = Pid.get(params[:id])
    if pid
      [200, pid.id.to_s]
    else
      404
    end
  end
  
end