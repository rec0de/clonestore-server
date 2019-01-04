require 'uri'
require 'net/http'
require 'json'

class PrintRemote

	def initialize(url, secret)
		raise CloneStorePrintRemoteError, "Invalid printer URL" if ! url =~ URI::regexp
		@uri = URI.parse(url)
		@secret = secret
		@digest = OpenSSL::Digest.new('sha256')
	end

	def status
		req = Net::HTTP::Get.new(@uri)
		res = Net::HTTP.start(@uri.host, @uri.port, use_ssl: (@uri.scheme == 'https')) {|http|
		  http.request(req)
		}

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

	def print(plasmid)
		# Gather necessary data and calculate MAC
		link = "http://cs.rec0de.net/#{plasmid.id}"
		text = "#{plasmid.name}\n#{Time.at(plasmid.timeOfCreation)} | #{plasmid.initials}"
		current = (Time.now().to_i / 30).floor
		mac = OpenSSL::HMAC.hexdigest(@digest, @secret, "#{link}|#{text}#{current}")

		# Send POST request to print server
		begin
			res = Net::HTTP.start(@uri.host, @uri.port, use_ssl: (@uri.scheme == 'https')) do |http|
				req = Net::HTTP::Post.new(@uri)
				req.set_form_data('mac' => mac, 'text' => text, 'qrdata' => link)
				http.request(req)
			end

			response = JSON.parse(res.body)
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