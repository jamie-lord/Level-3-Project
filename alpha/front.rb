require 'sinatra'
require 'redis'
require 'devise'

require_relative 'main.rb'

set :bind, '0.0.0.0'

helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def random_string(length)
    rand(36**length).to_s(36)
  end
end

get '/' do
  # NOTHING
end

get '/:userid' do

  current_user = User.new(params[:userid])

  @current_username = current_user.get_username_from_id

  @user_keywords = current_user.get_user_keywords

  @top_items = current_user.get_top_items

  erb :index
end

#update
post '/' do
  # if params[:url] and not params[:url].empty?
  #   @shortcode = random_string 5
  #   Current_database.setnx "links:#{@shortcode}", params[:url]
  # end
  erb :index
end

get '/:shortcode' do
  @url = Current_database.get "links:#{params[:shortcode]}"
  redirect to(@url) || '/'
end