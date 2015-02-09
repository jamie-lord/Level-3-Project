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
require "rss"

#constant database host
DatabaseHost = "192.168.0.13"

DatabaseNumber = 0

#constant database connetion
CurrentDatabase = Redis.new(:host => DatabaseHost, :port => 6379, :db => DatabaseNumber)

def setStaticFields()
	CurrentDatabase.set("sources:nextId", 0)
end

def addSources()

	sourcesFile = File.open("lists/sources").read
	sourcesFile.gsub!(/\r\n?/, "\n")
	sourcesFile.each_line do |url|

		addNewSource(url.strip)

	end

end

def addNewSource(url)
	newId = getNextSourceId
	begin
		url = URI.parse(url)
		req = Net::HTTP.new(url.host, url.port)
		res = req.request_head(url.path)

		if res.code == "200"
			begin
				# What feed are we parsing?
				rss_feed = url

				# Variable for storing feed content
				rss_content = ""

				# Read the feed into rss_content
				open(rss_feed) do |f|
				   rss_content = f.read
				end

				# Parse the feed, dumping its contents to rss
				rss = RSS::Parser.parse(rss_content, false)

				# Output the feed title and website URL
				puts "Title: #{rss.channel.title}"
				puts "RSS URL: #{rss.channel.link}"
				puts "Total entries: #{rss.items.size}"

				title = rss.channel.title.to_s
				
			rescue
				title = ""
			end
			CurrentDatabase.hmset("sources:#{newId}", "url", url)
			CurrentDatabase.hmset("sources:#{newId}", "title", title)
			CurrentDatabase.hmset("sources:#{newId}", "lastScan", Time.now.to_i - 36000)
			CurrentDatabase.incr("sources:nextId")
		end
	rescue
	end
end

def getNextSourceId
	return CurrentDatabase.get("sources:nextId").to_i
end

def addSourceDirectory()
	totalItems = getNextSourceId.to_i

	totalItems.times do |i|

		url = CurrentDatabase.hget("sources:#{i}", "url").to_s

		CurrentDatabase.zadd("sources:directory", i, url)
	end
end

def addUser(name)
	CurrentDatabase.hmset("users:#{name}:meta", "name", name)
	CurrentDatabase.hmset("users:#{name}:meta", "new", "true")
end

if __FILE__ == $0
	setStaticFields

	addSources
	addSourceDirectory
	addUser("jamie")

end