require 'set'
require 'json'

class Plasmid attr_reader :id, :createdBy, :initials, :description, :backbonePlasmid, :timeOfEntry, :timeOfCreation, :geneData, :features, :selectionMarkers

	def initialize(createdBy, initials, desc, backbone, geneData, timeCreated, timeOfEntry = nil, id = nil)
		@features = Set.new
		@selectionMarkers = Set.new
		@createdBy = createdBy
		@initials = initials
		@description = desc
		@backbonePlasmid = backbone
		@timeOfCreation = timeCreated
		@timeOfEntry = (timeOfEntry == nil) ? Time.now.to_i : timeOfEntry
		@geneData = geneData
		@id = id;
	end

	def addFeature(feature)
		@features.add(feature)
	end

	def addSelectionMarker(marker)
		@selectionMarkers.add(marker)
	end

	def setIdNum(id)
		@id = "p#{@initials}#{id.to_s}"
	end

	def sanityCheck
		# Assert that all required values are present
		if @createdBy == nil || @initials == nil
			raise CloneStorePlasmidSanityError, 'Creator Name and Initials of plasmid have to be set'
		end
		
		# Assert that time of creation is a somewhat sane unix timestamp and does not lie too far in the future
		if !@timeOfCreation.is_a? Integer || @timeOfCreation > Time.now.to_i + 24 * 60 * 60 || @timeOfCreation < 0
			raise CloneStorePlasmidSanityError, 'Time of creation value is not a valid timestamp'
		end

		# Assert that time of entry is a somewhat sane unix timestamp and does not lie too far in the future
		if !@timeOfEntry.is_a? Integer || @timeOfEntry > Time.now.to_i + 24 * 60 * 60 || @timeOfEntry < 0
			raise CloneStorePlasmidSanityError, 'Time of entry value is not a valid timestamp'
		end
	end

	def self.fromHash(h)
		Plasmid.new(h['createdBy'], h['initials'], h['description'], h['backbonePlasmid'], h['geneData'], h['timeOfCreation'], h['timeOfEntry'], h['id'])
	end

	def self.fromJSON(json)
		begin
			parsed = JSON.parse(json)
		rescue JSON::ParserError
			raise CloneStorePlasmidSanityError, "Plasmid JSON data is corrupt"
		end
		
		res = Plasmid::fromHash(parsed)

		parsed['features'].each{ |feature|
			res.addFeature(feature)
		}
		parsed['selectionMarkers'].each{ |marker|
			res.addSelectionMarker(marker)
		}

		return res
	end

	def to_json
		obj = {
			'id' => @id,
			'description' => @description,
			'backbonePlasmid' => @backbonePlasmid,
			'features' => @features.to_a,
			'selectionMarkers' => @selectionMarkers.to_a,
			'timeOfCreation' => @timeOfCreation,
			'timeOfEntry' => @timeOfEntry,
			'createdBy' => @name,
			'initials' => @initials,
			'geneData' => @geneData
		}

		return JSON.generate(obj)
	end

end

class CloneStoreRuntimeError < RuntimeError
end

class CloneStorePlasmidSanityError < CloneStoreRuntimeError
end