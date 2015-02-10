require "httpclient"

require_relative 'main.rb'

if __FILE__ == $0
	url = gets

	httpc = HTTPClient.new
	resp = httpc.get(url)
	puts resp.header['Location']

	open(url) do |resp|
	  puts resp.base_uri.to_s
	  puts findFeedUrl(resp.base_uri.to_s)
	end

	
end