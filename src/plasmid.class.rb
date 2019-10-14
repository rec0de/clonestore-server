require 'set'
require 'json'

class Plasmid attr_reader :id, :createdBy, :initials, :description, :labNotes, :backbonePlasmid, :timeOfEntry, :timeOfCreation, :geneData, :features, :selectionMarkers, :ORFs, :archived

	def initialize(createdBy, initials, desc, labnotes, backbone, geneData, timeCreated, timeOfEntry = nil, id = nil, archived = false)
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
		@id = id
		@archived = (archived && archived != 0) ? true : false # looks stupid but forces conversion of 1/0 flags to true boolean
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
			raise CloneStoreObjectSanityError, 'Creator Name and Initials of plasmid have to be set'
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
		Plasmid.new(h['createdBy'], h['initials'], h['description'], h['labNotes'], h['backbonePlasmid'], h['geneData'], h['timeOfCreation'], h['timeOfEntry'], h['id'], h['archived'])
	end

	def self.fromJSON(json)
		begin
			parsed = JSON.parse(json)
		rescue JSON::ParserError
			raise CloneStoreObjectSanityError, "Plasmid JSON data is corrupt"
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
			'ORFs' => @ORFs.to_a,
			'timeOfCreation' => @timeOfCreation,
			'timeOfEntry' => @timeOfEntry,
			'createdBy' => @createdBy,
			'initials' => @initials,
			'geneData' => @geneData,
			'archived' => @archived
		}

		return JSON.generate(obj)
	end

	def getLink(template)
		template.gsub("[typeid]", "p").gsub("[objectid]", @id)
	end

	def getLabelText(info)

		dateString = Time.at(@timeOfCreation).to_date.strftime('%Y/%m/%d')

		text = "#{@id}\n#{dateString} | #{@initials}"

		if(info != nil)
			text += "\n #{info}\n#{@selectionMarkers.to_a.join(', ')}"
		end

		return text
	end

end

class CloneStoreRuntimeError < RuntimeError
end

class CloneStoreObjectSanityError < CloneStoreRuntimeError
end