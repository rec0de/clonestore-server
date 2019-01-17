require 'set'
require 'json'

class Plasmid attr_reader :id, :name, :initials, :description, :timeOfEntry, :timeOfCreation, :geneData, :features, :selectionMarkers

	def initialize(name, initials, desc, geneData, timeCreated, timeOfEntry = Time.now.to_i)
		@features = Set.new
		@selectionMarkers = Set.new
		@name = name
		@initials = initials
		@description = desc
		@timeOfCreation = timeCreated
		@timeOfEntry = timeOfEntry
		@geneData = geneData
		@id = nil;
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
		if @name == nil || @initials == nil
			raise CloneStorePlasmidSanityError, 'Name and Initials of plasmid have to be set'
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

	def self.fromJSON(json)
		begin
			parsed = JSON.parse(json)
		rescue JSON::ParserError
			raise CloneStorePlasmidSanityError, "Plasmid JSON data is corrupt"
		end
		
		res = Plasmid.new(parsed['name'], parsed['initials'], parsed['description'], parsed['geneData'], parsed['timeOfCreation'], parsed['timeOfEntry'])

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
			'name' => @name,
			'initials' => @initials,
			'description' => @description,
			'timeOfCreation' => @timeOfCreation,
			'timeOfEntry' => @timeOfEntry,
			'features' => @features.to_a,
			'selectionMarkers' => @selectionMarkers.to_a,
			'geneData' => @geneData
		}

		return JSON.generate(obj)
	end

end

class CloneStoreRuntimeError < RuntimeError
end

class CloneStorePlasmidSanityError < CloneStoreRuntimeError
end