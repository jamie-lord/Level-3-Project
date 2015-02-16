require_relative 'main.rb'

numberOfPotentialSources = CurrentDatabase.scard("sources:potential").to_i

puts numberOfPotentialSources

system = User.new("SYSTEM")

numberOfPotentialSources.times do |i|
	begin
		#get full content within 5 seconds
		Timeout.timeout(20){
			source = CurrentDatabase.spop("sources:potential")
			puts "#{i} of #{numberOfPotentialSources}\t\t#{source}"
			system.addPotentialNewSource(source)
		}
	rescue Timeout::Error
			puts "\n!!!!!!!!!!!!!!!!!ERROR: Timeout !!!!!!!!!!!!!!!!!".red
	end
end