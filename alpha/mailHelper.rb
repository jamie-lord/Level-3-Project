require "mail"

settings = {
	:openssl_verify_mode => OpenSSL::SSL::VERIFY_NONE,
	:address              => "mail.fleek.in",
	:port                 => 587,
	:user_name => "auto_send@fleek.in",
	:password => '0f277857513378875cbbdb6b754602681d6e8959073c14b49f166f498ad63bd0',
	:domain               => 'localhost',
	:authentication       => 'plain',
	:enable_starttls_auto => true
}

Mail.defaults do
	delivery_method :smtp, settings
end

def sendUserBug(bugString)
	mail = Mail.new do
		from    'auto_send@fleek.in'
		to      'bugs@fleek.in'
		subject 'User reported bug'
		body    bugString
	end

	mail.deliver!
end

def sendError(errorString)
	mail = Mail.new do
		from    'auto_send@fleek.in'
		to      'errors@fleek.in'
		subject 'Error generated'
		body    errorString
	end

	mail.deliver!
end

def sendScheduledReport(reportString)
	mail = Mail.new do
		from    'auto_send@fleek.in'
		to      'jamie@fleek.in'
		subject 'Scheduled task report'
		body    reportString
	end

	mail.deliver!
end

def sendWelcomeEmail(name, email)
	mail = Mail.new do
		from    'auto_send@fleek.in'
		to      email
		subject "You've now got a fleek.in account"
		body    "Welcome to fleek.in! Your account name's #{name}. You can start using fleek.in here: http://fleek.in/#{name}"
	end

	mail.deliver!
end

def sendAccountRemovalEmail(name, email)
	mail = Mail.new do
		from    'auto_send@fleek.in'
		to      email
		subject "Your fleek.in account has been deleted"
		body    "Your fleek.in account, '#{name}', has been perminantley removed."
	end

	mail.deliver!
end