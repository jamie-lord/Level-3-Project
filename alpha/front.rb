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

      user.incrStat("like")

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

      user.incrStat("dislike")

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

      user.incrStat("irrelevant")

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

      user.incrStat("streamLoads")

      user.addToLog("Load stream", "INFO")

      @stream = user.getStream

      @stats = user.getStats

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

      user.incrStat("clicked")

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

      user.incrStat("like")

      user.addToLog("Seeded #{params[:url0]}", "INFO")

      if params[:url1].length > 0
        user.addLike(params[:url1])
        user.incrStat("like")
        user.addToLog("Seeded #{params[:url1]}", "INFO")
      end

      if params[:url2].length > 0
        user.addLike(params[:url2])
        user.incrStat("like")
        user.addToLog("Seeded #{params[:url2]}", "INFO")
      end

      if params[:url3].length > 0
        user.addLike(params[:url3])
        user.incrStat("like")
        user.addToLog("Seeded #{params[:url3]}", "INFO")
      end

      if params[:url4].length > 0
        user.addLike(params[:url4])
        user.incrStat("like")
        user.addToLog("Seeded #{params[:url4]}", "INFO")
      end

      user.toggleNew

      user.updateStream

      redirect "/" + @name
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
      user.addPotentialNewSource(@url)
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

      user.incrStat("bugsReported")

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