require 'set'
require 'json'

class Plasmid attr_reader :id, :createdBy, :initials, :description, :labNotes, :backbonePlasmid, :timeOfEntry, :timeOfCreation, :geneData, :features, :selectionMarkers, :ORFs

	def initialize(createdBy, initials, desc, labnotes, backbone, geneData, timeCreated, timeOfEntry = nil, id = nil)
		@features = Set.new
		@selectionMarkers = Set.new
		@ORFs = Set.new
		@createdBy = createdBy
		@initials = initials
		@description = desc
		@labNotes = labnotes
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

	def addORF(orf)
		@ORFs.add(orf)
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
		Plasmid.new(h['createdBy'], h['initials'], h['description'], h['labNotes'], h['backbonePlasmid'], h['geneData'], h['timeOfCreation'], h['timeOfEntry'], h['id'])
	end

	def self.fromJSON(json)
		begin
			parsed = JSON.parse(json)
		rescue JSON::ParserError
			raise CloneStorePlasmidSanityError, "Plasmid JSON data is corrupt"
		end
		
		res = Plasmid::fromHash(parsed)

		aFeature = res.method(:addFeature)
		aSelMark = res.method(:addSelectionMarker)
		aORF = res.method(:addORF)

		parsed['features'].each(&aFeature) if parsed['features'] != nil
		parsed['selectionMarkers'].each(&aSelMark) if parsed['selectionMarkers'] != nil
		parsed['ORFs'].each(&aORF) if parsed['ORFs'] != nil

		return res
	end

	def to_json
		obj = {
			'id' => @id,
			'description' => @description,
			'labNotes' => @labNotes,
			'backbonePlasmid' => @backbonePlasmid,
			'features' => @features.to_a,
			'selectionMarkers' => @selectionMarkers.to_a,
			'ORFs' => @orfs.to_a,
			'timeOfCreation' => @timeOfCreation,
			'timeOfEntry' => @timeOfEntry,
			'createdBy' => @createdBy,
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