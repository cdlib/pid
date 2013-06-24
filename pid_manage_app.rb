$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), 'models')))
require 'sinatra'
require 'pid_models'

get '/' do
  "Success"
end

get '/pid/:id' do
  pid = Pid.get(params[:id])
  if pid
    [200, pid.id.to_s]
  else
    404
  end
end
