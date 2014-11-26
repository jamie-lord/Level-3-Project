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

#constant database host
Database_host = "192.168.0.13"

#constant database connetion
Current_database = Redis.new(:host => Database_host, :port => 6379, :db => 0)

Start_time = Time.now.to_i

Suppress_output = true

$sources_completed = 0

$items_completed = 0

$new_items = 0

$updated_items = 0

$not_updated_items = 0

$not_added_items = 0

$full_content_errors = 0

$full_content_timeouts = 0

$keywords_errors = 0

class Source

	attr_accessor :id
	attr_accessor :url
	attr_accessor :feed

	def initialize(id)
		# Instance variables
		@id = id
		@url = self.get_url
		@feed = self.get_feed
	end

	def get_url
		return Current_database.hget("source:#{@id}", "url")
	end

	def set_last_scan_now
		Current_database.hmset("source:#{@id}","last_scan",Time.now.to_i)
	end

	def get_feed
		#get the RSS feed from source URL
		return Feedjira::Feed.fetch_and_parse @url
	end

	def output_source_info
		#source information
  		puts "\n~~~~~~~~~~~~~SOURCE DATA~~~~~~~~~~~~~"
		puts "\nSource identifier:\t#{@id}"
		puts "\nurl:\t\t\t#{@url}"
		puts "\ntitle:\t\t\t#{@feed.title}"
  		puts "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	end

end

class Item

	attr_accessor :id
	attr_accessor :url
	attr_accessor :published
	attr_accessor :source_id
	attr_accessor :author
	attr_accessor :summary
	attr_accessor :keywords
	attr_accessor :full_content
	attr_accessor :title
	attr_accessor :last_scan
	attr_accessor :status


	def initialize(source_id, entry)

		@source_id = source_id

		unix_time_now = Time.now.to_i

		#redirect url and set
	    if entry.url != nil
	    	@url = follow_url_redirect(entry.url)
	    end

	  	#convert datetime to unix timestamp
	    if entry.published != nil
	    	@published = entry.published.to_time.to_i
	    else
	    	@published = unix_time_now
	    end

	    #unique item id
	    if entry.entry_id != nil
	    	@id = strip_url(entry.entry_id)
	    elsif entry.id != nil
	    	@id = strip_url(entry.id)
	    elsif entry.url != nil
	    	@id = strip_url(entry.url)
	    end

	    #scrape full content from url
		@full_content = self.scrape_full_content(@url)

		#remove HTML from summary
	    @summary = sanitise_html(entry.summary)

	    @author = entry.author

	    @title = entry.title

	    @last_scan = unix_time_now

	    #UPDATE EXISTING ITEM
	    if does_item_exist == true

	    	if get_attribute("meta", "last_scan").to_i + Item_update_interval < unix_time_now
	    		if Suppress_output != true
	    			puts "\n------------UPDATING #{@source_id}:#{@id}------------".blue
	    		end 

	    		@status = "updated"

	    		$updated_items += 1

	    		time_since_last_scan(get_attribute("meta", "last_scan"))

	    		#update title
		        update_attribute("meta", "title", @title)

		        #update url
		        update_attribute("meta", "url", @url)

		        #update published date and time
		        update_date_attribute("meta", "published", @published)

		        #update item author
		        update_attribute("meta", "author", @author)

		        #update item summary
		        update_attribute("meta", "summary", @summary)

		        #update item full_content
		        if get_attribute("meta", "full_content") != @full_content
		        	update_attribute("meta", "full_content", @full_content)

		        	#update saved keywords
		        	self.store_keywords

		        end

		        #update last_scan time
		        update_date_attribute("meta", "last_scan", unix_time_now)

		        #update categories
		        if entry.respond_to? :categories
		        	set_categories(entry.categories)
		        end

		    else
		    	if Suppress_output != true
		    		puts "\n----------ITEM #{@source_id}:#{@id} NOT UPDATED: TOO YOUNG----------".yellow
		    	end

		    	@status = "not_updated"

		    	$not_updated_items += 1

		    	time_since_last_scan(get_attribute("meta", "last_scan"))
	    	end

		#ADD NEW ITEM    
		else
			if Suppress_output != true
				puts "\n+++++++++++++++ADDING #{@source_id}:#{@id}+++++++++++++++".green
			end

			if @full_content != "fail"
				begin
					#store meta
	       			self.set_new_item

				    #update saved keywords
				    self.store_keywords

				    #store categories
			        if entry.respond_to? :categories
			        	set_categories(entry.categories)
			        end

			        @status = "new"

					$new_items += 1

				rescue
					@status = "not_added"

		    		$not_added_items += 1
				end
		    else
		    	@status = "not_added"

		    	$not_added_items += 1
			end
		end
	end

	def store_keywords
		begin
			#update keywords
			self.generate_keywords

			#set keywords
			self.set_keywords
		rescue
			if Suppress_output != true
				puts "\n!!!!!!!!!!!!!!!!!ERROR: Failed to get or set keywords!!!!!!!!!!!!!!!!!".red
			end

			$keywords_errors += 1

		end
		
	end

	def time_since_last_scan(timestamp)
		if Suppress_output != true
			puts "\nTime since last scan:\t\t\t#{Time.now.to_i - timestamp.to_i} seconds\n"
		end
	end

	def update_attribute(hash, attribute, value)
		if get_attribute(hash, attribute) != value
			if Suppress_output != true
				puts "Updating:\t#{attribute}".yellow
			end
			set_attribute(hash, attribute, value)
		end
	end

	def update_date_attribute(hash, attribute, value)
		if get_attribute(hash, attribute).to_i != value.to_i
			if Suppress_output != true
				puts "Updating:\t#{attribute}".yellow
			end
			set_attribute(hash, attribute, value.to_i)
		end
	end

	def output_item_meta
		#item information
		puts "\n~~~~~~~~~~~~~~~~META DATA~~~~~~~~~~~~~~~~"
        puts "\nItem identifier:\t#{@id}"
        puts "\nkey:\t\t\titem:#{@source_id}:#{@id}:meta"
        puts "\nstatus:\t\t\t#{@status}"
        puts "\nurl:\t\t\t#{@url}"
        puts "\ntitle:\t\t\t#{@title}"
        puts "\npublished:\t\t#{@published}\t\t#{Time.at(@published)}"
        #puts "\nfull_content:\t\t\t#{item_full_content}"
        puts "\nsummary:\t\t#{@summary.truncate(100)}"
        puts "\nauthor:\t\t\t#{@author}"
        puts "\nlast_scan:\t\t#{@last_scan}\t\t#{Time.at(@published)}"
        puts "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		
	end

	def generate_keywords
		text = Highscore::Content.new @full_content

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

		@keywords = text.keywords.top(50)
		
	end

	def does_item_exist
		if Current_database.exists("items:#{@source_id}:#{@id}:meta") == true
			return true
		else
			return false
		end
	end

	def get_attribute(hash, attribute)
		return Current_database.hget("items:#{@source_id}:#{@id}:#{hash}", attribute)
	end

	def set_attribute(hash, attribute, value)
		Current_database.hmset("items:#{@source_id}:#{@id}:#{hash}", attribute, value)
	end

	def set_keywords
		@keywords.each do |keyword|
			#save keywords
			Current_database.hmset("items:#{@source_id}:#{@id}:keywords","#{keyword.text}","#{keyword.weight}")
		end
	end

	def set_categories(categories)
		if categories.empty? == false
			if Suppress_output != true
				puts "\n~~~~~~~~~~~~~~~~CATEGORIES~~~~~~~~~~~~~~~~"
			end
			categories.each do |category|
	        	Current_database.sadd("items:#{@source_id}:#{@id}:categories", "#{category}")
	        	if Suppress_output != true
	        		puts "-\t#{category}"
	        	end
	        end
	        if Suppress_output != true
	        	puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	        end
	    else
	    	if Suppress_output != true
	    		puts "\n!!!!!!!!!!!!!!!!!WARNING: No categories present!!!!!!!!!!!!!!!!!".yellow
	    	end
		end
	end

	def set_new_item
		Current_database.hmset("items:#{@source_id}:#{@id}:meta", "url", @url, "title", @title, "published", @published, "full_content", @full_content ,"summary", @summary , "author", @author, "last_scan", @last_scan)
	end

	def scrape_full_content(url)
		begin
			full_source = ""

			#get full content within 5 seconds
			Timeout.timeout(5){
	    		begin
	    			full_source = open(url).read.force_encoding('UTF-8')
	    		rescue
	    			if Suppress_output != true
	    				puts "\n!!!!!!!!!!!!!!!!!ERROR: Failed to get full content!!!!!!!!!!!!!!!!!".red
	    			end

	    			$full_content_errors += 1

					return "fail"
	    		end
			}

			#strip HTML tags
			full_content = sanitise_html(full_source)

			#remove blank lines and tabs
			full_content.gsub! /\t/, ''

			full_content.gsub! /^$\n/, ''

			full_content.gsub! /^ $/, ''

			full_content.gsub! /\n+/, "\n"

			full_content.gsub! /^$/, ''

			return full_content
	    
		rescue Timeout::Error
			if Suppress_output != true
				puts "\n!!!!!!!!!!!!!!!!!ERROR: Timeout getting full content!!!!!!!!!!!!!!!!!".red
			end

			$full_content_timeouts += 1

			return "fail"
		end
	end

end

def get_total_sources(databaseConnection)
	return databaseConnection.get("source:next_id").to_i
end

def strip_url(url)
  url.sub!(/https\:\/\/www./, '') if url.include? "https://www."

  url.sub!(/http\:\/\/www./, '') if url.include? "http://www."

  url.sub!(/www./, '') if url.include? "www."

  url.sub!(/http\:\/\//, '') if url.include? "http://"

  url = url.tr('^A-Za-z0-9\.\/','')

  return url
end

def follow_url_redirect(url)
  begin
    open(url) do |response|
      return response.base_uri.to_s
    end
  rescue
    return url
  end
end

def sanitise_html(source)
	return ActionView::Base.full_sanitizer.sanitize(Readability::Document.new(source).content).squeeze(" ").strip
end

def scan_source(id)
	#create source object
	current_source = Source.new(id)

	#output current source information
	#current_source.output_source_info

	#for each item
	current_source.feed.entries.each do |entry|

		#create item object
		current_item = Item.new(id, entry)

		$items_completed += 1

		# if current_item.status != "not_updated"
		# 	current_item.output_item_meta
		# end

		system "clear"

		#runtime statistics
		puts "\n>>>>>>>>>>>>>>>>RUNTIME INFORMATION<<<<<<<<<<<<<<<<<"
		puts "\nTime running:\t\t\t\t#{Time.now.to_i - Start_time} seconds"
		puts "\nSources completed:\t\t\t#{$sources_completed}"
		puts "\nItems completed:\t\t\t#{$items_completed}"
		puts "\nNew items:\t\t\t\t#{$new_items}".green
		puts "\nUpdated items:\t\t\t\t#{$updated_items}".blue
		puts "\nItems not updated:\t\t\t#{$not_updated_items}".yellow
		puts "\nItems not added:\t\t\t#{$not_added_items}".yellow
		puts "\nFull content errors:\t\t\t#{$full_content_errors}".red
		puts "\nFull content timeouts:\t\t\t#{$full_content_timeouts}".red
		puts "\nKeyword errors:\t\t\t\t#{$keywords_errors}".red
		puts "\nLast item:\t\t\t\titem:#{current_item.source_id}:#{current_item.id}"
		puts "\n>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<"

	end

	$sources_completed += 1

end

if __FILE__ == $0

	#starting source id, default = 0
	source_id = 0

	#constant item update interval in seconds
	Item_update_interval = 600

	Number_of_threads = 10

	#runtime information
	puts "\n*********************RUNTIME INFORMATION*********************"
	puts "\nDatabase host:\t\t\t#{Database_host}"
	puts "\nStart source id:\t\t\t#{source_id}"
	puts "\nItem update interval:\t\t\t#{Item_update_interval/60} minutes"
	puts "\n*************************************************************"

	#for each source
	(get_total_sources(Current_database)/Number_of_threads).times {

		threads = []

		Number_of_threads.times do |i|
			#puts source_id
			threads << Thread.new{
				scan_source(source_id+i)
				Thread::exit()
			}

			#temp = gets

		end

		threads.each(&:join)

		#move on to next source id
	  	source_id += Number_of_threads

	}

	

end