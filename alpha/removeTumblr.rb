require_relative 'main.rb'

numberOfpotentialSources = CurrentDatabase.scard("sources:potential")

numberOfTumblrs = 0

addressesScanned = 0

numberOfpotentialSources.times do |source|

	uri = URI.parse(CurrentDatabase.spop("sources:potential")).to_s

	if uri.include? "tumblr"
		numberOfTumblrs = numberOfTumblrs + 1
	else
		CurrentDatabase.sadd("sources:potentialClean", uri)
	end

	addressesScanned  = addressesScanned + 1

	puts "#{addressesScanned} of #{numberOfpotentialSources} checked #{numberOfTumblrs} were Tumblr links"

end