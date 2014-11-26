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



puts social_facebook_likes("http://arstechnica.com/security/2014/11/sony-pictures-hackers-release-list-of-stolen-corporate-files/")
puts social_facebook_shares("http://arstechnica.com/security/2014/11/sony-pictures-hackers-release-list-of-stolen-corporate-files/")
