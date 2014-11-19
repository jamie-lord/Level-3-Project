#!/usr/bin/env ruby

require "redis"
require "base58"
require "feedjira"
require "open-uri"
require "action_view"
require "readability"
require "highscore"

#database connection
redis = Redis.new(:host => "192.168.0.13", :port => 6379, :db => 0)

current_source_id = 0

total_sources = redis.get("next_source_id").to_i

#for each source link
total_sources.times {

  current_source_url = redis.hget("source:#{current_source_id}", "url")

  current_feed = Feedjira::Feed.fetch_and_parse current_source_url

  puts "\nSource ID: #{current_source_id}"

  puts "\nSource link: #{current_source_url}"

  puts "\nTitle: #{current_feed.title}"

  #setup first item ID if not present
  if redis.get("items:#{current_source_id}:next_item_id") == "NULL"
    redis.set("items:#{current_source_id}:next_item_id","0")
  end

  current_feed.entries.each do |entry|

    next_item_id = redis.get("items:#{current_source_id}:next_item_id").to_i

    #meta data
    puts "\ntitle: #{entry.title}"
    puts "\nurl: #{entry.url}"
    puts "\nauthor: #{entry.author}"
    puts "\npublished: #{entry.published}"
    #puts "\nContent: #{entry.content}"
    puts "\nsummary: #{entry.summary}"
    #puts "\nImage: #{entry.image}"
    puts "\npermalink: #{entry.entry_id}"
    puts "\ncategories: #{entry.categories}"

    

    #generate keywords from full_content
    text = Highscore::Content.new get_full_content(entry.url)
    text.configure do
      #set :multiplier, 2
      #set :upper_case, 3
      #set :long_words, 2
      #set :long_words_threshold, 15
      #set :short_words_threshold, 3      # => default: 2
      #set :bonus_multiplier, 2           # => default: 3
      #set :vowels, 1                     # => default: 0 = not considered
      #set :consonants, 5                 # => default: 0 = not considered
      set :ignore_case, true             # => default: false
      #set :word_pattern, /[\w]+[^\s0-9]/ # => default: /\w+/
      #set :stemming, true                # => default: false
    end

  #get only the top 50 keywords
  text.keywords.top(50).each do |keyword|
    puts keyword.text   # => keyword text
    puts keyword.weight # => rank weight (float)

    #save keywords
    redis.hmset("items:#{current_source_id}:#{next_item_id}:keywords","#{keyword.text}","#{keyword.weight}")

  end

  

   #update source last scan time
   redis.hmset("source:#{current_source_id}","last_scan",Time.now.to_i)

  #Add new item
  redis.hmset("items:#{current_source_id}:#{next_item_id}:meta","url",entry.url,"permalink",entry.id,"title",entry.title,"published",entry.published,"full_content",full_content,"summary",entry.summary,"author",entry.author,"full_content",full_content,"last_scan",Time.now.to_i)

  #create set for item categories
  entry.categories.each do |category|
    redis.sadd("items:#{current_source_id}:#{next_item_id}:categories", "#{category}")
  end

  next_item_id += 1

  #increment stored next item id
  redis.set("items:#{current_source_id}:next_item_id","#{next_item_id}")
  #temp wait
  temp = gets.chomp

end




  #move on to next source URL
  current_source_id += 1
}

def get_full_content(url)
  #get full content
  full_source = open(url).read

  #strip HTML tags
  full_content = ActionView::Base.full_sanitizer.sanitize(Readability::Document.new(full_source).content).strip

  return full_content
end

class DatabaseInteraction
  def 



end