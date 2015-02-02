class Source

	attr_accessor :id
	attr_accessor :url
	attr_accessor :feed

	def initialize(sourceId)
		# Instance variables
		@id = sourceId
		#puts @id
		@url = self.getUrl
		#puts @url
		if @url != nil
			@feed = self.getFeed
		end
		#puts @feed
	end

	def getUrl
		return CurrentDatabase.hget("sources:#{@id}", "url").to_s
	end

	def setLastScanNow
		CurrentDatabase.hmset("sources:#{@id}", "lastScan", Time.now.to_i)
	end

	def setScanError
		CurrentDatabase.hmset("sources:#{@id}", "scanError", Time.now.to_i)
	end

	def getFeed
		#get the RSS feed from source URL
		return Feedjira::Feed.fetch_and_parse @url
	end

	def outputSourceInfo
		#source information
  		puts "\n~~~~~~~~~~~~~SOURCE DATA~~~~~~~~~~~~~"
		puts "\nSource identifier:\t#{@id}"
		puts "\nurl:\t\t\t#{@url}"
		puts "\ntitle:\t\t\t#{@feed.title}"
  		puts "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	end

end