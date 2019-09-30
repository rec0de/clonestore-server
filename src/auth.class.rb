require 'securerandom'

class Authenticator
	@@db = nil
	@@tokenBytes = 32
	@@tokenLifetime = 60 * 60 * 24 * 90 # 90 days default session lifetime

	def self.linkDatabase(db)
		@@db = db
	end

	def self.authenticate(proof)
		if proof == 'testtoken'
			token = SecureRandom::hex(@@tokenBytes)
			@@db.registerSessionToken(token)
			return token
		else
			return nil
		end
	end

	def self.check(token)
		startTime = @@db.getSessionByToken(token)

		return false if startTime == nil

		if startTime < Date.now.to_i - @@tokenLifetime
			@@db.revokeSessionToken(token)
			return false
		else
			return true
		end
	end
end