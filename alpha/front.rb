require 'sinatra'
require 'redis'
require 'devise'

require_relative 'main.rb'
require_relative 'views/siteVariables.rb'

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

  @name = params[:name]

  if params[:url] != nil
    if doesUserExist(@name) == true

      user = User.new(@name)

      user.addLike(params[:url])

      user.addToLog("Liked #{params[:url]}", "INFO")

      user.updateStream

      redirect "/" + @name
    else
      erb :noUser
    end
  else
    redirect "/" + @name
  end
end

get '/:name/dislike' do

  @name = params[:name]

  if params[:url] != nil
    if doesUserExist(@name) == true

      user = User.new(@name)

      user.addDislike(params[:url])

      user.addToLog("Dislike #{params[:url]}", "INFO")

      user.updateStream

      redirect "/" + @name
    else
      erb :noUser
    end
  else
    redirect "/" + @name
  end
end

get '/:name/irrelevant' do

  @name = params[:name]

  if params[:url] != nil
    if doesUserExist(@name) == true

      user = User.new(@name)

      user.addIrrelevant(params[:url])

      user.addToLog("Irrelevant #{params[:url]}", "INFO")

      user.updateStream

      redirect "/" + @name
    else
      erb :noUser
    end
  else
    redirect "/" + @name
  end
end

get '/:name' do

  @name = params[:name]

  if doesUserExist(@name) == true
    user = User.new(@name)

    if user.newUser == true
      erb :newUser
    else
      user.updateStream

      user.addToLog("Load stream", "INFO")

      @stream = user.getStream

      erb :stream
    end
  else
    erb :noUser
  end
end

get '/:name/redirect' do

  @name = params[:name]

  if params[:url] != nil
    if doesUserExist(@name) == true

      @url = params[:url]

      user = User.new(@name)

      user.addViewed(@url)

      user.addToLog("Clicked #{@url}", "INFO")

      redirect @url
    else
      erb :noUser
    end
  else
    redirect "/" + @name
  end
end

post '/:name/likeSeed' do

  @name = params[:name]

  if params[:url0] != nil
    if doesUserExist(@name) == true

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
    else
      erb :noUser
    end
  else
    redirect "/" + @name
  end
end

post '/:name/addSource' do

  @name = params[:name]

  if doesUserExist(@name) == true

    @url = params[:url]

    user = User.new(@name)

    if @url != nil
      user.addToLog("Added new source #{@url}", "INFO")
    else
      user.addToLog("Failed to enter new source", "WARNING")
    end

    redirect "/" + @name
  else
    erb :noUser
  end
end

post '/:name/reportBug' do

  @name = params[:name]

  if doesUserExist(@name) == true

    @report = params[:report]

    user = User.new(@name)

    if @report != nil
      user.addToLog("Bug reported: #{@report}", "BUG")
    else
      user.addToLog("Failed to add bug report", "WARNING")
    end

    redirect "/" + @name
  else
    @report = params[:report]

    user = User.new(@name)

    if @report != nil
      user.addToLog("Bug reported (by unknown user): #{@report}", "BUG")
    else
      user.addToLog("Failed to add bug report (by unknow user)", "WARNING")
    end

    redirect "/" + @name
  end
end