require 'sinatra'
require 'redis'
require 'devise'

require_relative 'main.rb'

set :bind, '0.0.0.0'

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get '/' do
  # NOTHING
end

get '/:userid/like' do

  if params[:url] != nil

    @userId = params[:userid]

    user = User.new(@userId)

    user.addLike(params[:url])

    redirect "/" + @userId
  end
end

get '/:userid/dislike' do

  if params[:url] != nil

    @userId = params[:userid]

    user = User.new(@userId)

    user.addDislike(params[:url])

    redirect "/" + @userId
  end
end

get '/:userid' do

  @userId = params[:userid]

  user = User.new(@userId)

  @userName = user.getUsernameFromId

  @userKeywords = user.getUserKeywords

  @topItems = user.getTopItems

  erb :index

end

post '/' do
  erb :index
end