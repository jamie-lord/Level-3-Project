#!/usr/bin/env ruby

require_relative 'main.rb'

if __FILE__ == $0
	puts "Enter new user name:"
	name = gets
	name = name.delete!("\n")
	if name !~ /^[a-zA-Z0-9]+$/
		puts "User name contains illegal character"
	else
		if doesUserExist(name) == true
			puts "User already exists"
		else
			puts "Enter email address:"
			email = gets
			email = email.delete!("\n")
			addNewUser(name)
			addUserEmail(name, email)
			sendWelcomeEmail(name, email)
			addToGeneralLog("Added new user \'#{name}\' with email \'#{email}\'", "INFO")
			puts "New user added"
		end
	end
end