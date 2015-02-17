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

	def addToLog(message, type)
		logTime = Time.now.strftime("%d/%m/%Y %H:%M:%S")
		today = Time.now.strftime("%d/%m/%Y")
		CurrentDatabase.sadd("logs:#{today}", "#{logTime} - #{type} - #{@name} - #{message}")
		puts "#{logTime} - #{type} - #{@name} - #{message}".black.on_red
		if type == "BUG"
			sendUserBug("#{logTime} - #{type} - #{@name} - #{message}")
		elsif type == "ERROR"
			sendError("#{logTime} - #{type} - #{@name} - #{message}")
		end
	end

	def toggleNew()
		currentState = CurrentDatabase.hmget("users:#{@name}:meta", "new")
		newState = !currentState
		CurrentDatabase.hmset("users:#{@name}:meta", "new", newState)
	end

	def addViewed(url)
		if url =~ /\A#{URI::regexp}\z/
			CurrentDatabase.zadd("users:#{@name}:viewed", Time.now.to_i, url)
		end
	end

	def addLike(url)
		if url =~ /\A#{URI::regexp}\z/
			CurrentDatabase.sadd("users:#{@name}:like", url)
		end
	end

	def addLiked(url)
		if url =~ /\A#{URI::regexp}\z/
			CurrentDatabase.sadd("users:#{@name}:liked", url)
		end
	end

	def addDislike(url)
		if url =~ /\A#{URI::regexp}\z/
			CurrentDatabase.sadd("users:#{@name}:dislike", url)
		end
	end

	def addDisliked(url)
		if url =~ /\A#{URI::regexp}\z/
			CurrentDatabase.sadd("users:#{@name}:disliked", url)
		end
	end

	def addIrrelevant(url)
		if url =~ /\A#{URI::regexp}\z/
			CurrentDatabase.sadd("users:#{@name}:irrelevant", url)
		end
	end

	def removeLike(url)
		CurrentDatabase.srem("users:#{@name}:like", url)		
	end

	def removeDislike(url)
		CurrentDatabase.srem("users:#{@name}:dislike", url)		
	end

	def incrStat(statName)
		CurrentDatabase.hincrby("users:#{@name}:stats", statName, 1)
	end

	def updateStream
		#convert like items to liked
		itemsLike = CurrentDatabase.scard("users:#{@name}:like").to_i
		if itemsLike > 0
			itemsLike.times do |i|
				url = CurrentDatabase.spop("users:#{@name}:like").to_s
				begin
					keywords = getKeywordsFromUrl(url)

					addUserKeywords(keywords, "likedKeywords")
				rescue
				end
				addLiked(url)
			end
		end

		#convert dislike items to disliked
		itemsDislike = CurrentDatabase.scard("users:#{@name}:dislike").to_i
		if itemsDislike > 0
			itemsDislike.times do |i|
				url = CurrentDatabase.spop("users:#{@name}:dislike").to_s
				begin
					keywords = getKeywordsFromUrl(url)

					addUserKeywords(keywords, "dislikedKeywords")
				rescue
				end
				addDisliked(url)
			end
		end

		#trim keywords sets to maximum length of 50
		CurrentDatabase.zremrangebyrank("users:#{@name}:likedKeywords", 0, -51)
		CurrentDatabase.zremrangebyrank("users:#{@name}:dislikedKeywords", 0, -51)

		#get all liked keywords for user
		likedKeywords = getWholeUserSet("likedKeywords")

		#get all disliked keywords for user
		dislikedKeywords = getWholeUserSet("dislikedKeywords")

		#for every liked keyword
		likedKeywords.each do |keyword|

			#get top 5 items for specific keyword
			itemKeys = CurrentDatabase.zrevrange("keywords:#{keyword[0]}", 0, 1, :with_scores => true)

			#for each item
			itemKeys.each do |item|

				#get item key
				itemKey = item[0]

				sourceId = itemKey.split("/").first

				itemId = itemKey.split("/", 2).last

				itemMetaArr = CurrentDatabase.hmget("items:#{sourceId}:#{itemId}:meta", "published", "facebookLikes", "facebookShares", "twitterShares")

				itemAge = Time.now.to_i - itemMetaArr[0].to_i

				socialTotal = itemMetaArr[1].to_i + itemMetaArr[2].to_i + itemMetaArr[3].to_i

				itemScore = socialTotal

				#if item is less than 2 hours old the increase score
				if itemAge < 7200
					itemScore += 7200 - itemAge
				#if item is older that one month then decrease score
				elsif itemAge > 2419200
					itemScore -= 2000
				end				

				if itemKey.length > 0
					addStream(itemKey, itemScore.to_i)
				end
			end
		end

		#sanitise stream i.e. remove previously viewed items
		#get whole stream
		stream = CurrentDatabase.zrevrange("users:#{@name}:stream", 0, -1)

		stream.each do |item|

			itemKey = item.to_s

			sourceId = itemKey.split("/").first

			itemId = itemKey.split("/", 2).last

			url = getItemMeta(sourceId, itemId, "url")

			if isItemViewed(url) == true
				CurrentDatabase.zrem("users:#{@name}:stream", itemKey)
				puts "Removing item #{url} from stream as already viewed"
			end
		end

		#only preserve the top 10 items currently in the stream
		trimStream

	end

	def getTopItem(keyword)
		item = CurrentDatabase.zrevrange("keywords:#{keyword}", 0, 5, :with_scores => true)
		itemId = keywordArr[0].to_s
		return itemId
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

	def addUserKeywords(keywords, key)
		scoreKeyword = Array.new
		keywords.each do |keyword|
			scoreKeyword.push(keyword.weight, keyword.text)
			if CurrentDatabase.zscore("users:#{@name}:#{key}", keyword.text) == nil
				CurrentDatabase.zadd("users:#{@name}:#{key}", keyword.weight, keyword.text)
			else
				CurrentDatabase.zincrby("users:#{@name}:#{key}", keyword.weight, keyword.text)
			end
			
		end
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

			#item[0]
			item << getItemMeta(sourceId, itemId, "url")

			#item[1]
			item << getItemMeta(sourceId, itemId, "title")

			sourceTitle = getSourceMeta(sourceId, "title")

			#item[2]
			if sourceTitle.length > 0
				item << sourceTitle
			else
				item << ""
			end

			itemAuthor = getItemMeta(sourceId, itemId, "author")

			#item[3]
			if itemAuthor.length > 0
				item << itemAuthor
			else
				item << ""
			end

			#item[4]
			published = getItemMeta(sourceId, itemId, "published")

			if (Time.now.to_i - published.to_i) < 7200
				item << "new"
			elsif (Time.now.to_i - published.to_i) > 15768000
				item << "old"
			else
				item << ""
			end

			stream << item
		end
		return stream
	end

	def getStats
		stats = CurrentDatabase.hmget("users:#{@name}:stats", "like", "dislike", "clicked")
		globalStats = CurrentDatabase.hmget("stats:global", "sources", "items", "keywords", "users")
		stats.concat globalStats
		return stats
	end

	def trimStream
		CurrentDatabase.zremrangebyrank("users:#{@name}:stream", 0, -11)
	end

	def addStream(globalId, score)
		sourceId = globalId.split("/").first
		itemId = globalId.split("/", 2).last
		url = getItemMeta(sourceId, itemId, "url").to_s

		if isItemViewed(url) == false
			CurrentDatabase.zadd("users:#{@name}:stream", score, globalId)
		else
			CurrentDatabase.zrem("users:#{@name}:stream", globalId)
		end
	end

	def isItemViewed(url)
		if CurrentDatabase.sismember("users:#{@name}:liked", url) == true
			return true
		elsif CurrentDatabase.sismember("users:#{@name}:disliked", url) == true
			return true
		elsif CurrentDatabase.sismember("users:#{@name}:like", url) == true
			return true
		elsif CurrentDatabase.sismember("users:#{@name}:dislike", url) == true
			return true
		elsif CurrentDatabase.sismember("users:#{@name}:irrelevant", url) == true
			return true
		else
			return false
		end
	end

	def getWholeUserSet(setName)
		#gets all members of sorted list
		return CurrentDatabase.zrevrange("users:#{@name}:#{setName}", 0, -1, :with_scores => true)
	end

	def addPotentialNewSource(url)
		begin
			finalUrl = getUltimateUrl(url)
			begin
				feedUrls = findFeedUrl(finalUrl)
				if feedUrls.empty?
					self.addToLog("Couldn't find feed for #{finalUrl}", "INFO")
				else
					feedUrl = feedUrls[0].strip
					begin
						self.incrStat("sourcesAdded")
						self.addToLog(addNewSource(feedUrl), "SOURCE")
					rescue
						self.addToLog("addPotentialNewSource: Couldn't addNewSource for #{feedUrl}", "ERROR")
					end
				end
			rescue
				self.addToLog("addPotentialNewSource: Couldn't findFeedUrl for #{finalUrl}", "ERROR")
			end
		rescue
			self.addToLog("addPotentialNewSource: Couldn't getUltimateUrl for #{url}", "ERROR")
		end		
	end
end