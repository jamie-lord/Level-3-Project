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

require_relative 'userClass.rb'
require_relative 'sourceClass.rb'
require_relative 'itemClass.rb'

#constant database host
DatabaseHost = "192.168.0.13"

#constant database connetion
CurrentDatabase = Redis.new(:host => DatabaseHost, :port => 6379, :db => 0)

StartTime = Time.now.to_i

SuppressOutput = true

$sourcesCompleted = 0

$itemsCompleted = 0

$newItems = 0

$updatedItems = 0

$notUpdatedItems = 0

$notAddedItems = 0

$fullContentErrors = 0

$fullConentTimeouts = 0

$keywordsErrors = 0

def getTotalSources(databaseConnection)
	return databaseConnection.get("source:next_id").to_i
end

def incrTotalSources()
	CurrentDatabase.incr("source:next_id")
end

def stripUrl(url)
  url.sub!(/https\:\/\/www./, '') if url.include? "https://www."

  url.sub!(/http\:\/\/www./, '') if url.include? "http://www."

  url.sub!(/www./, '') if url.include? "www."

  url.sub!(/http\:\/\//, '') if url.include? "http://"

  url = url.tr('^A-Za-z0-9\.\/','')

  return url
end

def getSourceId(url)
	sourceId = CurrentDatabase.zscore("source:directory", url)
	if sourceId == nil
		return nil
	else
		return sourceId.to_i
	end
end

def addNewSource(url)
	if getSourceId(url) == nil
		id = getTotalSources(CurrentDatabase)
		incrTotalSources
		newSource = Source.new(id)
		CurrentDatabase.hmset("source:#{id}","url", url)
		CurrentDatabase.zadd("source:directory", id, url)
	else
		puts "Source already exists!"
	end
end

def updateSourceDirectory()
	totalItems = getTotalSources(CurrentDatabase).to_i

	totalItems.times do |i|

		url = CurrentDatabase.hget("source:#{i}", "url").to_s

		CurrentDatabase.zadd("source:directory", i, url)
	end
end

def followUrlRedirect(url)
  begin
    open(url) do |response|
      return response.base_uri.to_s
    end
  rescue
    return url
  end
end

def sanitiseHtml(source)
	return ActionView::Base.fullSanitizer.sanitize(Readability::Document.new(source).content).squeeze(" ").strip
end

def scanSource(id)
	#create source object
	currentSource = Source.new(id)

	#output current source information
	#current_source.output_source_info

	#for each item
	currentSource.feed.entries.each do |entry|

		#create item object
		currentItem = Item.new(id, entry)

		$itemsCompleted += 1

		# if current_item.status != "not_updated"
		# 	current_item.output_item_meta
		# end

		system "clear"

		#runtime statistics
		puts "\n>>>>>>>>>>>>>>>>RUNTIME INFORMATION<<<<<<<<<<<<<<<<<"
		puts "\nTime running:\t\t\t\t#{Time.now.to_i - StartTime} seconds"
		puts "\nSources completed:\t\t\t#{$sourcesCompleted}"
		puts "\nItems completed:\t\t\t#{$itemsCompleted}"
		puts "\nNew items:\t\t\t\t#{$newItems}".green
		puts "\nUpdated items:\t\t\t\t#{$updatedItems}".blue
		puts "\nItems not updated:\t\t\t#{$notUpdatedItems}".yellow
		puts "\nItems not added:\t\t\t#{$notAddedItems}".yellow
		puts "\nFull content errors:\t\t\t#{$fullContentErrors}".red
		puts "\nFull content timeouts:\t\t\t#{$fullConentTimeouts}".red
		puts "\nKeyword errors:\t\t\t\t#{$keywordsErrors}".red
		puts "\nLast item:\t\t\t\titem:#{currentItem.sourceId}:#{currentItem.id}"
		puts "\n>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<"

	end

	$sourcesCompleted += 1

end

def socialFacebookLikes(url)
	begin
		uri = URI.parse("https://graph.facebook.com/fql?q=select%20%20like_count%20from%20link_stat%20where%20url=%22#{url}%22")

		response = Net::HTTP.get_response(uri)

		result = response.body
	rescue
		result = "0"
	end
	begin
		return JSON.parse(result)['data'][0]['like_count']
	rescue
		return "0"
	end	
end

def socialFacebookShares(url)
	begin
		uri = URI.parse("https://graph.facebook.com/fql?q=select%20%20share_count%20from%20link_stat%20where%20url=%22#{url}%22")

		response = Net::HTTP.get_response(uri)

		result = response.body
	rescue
		result = "0"
	end
	begin
		return JSON.parse(result)['data'][0]['share_count']
	rescue
		return "0"
	end	
end

def socialTwitterShares(url)
	begin
		uri = URI.parse("https://cdn.api.twitter.com/1/urls/count.json?url=#{url}")

		response = Net::HTTP.get_response(uri)

		result = response.body
	rescue
		result = "0"
	end
	begin
		return JSON.parse(result)['count']
	rescue
		return "0"
	end	
end

def getTopItem(keyword)
	return CurrentDatabase.zrevrange("keywords:#{keyword}", 0, 0)
end

def getItemUrl(sourceId, itemId)
	return CurrentDatabase.hget("items:#{sourceId}:#{itemId}:meta", "url")
end

def getAttribute(hash, attribute)
	return CurrentDatabase.hget("items:#{@sourceId}:#{@id}:#{hash}", attribute)
end

if __FILE__ == $0

	#constant item update interval in seconds
	ItemUpdateInterval = 1800

	NumberOfThreads = 15

	#runtime information
	puts "\n*********************RUNTIME INFORMATION*********************"
	puts "\nDatabase host:\t\t\t#{DatabaseHost}"
	puts "\nItem update interval:\t\t\t#{ItemUpdateInterval/60} minutes"
	puts "\n*************************************************************"

	while true

		TotalItems = getTotalSources(CurrentDatabase)

		#starting source id, default = 0
		sourceId = 0

		#for each source
		(TotalItems/NumberOfThreads).times {

			threads = []

			NumberOfThreads.times do |i|
				threads << Thread.new{
					scanSource(sourceId+i)
					Thread::exit()
				}
			end

			threads.each(&:join)

			#move on to next source id
		  	sourceId += NumberOfThreads

		}

		RemainingItems = TotalItems%NumberOfThreads

		sourceId = TotalItems-RemainingItems

		threads = []

		RemainingItems.times do |i|
			threads << Thread.new{
				scanSource(sourceId+i)
				Thread::exit()
			}
		end

		threads.each(&:join)

	end

end