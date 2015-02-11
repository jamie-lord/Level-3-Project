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

    user.addToLog("Liked #{params[:url]}", "INFO")

    user.updateStream

    redirect "/" + @name
  end
end

get '/:name/dislike' do

  if params[:url] != nil

    @name = params[:name]

    user = User.new(@name)

    user.addDislike(params[:url])

    user.addToLog("Dislike #{params[:url]}", "INFO")

    user.updateStream

    redirect "/" + @name
  end
end

get '/:name/irrelevant' do

  if params[:url] != nil

    @name = params[:name]

    user = User.new(@name)

    user.addIrrelevant(params[:url])

    user.addToLog("Irrelevant #{params[:url]}", "INFO")

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

    user.addToLog("Load stream", "INFO")

    @stream = user.getStream

    erb :stream
  end
end

get '/:name/redirect' do

  if params[:url] != nil

    @name = params[:name]

    @url = params[:url]

    user = User.new(@name)

    user.addViewed(@url)

    user.addToLog("Clicked #{@url}", "INFO")

    redirect @url
  else
    redirect "/" + @name
  end
end

post '/:name/likeSeed' do

  if params[:url0] != nil

    @name = params[:name]

    user = User.new(@name)

    user.addLike(params[:url0])

    user.addToLog("Seeded #{params[:url0]}", "INFO")

    if params[:url1] != nil
      user.addLike(params[:url1])
      user.addToLog("Seeded #{params[:url1]}", "INFO")
    end

    if params[:url2] != nil
      user.addLike(params[:url2])
      user.addToLog("Seeded #{params[:url2]}", "INFO")
    end

    if params[:url3] != nil
      user.addLike(params[:url3])
      user.addToLog("Seeded #{params[:url3]}", "INFO")
    end

    if params[:url4] != nil
      user.addLike(params[:url4])
      user.addToLog("Seeded #{params[:url4]}", "INFO")
    end

    user.toggleNew

    user.updateStream

    redirect "/" + @name
  end
end

post '/' do
  erb :index
end