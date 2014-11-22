#!/usr/bin/env ruby

require "redis"
require "base58"
require "feedjira"
require "open-uri"
require "action_view"
require "readability"

def get_total_sources(databaseConnection)
	return databaseConnection.get("source:next_id").to_i
end

def get_source_url(databaseConnection, current_source_id)
	return databaseConnection.hget("source:#{current_source_id}", "url")
end

#database connection
current_database = Redis.new(:host => "192.168.0.13", :port => 6379, :db => 0)

url = ""

while url != "q"

  send_to_db = false

  puts "Please enter the source URL... (q to quit)"

  url = gets

  url.strip!

  current_source_id = 0

  #check if source already exists
  get_total_sources(current_database).times {
    if get_source_url(current_database, current_source_id).to_s == url.to_s
      puts "The source already exists! source:#{current_source_id}"
    end
    current_source_id += 1
  }

  #test valid source

  #generate source name
  begin
    new_feed = Feedjira::Feed.fetch_and_parse url

    new_source_name = new_feed.title

    send_to_db = true

    if new_source_name == nil
      puts "Source name: nil"
      send_to_db = false
    end
    
  rescue
    puts "Failed to get source RSS"
  end

  if send_to_db == true
    #add source
    new_source_id = get_total_sources(current_database)

    current_database.hmset("source:#{new_source_id}","url",url,"name",new_source_name)

    #increment source:next_id
    current_database.incr("source:next_id")

    puts "Source #{new_source_id} AKA #{new_source_name} sucessfully added"
  end
  
end