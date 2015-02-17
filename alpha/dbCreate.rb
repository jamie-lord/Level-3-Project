#!/usr/bin/env ruby

require_relative 'main.rb'

def addSources()
	sourcesFile = File.open("lists/sources").read
	sourcesFile.gsub!(/\r\n?/, "\n")
	sourcesFile.each_line do |url|
		finalUrl = getUltimateUrl(url)
		puts addNewSource(finalUrl.strip)
	end
end

def getNextSourceId
	return CurrentDatabase.get("sources:nextId").to_i
end

def addSourceDirectory()
	totalItems = getNextSourceId.to_i
	totalItems.times do |i|
		url = CurrentDatabase.hget("sources:#{i}", "url").to_s
		CurrentDatabase.zadd("sources:directory", i, url)
	end
end

if __FILE__ == $0
	addNewUser("jamie")
	addNewUser("john")
	addNewUser("charles")
	addNewUser("jake")
	addNewUser("jordan")
	addNewUser("lucy")
	addNewUser("tarik")
	addNewUser("test")
	CurrentDatabase.set("sources:nextId", 0)
	addSources
	addSourceDirectory
end