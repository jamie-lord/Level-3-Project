def followUrlRedirect(url)
	url = url.split("#")[0]
	begin
		httpc = HTTPClient.new
		resp = httpc.get(url)
		open(url) do |resp|
			return resp.base_uri.to_s
		end
	rescue
		return url
	end
end

input = gets

puts followUrlRedirect(input)