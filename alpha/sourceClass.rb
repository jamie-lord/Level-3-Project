class Source

	attr_accessor :id
	attr_accessor :url
	attr_accessor :feed

	def initialize(id)
		# Instance variables
		@id = id
		@url = self.getUrl
		@feed = self.getFeed
	end

	def getUrl
		return CurrentDatabase.hget("source:#{@id}", "url")
	end

	def setLastScanNow
		CurrentDatabase.hmset("source:#{@id}","last_scan",Time.now.to_i)
	end

	def getFeed
		#get the RSS feed from source URL
		return Feedjira::Feed.fetchAndParse @url
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