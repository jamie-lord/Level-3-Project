require "mail"

options = {
	:openssl_verify_mode => OpenSSL::SSL::VERIFY_NONE,
	:address              => "mail.fleek.in",
	:port                 => 587,
	:domain               => 'localhost',
	:user_name            => 'bugs@fleek.in',
	:password             => '0aa72958bbf63f7bf33ec409e1590e458a073b44f63f470ae4e3f38f96b5d8de',
	:authentication       => 'plain',
	:enable_starttls_auto => true
}

Mail.defaults do
	delivery_method :smtp, options
end

def sendUserBug(bugString)
	mail = Mail.new do
		from    'bugs@fleek.in'
		to      'bugs@fleek.in'
		subject 'User reported bug'
		body    bugString
	end

	mail.deliver!
end