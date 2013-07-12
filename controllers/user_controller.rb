class PidApp < Sinatra::Application
  get '/user/login' do
    erb :login
  end

  post '/user/login' do
    if session[:user] = User.authenticate(params['login'], params['password'])
      redirect '/'
    else
      erb :login
    end
  end

  get '/user/logout' do
    session[:user] = nil
    redirect '/'
  end

  get '/user/new' do
    erb :new_user
  end

  post '/user/create' do
    @user = User.new(params)
    begin
      @user.save
      redirect "/user/#{@user.login}"
    rescue DataMapper::SaveFailureError => e
      erb :new_user
    end
  end

  get '/user/list' do
    @user = User.all
    erb :list_users
  end

  get '/user/:name' do
    @user = User.first(:login => params[:name])
    if @user
      erb :show_user
    else
      404
    end
  end
  
end