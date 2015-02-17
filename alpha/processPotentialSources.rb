require_relative 'main.rb'

def processSource(source)
	begin
		#get full content within 5 seconds
		Timeout.timeout(20){
			source = CurrentDatabase.spop("sources:potential")
			if CurrentDatabase.sismember("sources:done", source) == true
				puts "#{source} already processed"
			else
				System.addPotentialNewSource(source)
				CurrentDatabase.sadd("sources:done", source)
			end
		}
	rescue Timeout::Error
			puts "\n!!!!!!!!!!!!!!!!!ERROR: Timeout !!!!!!!!!!!!!!!!!".red
	end
end

startTime = Time.now.strftime("%d/%m/%Y %H:%M:%S")

NumberOfPotentialSources = CurrentDatabase.scard("sources:potential").to_i

puts NumberOfPotentialSources

System = User.new("SYSTEM")

NumberOfThreads = 64

count = 0

#for each source
(NumberOfPotentialSources/NumberOfThreads).times {

	threads = []

	NumberOfThreads.times do |i|
		threads << Thread.new{
			processSource(CurrentDatabase.spop("sources:potential"))
			count += 1
			Thread::exit()
		}
	end

	threads.each(&:join)

	puts "#{count} of #{NumberOfPotentialSources} done"

}

RemainingItems = NumberOfPotentialSources%NumberOfThreads

threads = []

RemainingItems.times do |i|
	threads << Thread.new{
		puts "#{count} of #{NumberOfPotentialSources}"
		processSource(CurrentDatabase.spop("sources:potential"))
		Thread::exit()
	}
end

threads.each(&:join)

finishTime = Time.now.strftime("%d/%m/%Y %H:%M:%S")

puts "Started at #{startTime}".green

puts "Finished at #{finishTime}".green

runTime = (Time.parse(finishTime).to_i - Time.parse(startTime).to_i) / 60

puts "Time taken #{runTime} minutes".green