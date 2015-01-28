class User
	attr_accessor :id

	def initialize(id)
		# Instance variables
		@id = id
	end

	def addLike(url)
		CurrentDatabase.sadd("users:#{@id}:like", url)
	end

	def addDislike(url)
		CurrentDatabase.sadd("users:#{@id}:dislike", url)
	end

	def removeLike(url)
		CurrentDatabase.srem("users:#{@id}:like", url)		
	end

	def removeDislike(url)
		CurrentDatabase.srem("users:#{@id}:dislike", url)		
	end

	def getTopItems
	userKeywords = getUserKeywords

	topItems = []

		userKeywords.each do |userKeyword|

			#get top item for specific keyword
			itemKey = getTopItem(userKeyword)[0].to_s

			sourceId = itemKey.split("/").first

			itemId = itemKey.split("/", 2).last

			topItems << getItemUrl(sourceId, itemId)

		end
		return topItems
	end

	def updateStream
		
	end

	def addStream(weight, globalId)
		CurrentDatabase.zadd("users:@id:stream", weight, globalId)
	end

	def removeStream(globalId)
		CurrentDatabase.zrem("users:@id:stream", globalId)
	end

	def getUserKeywords
		#gets all members of sorted list
		return CurrentDatabase.zrevrange("users:#{@id}:keywords", 0, -1)
	end

	def getUsernameFromId
		return CurrentDatabase.hget("users:#{@id}:meta", "username")
	end
end