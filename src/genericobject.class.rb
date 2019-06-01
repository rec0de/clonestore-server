require 'json'

class GenericObject attr_reader :id, :createdBy, :initials, :labNotes, :description, :refType, :refID, :storageLocation, :timeOfEntry, :timeOfCreation

	def initialize(createdBy, initials, labnotes, description, referenceType, referenceID, storageLocation, timeCreated, timeOfEntry = nil, id = nil)
		@createdBy = createdBy
		@initials = initials
		@labNotes = labnotes
		@description = description
		@refType = referenceType
		@refID = referenceID
		@storageLocation = storageLocation
		@timeOfCreation = timeCreated
		@timeOfEntry = (timeOfEntry == nil) ? Time.now.to_i : timeOfEntry
		@id = id;
	end

	def setIdNum(id)
		@id = "g#{@initials}#{id.to_s}"
	end

	def sanityCheck
		# Assert that all required values are present
		if @createdBy == nil || @initials == nil
			raise CloneStoreObjectSanityError, 'Creator Name and Initials of generic object have to be set'
		end

		if @description == nil || @description == ''
			raise CloneStoreObjectSanityError, 'Generic Objects cannot have empty descriptions'
		end
		
		# Assert that time of creation is a somewhat sane unix timestamp and does not lie too far in the future
		if !@timeOfCreation.is_a? Integer || @timeOfCreation > Time.now.to_i + 24 * 60 * 60 || @timeOfCreation < 0
			raise CloneStoreObjectSanityError, 'Time of creation value is not a valid timestamp'
		end

		# Assert that time of entry is a somewhat sane unix timestamp and does not lie too far in the future
		if !@timeOfEntry.is_a? Integer || @timeOfEntry > Time.now.to_i + 24 * 60 * 60 || @timeOfEntry < 0
			raise CloneStoreObjectSanityError, 'Time of entry value is not a valid timestamp'
		end

		# Assert non-empty storage location
		if @storageLocation == nil || @storageLocation == ''
			raise CloneStoreObjectSanityError, 'Generic Objects cannot have empty storage location'
		end
	end

	def self.fromHash(h)
		GenericObject.new(h['createdBy'], h['initials'], h['labNotes'], h['description'], h['referenceType'], h['referenceID'], h['storageLocation'], h['timeOfCreation'], h['timeOfEntry'], h['id'])
	end

	def self.fromJSON(json)
		begin
			parsed = JSON.parse(json)
		rescue JSON::ParserError
			raise CloneStoreObjectSanityError, "Generic Object JSON data is corrupt"
		end
		
		GenericObject::fromHash(parsed)
	end

	def getLink(template)
		template.gsub("[typeid]", "g").gsub("[objectid]", @id)
	end

	def getLabelText(info)

		dateString = Time.at(@timeOfCreation).to_date.strftime('%Y/%m/%d')

		text = "#{@id}\n#{dateString} | #{@initials}"

		if @refID != nil && @refID != ''
			text += "\nrelated: #{@refID}"
		end

		return text
	end

	def to_json
		obj = {
			'id' => @id,
			'createdBy' => @createdBy,
			'initials' => @initials,
			'labNotes' => @labNotes,
			'description' => @description,
			'referenceType' => @refType,
			'referenceID' => @refID,
			'storageLocation' => @storageLocation,
			'timeOfCreation' => @timeOfCreation,
			'timeOfEntry' => @timeOfEntry
		}

		return JSON.generate(obj)
	end
end