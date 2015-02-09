class User
	attr_accessor :name
	attr_accessor :newUser

	def initialize(name)
		# Instance variables
		@name = name
		@newUser = self.isNew
	end

	def isNew()
		if CurrentDatabase.hget("users:#{@name}:meta", "new") == "true"
			return true
		else
			return false
		end
	end

	def toggleNew()
		CurrentDatabase.hmset("users:#{@name}:meta", "new", "false")
	end

	def addViewed(url)
		CurrentDatabase.zadd("users:#{@name}:viewed", Time.now.to_i, url)
	end

	def addLike(url)
		CurrentDatabase.sadd("users:#{@name}:like", url)
	end

	def addLiked(url)
		CurrentDatabase.sadd("users:#{@name}:liked", url)
	end

	def addDislike(url)
		CurrentDatabase.sadd("users:#{@name}:dislike", url)
	end

	def addDisliked(url)
		CurrentDatabase.sadd("users:#{@name}:disliked", url)
	end

	def removeLike(url)
		CurrentDatabase.srem("users:#{@name}:like", url)		
	end

	def removeDislike(url)
		CurrentDatabase.srem("users:#{@name}:dislike", url)		
	end

	def updateStream

		itemsLike = CurrentDatabase.scard("users:#{@name}:like").to_i

		if itemsLike > 0
			itemsLike.times do |i|
				url = getLike

				begin
					keywords = getKeywordsFromUrl(url)

					addUserKeywords(keywords)
				rescue
					
				end

				addLiked(url)

			end
		end

		keywords = getUserKeywords

		keywords.each do |keyword|

			#get top item for specific keyword
			itemKey = getTopItem(keyword[0])

			sourceId = itemKey.split("/").first

			itemId = itemKey.split("/", 2).last

			if itemKey != nil || itemKey != ""
				addStream(itemKey, keyword[1])
			end
		end

		trimStream

	end

	def getKeywordsFromUrl(url)
		text = Highscore::Content.new url

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

		return text.keywords.top(20)
	end

	def addUserKeywords(keywords)
		scoreKeyword = Array.new
		keywords.each do |keyword|
			scoreKeyword.push(keyword.weight, keyword.text)

			if CurrentDatabase.zscore("users:#{@name}:likedKeywords", keyword.text) == nil
				CurrentDatabase.zadd("users:#{@name}:likedKeywords", keyword.weight, keyword.text)
			else
				CurrentDatabase.zincrby("users:#{@name}:likedKeywords", keyword.weight, keyword.text)
			end
			
		end
	end

	def getLike
		return CurrentDatabase.spop("users:#{@name}:like").to_s
	end

	def getStream
		rawStream = CurrentDatabase.zrevrange("users:#{@name}:stream", 0, -1)
		stream = []
		rawStream.each do |item|
			#get top item for specific keyword
			itemKey = item.to_s

			sourceId = itemKey.split("/").first

			itemId = itemKey.split("/", 2).last

			item = []

			item << getItemMeta(sourceId, itemId, "url")

			item << getItemMeta(sourceId, itemId, "title")

			sourceTitle = getSourceMeta(sourceId, "title")

			if sourceTitle == nil || sourceTitle == ""
				item << ""
			else
				item << sourceTitle
			end

			itemAuthor = getItemMeta(sourceId, itemId, "author")

			if itemAuthor == nil || itemAuthor == ""
				item << ""
			else
				item << itemAuthor
			end

			stream << item
		end
		return stream
	end

	def trimStream
		CurrentDatabase.zremrangebyrank("users:#{@name}:stream", 0, -11)
	end

	def addStream(globalId, score)
		sourceId = globalId.split("/").first
		itemId = globalId.split("/", 2).last
		url = getItemMeta(sourceId, itemId, "url").to_s

		if isItemViewed(url) == false
			puts "Adding item\t\t\t#{globalId}\t#{url}".blue
			CurrentDatabase.zadd("users:#{@name}:stream", score, globalId)
		else
			removeStream(globalId)
		end
	end

	def isItemViewed(url)
		if CurrentDatabase.sismember("users:#{@name}:liked", url) == true
			puts "URL liked".yellow
			return true
		elsif CurrentDatabase.sismember("users:#{@name}:disliked", url) == true
			puts "URL disliked".yellow
			return true
		elsif CurrentDatabase.sismember("users:#{@name}:like", url) == true
			puts "URL like".yellow
			return true
		elsif CurrentDatabase.sismember("users:#{@name}:dislike", url) == true
			puts "URL dislike".yellow
			return true
		else
			return false
		end
	end

	def removeStream(globalId)
		CurrentDatabase.zrem("users:#{@name}:stream", globalId)
	end

	def getUserKeywords
		#gets all members of sorted list
		return CurrentDatabase.zrevrange("users:#{@name}:likedKeywords", 0, -1, :with_scores => true)
	end
end