#!/usr/bin/env ruby

require "redis"
require "base58"
require "feedjira"
require "open-uri"
require "action_view"
require "readability"
require "highscore"

def scrape_full_content(url)

  begin
    #get full content
    full_source = open(url).read

    #strip HTML tags
    full_content = ActionView::Base.full_sanitizer.sanitize(Readability::Document.new(full_source).content).squeeze(" ").strip

    #remove blank lines and tabs
    full_content.gsub! /\t/, ''

    full_content.gsub! /^$\n/, ''

    full_content.gsub! /^ $/, ''

    full_content.gsub! /\n+/, "\n"

    full_content.gsub! /^$/, ''
  rescue
    full_content = "fail"
  end

  return full_content
end

def get_total_sources(databaseConnection)
	return databaseConnection.get("next_source_id").to_i
end

def get_source_url(databaseConnection, current_source_id)
	return databaseConnection.hget("source:#{current_source_id}", "url")
end

def set_source_next_item(databaseConnection, current_source_id)
	if databaseConnection.get("items:#{current_source_id}:next_item_id") == "NULL"
		databaseConnection.set("items:#{current_source_id}:next_item_id","0")
	end
end

def get_source_next_item_id(databaseConnection, current_source_id)
	return databaseConnection.get("items:#{current_source_id}:next_item_id").to_i
end

def generate_keywords(full_content)
	text = Highscore::Content.new full_content

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

  return text.keywords.top(50)
end

def set_item_keywords(databaseConnection, current_source_id, item_id, keywords)

	keywords.each do |keyword|
		#save keywords
		databaseConnection.hmset("items:#{current_source_id}:#{item_id}:keywords","#{keyword.text}","#{keyword.weight}")
	end	
end

def strip_url(url)

  url.sub!(/https\:\/\/www./, '') if url.include? "https://www."

  url.sub!(/http\:\/\/www./, '') if url.include? "http://www."

  url.sub!(/www./, '') if url.include? "www."

  url.sub!(/http\:\/\//, '') if url.include? "http://"

  url = url.tr('^A-Za-z0-9\.\/','')

  return url
end

class Source

	def initialise(id, url, title)
		#instance variables
		@id = id
		@url = url
		@title = title
	end

	def output_metadata()

	end

end

#database connection
current_database = Redis.new(:host => "192.168.0.13", :port => 6379, :db => 0)

current_source_id = 0

item_update_interval = 600

#for each source link
get_total_sources(current_database).times {

	current_source_url = get_source_url(current_database, current_source_id)

  #update source last scan time
  current_database.hmset("source:#{current_source_id}","last_scan",Time.now.to_i)

	#get the RSS feed from source URL
	current_feed = Feedjira::Feed.fetch_and_parse current_source_url

  source_identifier = strip_url(current_source_url)

	#source information
  puts "\n~~~~~~~~~~~~~SOURCE DATA~~~~~~~~~~~~~"
	puts "\nSource identifier:\t#{source_identifier}"
	puts "\nurl:\t\t\t#{current_source_url}"
	puts "\ntitle:\t\t\t#{current_feed.title}"
  puts "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

  #set next_item to 0 if not present
  set_source_next_item(current_database, source_identifier)

  current_feed.entries.each do |entry|

  	#convert datetime to unix timestamp
  	item_published = entry.published.to_time.to_i

    #unique item id
    item_identifier = strip_url(entry.entry_id)

    if current_database.exists("items:#{source_identifier}:#{item_identifier}:meta") == true
      
      last_scan = current_database.hget("items:#{source_identifier}:#{item_identifier}:meta","last_scan").to_i

      #only update if enough time has passed
      if last_scan + item_update_interval < Time.now.to_i
        puts "------------UPDATING #{source_identifier}:#{item_identifier}------------"

        item_title = current_database.hget("items:#{source_identifier}:#{item_identifier}:meta","title")

        #update title
        if item_title != entry.title
          puts "Updating title"
          current_database.hmset("items:#{source_identifier}:#{item_identifier}:meta","title",entry.title)
        end

        item_url = current_database.hget("items:#{source_identifier}:#{item_identifier}:meta","url")

        #update url
        if item_url != entry.url
          puts "Updating url"
          current_database.hmset("items:#{source_identifier}:#{item_identifier}:meta","url",entry.url)
        end

        old_item_published = current_database.hget("items:#{source_identifier}:#{item_identifier}:meta","published").to_i

        #update published date and time
        if old_item_published != item_published
          puts "Updating published date and time"
          puts "Old published time:\t\t#{old_item_published}"
          puts "New published time:\t\t#{item_published}"
          current_database.hmset("items:#{source_identifier}:#{item_identifier}:meta","published",item_published)
        end

        item_author = current_database.hget("items:#{source_identifier}:#{item_identifier}:meta","author")

        #update item author
        if item_author != entry.author
          puts "Updating author"
          current_database.hmset("items:#{source_identifier}:#{item_identifier}:meta","author",entry.author)
        end

        old_item_summary = current_database.hget("items:#{source_identifier}:#{item_identifier}:meta","summary")

        #remove HTML from summary
        item_summary = ActionView::Base.full_sanitizer.sanitize(Readability::Document.new(entry.summary).content).strip

        if old_item_summary != item_summary
          puts "Updating summary"
          current_database.hmset("items:#{source_identifier}:#{item_identifier}:meta","summary",item_summary)
        end

        old_item_content = current_database.hget("items:#{source_identifier}:#{item_identifier}:meta","full_content")

        #generate keywords from full_content
        item_full_content = scrape_full_content(entry.url)

        if old_item_content != item_full_content && item_full_content != "fail"
          puts "Updating full_content"
          current_database.hmset("items:#{source_identifier}:#{item_identifier}:meta","full_content",item_full_content)

          begin
            #update keywords if full content has changed
            keywords = generate_keywords(item_full_content)

            set_item_keywords(current_database, source_identifier, item_identifier, keywords)
            
          rescue
            puts "\n!!!!!!!!!!!!!!!!!ERROR: Keywords!!!!!!!!!!!!!!!!!"
          end

        end

        new_last_scan = Time.now.to_i

        #update scan timestamp
        current_database.hmset("items:#{source_identifier}:#{item_identifier}:meta","last_scan",new_last_scan)

        #item meta:
        # puts "\n~~~~~~~~~~~~~~~~META DATA~~~~~~~~~~~~~~~~"
        # puts "\nItem identifier:\t#{item_identifier}"
        # puts "\nkey:\t\t\titem:#{source_identifier}:#{item_identifier}:meta"
        # puts "\nurl:\t\t\t#{entry.url}"
        # puts "\ntitle:\t\t\t#{entry.title}"
        # puts "\npublished:\t\t#{item_published}"
        # #puts "\nfull_content:\t\t\t#{item_full_content}"
        # puts "\nsummary:\t\t#{item_summary.truncate(100)}"
        # puts "\nauthor:\t\t\t#{entry.author}"
        # puts "\nlast_scan:\t\t#{new_last_scan}"
        # puts "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


        if entry.respond_to? :categories
          
          #item categories
          #puts "\n~~~~~~~~~~~~~~~~CATEGORIES~~~~~~~~~~~~~~~~"

          #create set for item categories
          entry.categories.each do |category|
            current_database.sadd("items:#{source_identifier}:#{item_identifier}:categories", "#{category}")
            #puts "-\t#{category}"
          end

          #puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

        end

      #item not old enough for update
      else
        puts "----------ITEM #{source_identifier}:#{item_identifier} NOT UPDATED: TOO YOUNG----------"

      end

    #end adding existing item
    else
      puts "+++++++++++++++ADDING #{source_identifier}:#{item_identifier}+++++++++++++++"

      #last item scan time
      item_last_scan = Time.now.to_i

      #remove HTML from summary
      item_summary = ActionView::Base.full_sanitizer.sanitize(Readability::Document.new(entry.summary).content).strip

      #generate keywords from full_content
      item_full_content = scrape_full_content(entry.url)

      if item_full_content != "fail"
        begin
          keywords = generate_keywords(item_full_content)

          set_item_keywords(current_database, source_identifier, item_identifier, keywords)
        rescue
          puts "\n!!!!!!!!!!!!!!!!!ERROR: Keywords!!!!!!!!!!!!!!!!!"
        end
      end

      #item meta:
      puts "\n~~~~~~~~~~~~~~~~META DATA~~~~~~~~~~~~~~~~"
      puts "\nItem identifier:\t#{item_identifier}"
      puts "\nkey:\t\t\titem:#{source_identifier}:#{item_identifier}:meta"
      puts "\nurl:\t\t\t#{entry.url}"
      puts "\ntitle:\t\t\t#{entry.title}"
      puts "\npublished:\t\t#{item_published}"
      #puts "\nfull_content:\t\t\t#{item_full_content}"
      puts "\nsummary:\t\t#{item_summary.truncate(100)}"
      puts "\nauthor:\t\t\t#{entry.author}"
      puts "\nlast_scan:\t\t#{item_last_scan}"
      puts "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

      #Add new item
      current_database.hmset("items:#{source_identifier}:#{item_identifier}:meta","url",entry.url,"title",entry.title,"published",item_published,"full_content",item_full_content,"summary",item_summary,"author",entry.author,"last_scan",item_last_scan)

      if entry.respond_to? :categories

        #item meta:
        puts "\n~~~~~~~~~~~~~~~~CATEGORIES~~~~~~~~~~~~~~~~"

        #create set for item categories
        entry.categories.each do |category|
          current_database.sadd("items:#{source_identifier}:#{item_identifier}:categories", "#{category}")
          puts "-\t#{category}"
        end

        puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

      end
    
    #end adding new item  
    end

    

  	#current_database.hmset("items:#{current_source_id}:guid_id", "#{next_item_id}", "#{entry.id}")

  	#next_item_id += 1

  	#increment stored next item id
  	#current_database.set("items:#{source_identifier}:next_item_id","#{next_item_id}")
    
end

#temp wait
#temp = gets

  #move on to next source URL
  current_source_id += 1
}