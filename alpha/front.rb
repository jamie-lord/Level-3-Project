require 'sinatra'
require 'redis'
require 'devise'

require_relative 'main.rb'

set :bind, '0.0.0.0'

set :port, 80

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get '/' do
  # NOTHING
end

get '/:name/like' do

  if params[:url] != nil

    @name = params[:name]

    user = User.new(@name)

    user.addLike(params[:url])

    user.updateStream

    redirect "/" + @name
  end
end

get '/:name/dislike' do

  if params[:url] != nil

    @name = params[:name]

    user = User.new(@name)

    user.addDislike(params[:url])

    user.updateStream

    redirect "/" + @name
  end
end

get '/:name' do

  @name = params[:name]

  user = User.new(@name)

  if user.newUser == true
     erb :newUser
  else

    user.updateStream

    @stream = user.getStream

    erb :index
  end
end

post '/:name/likeSeed' do

  if params[:url0] != nil

    @name = params[:name]

    user = User.new(@name)

    user.addLike(params[:url0])

    if params[:url1] != nil
      user.addLike(params[:url1])
    end

    if params[:url2] != nil
      user.addLike(params[:url2])
    end

    if params[:url3] != nil
      user.addLike(params[:url3])
    end

    if params[:url4] != nil
      user.addLike(params[:url4])
    end

    user.toggleNew

    user.updateStream

    redirect "/" + @name
  end
end

post '/' do
  erb :index
end