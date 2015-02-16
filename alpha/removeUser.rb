#!/usr/bin/env ruby

require_relative 'main.rb'

if __FILE__ == $0
	puts "Enter user name to remove:"
	name = gets
	name = name.delete!("\n")
	if name !~ /^[a-zA-Z0-9]+$/
		puts "User name contains illegal character"
	else
		if doesUserExist(name) == true
			email = CurrentDatabase.hget("users:#{name}:meta", "email")
			CurrentDatabase.del("users:#{name}:meta")
			CurrentDatabase.del("users:#{name}:like")
			CurrentDatabase.del("users:#{name}:liked")
			CurrentDatabase.del("users:#{name}:dislike")
			CurrentDatabase.del("users:#{name}:disliked")
			CurrentDatabase.del("users:#{name}:likedKeywords")
			CurrentDatabase.del("users:#{name}:dislikedKeywords")
			CurrentDatabase.del("users:#{name}:stats")
			CurrentDatabase.del("users:#{name}:stream")
			CurrentDatabase.del("users:#{name}:viewed")
			decrGlobalStat("users")
			addToGeneralLog("User \'#{name}\' removed", "INFO")
			if email.length > 0
				sendAccountRemovalEmail(name, email)
			end
			pust "User removed"
		else
			puts "User does not exist"
		end
	end
end