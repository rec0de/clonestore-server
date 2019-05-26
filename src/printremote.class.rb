require 'uri'
require 'net/http'
require 'json'

class PrintRemote

	def initialize(url, secret, frontendURL)
		raise CloneStorePrintRemoteError, "Invalid printer URL" if ! url =~ URI::regexp
		@uri = URI.parse(url)
		@secret = secret
		@digest = OpenSSL::Digest.new('sha256')
		@urlTemplate = frontendURL
	end

	def status
		begin
			req = Net::HTTP::Get.new(@uri)
			res = Net::HTTP.start(@uri.host, @uri.port, use_ssl: (@uri.scheme == 'https')) {|http|
		  		http.request(req)
			}
		rescue Errno::EHOSTUNREACH
			raise CloneStorePrintRemoteError, "Print Server is unreachable"
		end

		begin
			response = JSON.parse(res.body)
			if response['type'] != 'clonestore-printer'
				raise CloneStorePrintRemoteError, "Specified printer URL is not a clonestore-printer"
			end
			return response['online']
		rescue JSON::ParserError
			raise CloneStorePrintRemoteError, "Network request got malformed response"
		end
	end

	def print(object, copies = 1, additionalInfo = nil)

		raise CloneStoreRuntimeError, "Can't print non-printable object" unless (object.is_a? Plasmid) || (object.is_a? Microorganism)

		# Get label data from object instance
		link = object.getLink(@urlTemplate)
		text = object.getLabelText(additionalInfo)
		
		printPlain(link, text, copies)
	end

	def printPlain(link, text, copies)
		# Calculate MAC
		current = (Time.now().to_i / 30).floor
		mac = OpenSSL::HMAC.hexdigest(@digest, @secret, "#{link}|#{text}|#{copies}|#{current}")

		# Send POST request to print server
		begin
			res = Net::HTTP.start(@uri.host, @uri.port, use_ssl: (@uri.scheme == 'https')) do |http|
				req = Net::HTTP::Post.new(@uri)
				req.set_form_data('mac' => mac, 'text' => text, 'qrdata' => link, 'copies' => copies)
				http.request(req)
			end

			response = JSON.parse(res.body)
		rescue Errno::EHOSTUNREACH
			raise CloneStorePrintRemoteError, "Print Server is unreachable"
		rescue Errno::EHOSTUNREACH
			raise CloneStorePrintRemoteError, "Connection to printer refused"
		rescue JSON::ParserError
			raise CloneStorePrintRemoteError, "Network request got malformed response"
		end

		if response['success'] != true
			raise CloneStorePrintRemoteError, response['statustext']
		end
	end
end

class CloneStorePrintRemoteError < CloneStoreRuntimeError
end