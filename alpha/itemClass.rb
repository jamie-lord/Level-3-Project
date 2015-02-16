class Item

	attr_accessor :id
	attr_accessor :globalId	#the sourceId & id
	attr_accessor :url
	attr_accessor :published
	attr_accessor :sourceId
	attr_accessor :author
	attr_accessor :summary
	attr_accessor :keywords
	attr_accessor :fullContent
	attr_accessor :title
	attr_accessor :lastScan
	attr_accessor :status

	#social values
	attr_accessor :facebookLikes
	attr_accessor :facebookShares
	attr_accessor :twitterShares

	def initialize(sourceId, entry)

		@sourceId = sourceId

		unixTimeNow = Time.now.to_i

	    #unique item id
	    if entry.entry_id != nil
	    	@id = stripUrl(entry.entry_id)
	    elsif entry.id != nil
	    	@id = stripUrl(entry.id)
	    elsif entry.url != nil
	    	@id = stripUrl(entry.url)
	    end

	    #UPDATE EXISTING ITEM
	    if doesItemExist == true

	    	if getAttribute("meta", "lastScan").to_i + ItemUpdateInterval < unixTimeNow
	    		if SuppressOutput != true
	    			puts "\n------------UPDATING #{@sourceId}:#{@id}------------".blue
	    		end

	    		self.configurePrimary(entry, unixTimeNow)

	    		@status = "updated"

	    		$updatedItems += 1

	    		timeSinceLastscan(getAttribute("meta", "lastScan"))

		        #update published date and time
		        updateDateAttribute("meta", "published", @published)

				#update saved keywords
		        self.generateAndSetKeywords

		        CurrentDatabase.hmset("items:#{@sourceId}:#{@id}:meta", "title", @title, "url", @url, "author", @author, "summary", @summary, "facebookLikes", @facebookLikes, "facebookShares", @facebookShares, "twitterShares", @twitterShares)

		        #update lastScan time
		        updateDateAttribute("meta", "lastScan", unixTimeNow)

		        #update categories
		        if entry.respond_to? :categories
		        	setCategories(entry.categories)
		        end

		    else
		    	if SuppressOutput != true
		    		puts "\n----------ITEM #{@sourceId}:#{@id} NOT UPDATED: TOO YOUNG----------".yellow
		    	end

		    	@status = "not_updated"

		    	$notUpdatedItems += 1

		    	timeSinceLastscan(getAttribute("meta", "lastScan"))
	    	end

		#ADD NEW ITEM    
		else
			if SuppressOutput != true
				puts "\n+++++++++++++++ADDING #{@sourceId}:#{@id}+++++++++++++++".green
			end

			self.configurePrimary(entry, unixTimeNow)

			if @fullContent != "fail"
				begin
					#store meta
	       			self.setNewItem

				    #update saved keywords
				    self.generateAndSetKeywords

				    #store categories
			        if entry.respond_to? :categories
			        	setCategories(entry.categories)
			        end

			        @status = "new"

					$newItems += 1

					incrGlobalStat("items")

				rescue
					@status = "not_added"

		    		$notAddedItems += 1
				end
		    else
		    	@status = "not_added"

		    	$notAddedItems += 1
			end
		end
	end

	def generateAndSetKeywords
		begin
			#update keywords
			self.generateKeywords

			#set keywords
			self.setKeywords
		rescue
			if SuppressOutput != true
				puts "\n!!!!!!!!!!!!!!!!!ERROR: Failed to get or set keywords!!!!!!!!!!!!!!!!!".red
			end

			$keywordsErrors += 1

		end	
	end

	def configurePrimary(entry, unixTimeNow)
		#redirect url and set
	    if entry.url != nil
	    	@url = getUltimateUrl(entry.url)
	    end

	  	#convert datetime to unix timestamp
	    if entry.published != nil
	    	@published = entry.published.to_time.to_i
	    else
	    	@published = unixTimeNow
	    end

	    #scrape full content from url
		@fullContent = self.scrapeFullContent(@url)

		#remove HTML from summary
	    @summary = sanitiseHtml(entry.summary)

	    @author = entry.author

	    @title = entry.title

	    @lastScan = unixTimeNow

	    @globalId = sourceId.to_s + "/" + id.to_s

	    self.gatherAllSocial
	end

	def gatherAllSocial
		@facebookLikes = socialFacebookLikes(@url)
		@facebookShares = socialFacebookShares(@url)
		@twitterShares = socialTwitterShares(@url)
	end

	def timeSinceLastscan(timestamp)
		if SuppressOutput != true
			puts "\nTime since last scan:\t\t\t#{Time.now.to_i - timestamp.to_i} seconds\n"
		end
	end

	def updateDateAttribute(hash, attribute, value)
		if getAttribute(hash, attribute).to_i != value.to_i
			if SuppressOutput != true
				puts "Updating:\t#{attribute}".yellow
			end
			setAttribute(hash, attribute, value.to_i)
		end
	end

	def output_item_meta
		#item information
		puts "\n~~~~~~~~~~~~~~~~META DATA~~~~~~~~~~~~~~~~"
        puts "\nItem identifier:\t#{@id}"
        puts "\nkey:\t\t\titem:#{@sourceId}:#{@id}:meta"
        puts "\nstatus:\t\t\t#{@status}"
        puts "\nurl:\t\t\t#{@url}"
        puts "\ntitle:\t\t\t#{@title}"
        puts "\npublished:\t\t#{@published}\t\t#{Time.at(@published)}"
        puts "\nsummary:\t\t#{@summary.truncate(100)}"
        puts "\nauthor:\t\t\t#{@author}"
        puts "\nlastScan:\t\t#{@lastScan}\t\t#{Time.at(@published)}"
        puts "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		
	end

	def generateKeywords
		text = Highscore::Content.new @fullContent

		text.configure do
			#set :multiplier, 2
			#set :upper_case, 3
			#set :long_words, 2
			#set :long_words_threshold, 15
			set :short_words_threshold, 3      # => default: 2
			#set :bonus_multiplier, 2           # => default: 3
			#set :vowels, 1                     # => default: 0 = not considered
			#set :consonants, 5                 # => default: 0 = not considered
			set :ignore_case, true             # => default: false
			#set :word_pattern, /[\w]+[^\s0-9]/ # => default: /\w+/
			set :stemming, true                # => default: false
	  	end

		@keywords = text.keywords.top(20)
		
	end

	def doesItemExist
		if CurrentDatabase.exists("items:#{@sourceId}:#{@id}:meta") == true
			return true
		else
			return false
		end
	end

	def getAttribute(hash, attribute)
		return CurrentDatabase.hget("items:#{@sourceId}:#{@id}:#{hash}", attribute)
	end

	def setAttribute(hash, attribute, value)
		CurrentDatabase.hmset("items:#{@sourceId}:#{@id}:#{hash}", attribute, value)
	end

	def setKeywords
		scoreKeyword = Array.new
		@keywords.each do |keyword|
			scoreKeyword.push(keyword.weight, keyword.text)
			if doesKeywordExist(keyword.text) == false
				incrGlobalStat("keywords")
			end
			CurrentDatabase.zadd("keywords:#{keyword.text}", keyword.weight, @globalId)		
		end
		CurrentDatabase.zadd("items:#{@sourceId}:#{@id}:keywords", scoreKeyword)
	end

	def doesKeywordExist(keyword)
		return CurrentDatabase.exists("keywords:#{keyword}")
	end

	def setCategories(categories)
		if categories.empty? == false
			if SuppressOutput != true
				puts "\n~~~~~~~~~~~~~~~~CATEGORIES~~~~~~~~~~~~~~~~"
			end
			categories.each do |category|
	        	CurrentDatabase.sadd("items:#{@sourceId}:#{@id}:categories", "#{category}")
	        	if SuppressOutput != true
	        		puts "-\t#{category}"
	        	end
	        end
	        if SuppressOutput != true
	        	puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	        end
	    else
	    	if SuppressOutput != true
	    		puts "\n!!!!!!!!!!!!!!!!!WARNING: No categories present!!!!!!!!!!!!!!!!!".yellow
	    	end
		end
	end

	def setNewItem
		CurrentDatabase.hmset("items:#{@sourceId}:#{@id}:meta", "url", @url, "title", @title, "published", @published, "summary", @summary , "author", @author, "facebookLikes", @facebookLikes, "facebookShares", @facebookShares, "twitterShares", @twitterShares, "lastScan", @lastScan)
	end

	def scrapeFullContent(url)
		begin
			fullSource = ""

			#get full content within 5 seconds
			Timeout.timeout(10){
	    		begin
	    			fullSource = open(url).read.force_encoding('UTF-8')
	    		rescue
	    			if SuppressOutput != true
	    				puts "\n!!!!!!!!!!!!!!!!!ERROR: Failed to get full content!!!!!!!!!!!!!!!!!".red
	    			end

	    			$fullContentErrors += 1

					return "fail"
	    		end
			}

			#find any potential URLs in content
			findAllUrls(fullSource)
			
			#strip HTML tags
			fullContent = sanitiseHtml(fullSource)

			#remove blank lines and tabs
			fullContent.gsub! /\t/, ''

			fullContent.gsub! /^$\n/, ''

			fullContent.gsub! /^ $/, ''

			fullContent.gsub! /\n+/, "\n"

			fullContent.gsub! /^$/, ''

			return fullContent
	    
		rescue Timeout::Error
			if SuppressOutput != true
				puts "\n!!!!!!!!!!!!!!!!!ERROR: Timeout getting full content!!!!!!!!!!!!!!!!!".red
			end

			$fullContentTimeouts += 1

			return "fail"
		end
	end

end