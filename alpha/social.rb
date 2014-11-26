#!/usr/bin/env ruby

require "redis"
require "base58"
require "feedjira"
require "open-uri"
require "action_view"
require "readability"
require "highscore"
require "timeout"
require "colorize"
require "net/http"
require "json"

def social_facebook_likes(url)
	uri = URI.parse("https://graph.facebook.com/fql?q=select%20%20like_count%20from%20link_stat%20where%20url=%22#{url}%22")

	response = Net::HTTP.get_response(uri)

	result = response.body

	begin
		return JSON.parse(result)['data'][0]['like_count']
	rescue
		return "0"
	end	
end

def social_facebook_shares(url)
	uri = URI.parse("https://graph.facebook.com/fql?q=select%20%20share_count%20from%20link_stat%20where%20url=%22#{url}%22")

	response = Net::HTTP.get_response(uri)

	result = response.body

	begin
		return JSON.parse(result)['data'][0]['share_count']
	rescue
		return "0"
	end	
end

def social_twitter_shares(url)
	uri = URI.parse("https://cdn.api.twitter.com/1/urls/count.json?url=#{url}")

	response = Net::HTTP.get_response(uri)

	result = response.body

	begin
		return JSON.parse(result)['count']
	rescue
		return "0"
	end	
end

url = "http://jhack.co.uk"

puts social_facebook_likes(url)
puts social_facebook_shares(url)
puts social_twitter_shares(url)

10.times{|i| STDOUT.write "\r#{i}"; sleep 1}