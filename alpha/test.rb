require_relative 'main.rb'

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
	    		end
			}

			#find any potential URLs in content
			findAllUrls(fullSource)
	    
		rescue Timeout::Error
			if SuppressOutput != true
				puts "\n!!!!!!!!!!!!!!!!!ERROR: Timeout getting full content!!!!!!!!!!!!!!!!!".red
			end
		end
	end

input = gets

scrapeFullContent(input)