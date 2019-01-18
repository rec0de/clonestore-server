require 'sqlite3'
require_relative 'plasmid.class'
require_relative 'printremote.class'

class Database
	@@createStatements = [
		"CREATE TABLE IF NOT EXISTS plasmids(id TEXT PRIMARY KEY, createdBy TEXT, initials TEXT, labNotes TEXT, description TEXT, backbonePlasmid TEXT, timeOfEntry INTEGER, timeOfCreation INTEGER, geneData BLOB, isArchived BOOLEAN);",
		"CREATE TABLE IF NOT EXISTS selectionMarkers(plasmidID INTEGER, marker TEXT, CONSTRAINT noDuplicates UNIQUE (plasmidID, marker));",
		"CREATE TABLE IF NOT EXISTS plasmidFeatures(plasmidID INTEGER, hasFeature TEXT, CONSTRAINT noDuplicates UNIQUE (plasmidID, hasFeature));",

		"CREATE TABLE IF NOT EXISTS storageLocations(location TEXT, plasmidID TEXT, host TEXT, CONSTRAINT locUnique UNIQUE (location));",

		"CREATE TABLE IF NOT EXISTS printers(url TEXT, name TEXT, location TEXT, secret TEXT);",

		"CREATE TABLE IF NOT EXISTS idCounter(key TEXT, value INTEGER);"
	]

	def initialize(file)
		@db = SQLite3::Database.open(file)
		@db.results_as_hash = true;

		@@createStatements.each{ |stmt|
			@db.execute(stmt);
		}
	end

	def insert(plasmid)
		if plasmid.is_a? Plasmid
			# Perform sanity check
			plasmid.sanityCheck

			# Calculate ID if not already set
			if plasmid.id == nil
				plasmid.setIdNum(getNewId())
			end

			# Insert main plasmid data
			stm = @db.prepare("INSERT INTO plasmids(id, createdBy, initials, labNotes, description, backbonePlasmid, timeOfEntry, timeOfCreation, geneData, isArchived) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, 0);")
			stm.bind_param(1, plasmid.id)
			stm.bind_param(2, plasmid.createdBy)
			stm.bind_param(3, plasmid.initials)
			stm.bind_param(4, nil) #plasmid.labNotes)
			stm.bind_param(5, plasmid.description)
			stm.bind_param(6, plasmid.backbonePlasmid)
			stm.bind_param(7, plasmid.timeOfEntry)
			stm.bind_param(8, plasmid.timeOfCreation)
			stm.bind_param(9, plasmid.geneData)

			begin
				stm.execute
			rescue SQLite3::ConstraintException
				raise CloneStoreDatabaseError, "Could not save plasmid - ID is not unique"
			end

			# Insert selection marker data
			plasmid.selectionMarkers.each { |marker|
				stm = @db.prepare("INSERT INTO selectionMarkers(plasmidID, marker) VALUES (?, ?);")
				stm.bind_param(1, plasmid.id)
				stm.bind_param(2, marker)
				stm.execute
			}

			# Insert feature data
			plasmid.features.each { |feature|
				stm = @db.prepare("INSERT INTO plasmidFeatures(plasmidID, hasFeature) VALUES (?, ?);")
				stm.bind_param(1, plasmid.id)
				stm.bind_param(2, feature)
				stm.execute
			}

			# Increment the global ID counter to get a fresh ID next time
			incrementIdCounter()

			return plasmid.id
		else
			raise CloneStoreDatabaseError, 'Can\'t insert something that is not a Plasmid object'
		end
	end

	def getPlasmid(id)
		stm = @db.prepare("SELECT * FROM plasmids WHERE id = ?;")
		stm.bind_param(1, id)
		rs = stm.execute.next # Get only the first returned value

		return nil if rs == nil

		puts rs.inspect

		plasmid = Plasmid.new(rs['createdBy'], rs['initials'], rs['description'], rs['backbonePlasmid'], rs['geneData'], rs['timeOfCreation'], rs['timeOfEntry'], rs['id'])

		puts plasmid.to_json

		# Fetch features from database
		getPlasmidFeatures(id).each{ |row|
			plasmid.addFeature(row['hasFeature'])
		}

		# Fetch selectionMarkers from database
		getSelectionMarkers(id).each{ |row|
			plasmid.addSelectionMarker(row['marker'])
		}

		return plasmid
	end

	def getPlasmidFeatures(id)
		stm = @db.prepare("SELECT hasFeature FROM plasmidFeatures WHERE plasmidID = ?;")
		stm.bind_param(1, id)
		stm.execute
	end

	def getSelectionMarkers(id)
		stm = @db.prepare("SELECT marker FROM selectionMarkers WHERE plasmidID = ?;")
		stm.bind_param(1, id)
		stm.execute
	end

	def setArchiveFlag(id, flag = 1)
		if flag == 1
			stm = @db.prepare("DELETE FROM storageLocations WHERE plasmidID = ?;")
			stm.bind_param(1, id)
			stm.execute
		end
		stm = @db.prepare("UPDATE plasmids SET isArchived = ? WHERE id = ?;")
		stm.bind_param(1, flag)
		stm.bind_param(2, id)
		stm.execute
	end

	# Printing

	def setupPrinter(url, name, location, secret)
		clr = @db.prepare("DELETE FROM printers;")
		clr.execute
		stm = @db.prepare("INSERT INTO printers(url, name, location, secret) VALUES (?, ?, ?, ?);")
		stm.bind_param(1, url)
		stm.bind_param(2, name)
		stm.bind_param(3, location)
		stm.bind_param(4, secret)
		stm.execute
	end

	def getPrintRemote
		stm = @db.prepare("SELECT url, secret FROM printers LIMIT 1;")
		data = stm.execute.next

		if data == nil
			raise CloneStoreDatabaseError, "No printer configured"
		end

		PrintRemote.new(data['url'], data['secret'])
	end

	# Storage management

	def setStorageSlot(location, id, host)
		stm = @db.prepare("INSERT INTO storageLocations(location, plasmidID, host) VALUES (?, ?, ?);")
		stm.bind_param(1, location)
		stm.bind_param(2, id)
		stm.bind_param(3, host)
		stm.execute
	end

	def freeStorageSlot(location)
		stm = @db.prepare("DELETE FROM storageLocations WHERE location = ?;")
		stm.bind_param(1, location)
		stm.execute
	end

	def getStorageSlot(location)
		stm = @db.prepare("SELECT plasmidID AS id, host FROM storageLocations WHERE location = ?;")
		stm.bind_param(1, location)
		rs = stm.execute.next

		return rs;
	end

	# ID generation

	def getNewId
		stm = @db.prepare("SELECT value FROM idCounter WHERE key = 'global'")
		rs = stm.execute.next

		return rs == nil ? 1 : rs['value']
	end

	def incrementIdCounter
		stm = @db.prepare("UPDATE idCounter SET value = value + 1 WHERE key = 'global'")
		stm.execute
	end

end

class CloneStoreDatabaseError < CloneStoreRuntimeError
end