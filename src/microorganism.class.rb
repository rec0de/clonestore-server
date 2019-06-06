require 'json'

class Microorganism attr_reader :id, :createdBy, :initials, :labNotes, :organism, :plasmid, :resistance, :storageLocation, :timeOfEntry, :timeOfCreation

	def initialize(createdBy, initials, labnotes, organism, plasmid, resistance, storageLocation, timeCreated, timeOfEntry = nil, id = nil)
		@createdBy = createdBy
		@initials = initials
		@labNotes = labnotes
		@organism = organism
		@plasmid = plasmid
		@resistance = resistance
		@storageLocation = storageLocation
		@timeOfCreation = timeCreated
		@timeOfEntry = (timeOfEntry == nil) ? Time.now.to_i : timeOfEntry
		@id = id;
	end

	def setIdNum(id)
		@id = "m#{@initials}#{id.to_s}"
	end

	def sanityCheck
		# Assert that all required values are present
		if @createdBy == nil || @initials == nil
			raise CloneStoreObjectSanityError, 'Creator Name and Initials of microorganism have to be set'
		end
		
		# Assert that time of creation is a somewhat sane unix timestamp and does not lie too far in the future
		if (!@timeOfCreation.is_a? Integer) || (@timeOfCreation > Time.now.to_i + 24 * 60 * 60) || (@timeOfCreation < 0)
			raise CloneStoreObjectSanityError, 'Time of creation value is not a valid timestamp'
		end

		# Assert that time of entry is a somewhat sane unix timestamp and does not lie too far in the future
		if (!@timeOfEntry.is_a? Integer) || (@timeOfEntry > Time.now.to_i + 24 * 60 * 60) || (@timeOfEntry < 0)
			raise CloneStoreObjectSanityError, 'Time of entry value is not a valid timestamp'
		end
	end

	def self.fromHash(h)
		Microorganism.new(h['createdBy'], h['initials'], h['labNotes'], h['organism'], h['plasmid'], h['resistance'], h['storageLocation'], h['timeOfCreation'], h['timeOfEntry'], h['id'])
	end

	def self.fromJSON(json)
		begin
			parsed = JSON.parse(json)
		rescue JSON::ParserError
			raise CloneStoreObjectSanityError, "Microorganism JSON data is corrupt"
		end
		
		Microorganism::fromHash(parsed)
	end

	def getLink(template)
		template.gsub("[typeid]", "m").gsub("[objectid]", @id)
	end

	def getLabelText(info)

		dateString = Time.at(@timeOfCreation).to_date.strftime('%Y/%m/%d')

		text = "#{@organism}\n#{@plasmid}\n#{@id}\n#{dateString} | #{@initials}"

		return text
	end

	def to_json
		obj = {
			'id' => @id,
			'createdBy' => @createdBy,
			'initials' => @initials,
			'labNotes' => @labNotes,
			'organism' => @organism,
			'plasmid' => @plasmid,
			'resistance' => @resistance,
			'storageLocation' => @storageLocation,
			'timeOfCreation' => @timeOfCreation,
			'timeOfEntry' => @timeOfEntry
		}

		return JSON.generate(obj)
	end
end