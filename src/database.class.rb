require 'sqlite3'
require_relative 'plasmid.class'
require_relative 'microorganism.class'
require_relative 'printremote.class'

class Database
	@@createStatements = [
		"PRAGMA foreign_keys = ON;",

		"CREATE TABLE IF NOT EXISTS plasmids(id TEXT PRIMARY KEY, createdBy TEXT, initials TEXT, labNotes TEXT, description TEXT, backbonePlasmid TEXT, timeOfEntry INTEGER, timeOfCreation INTEGER, geneData BLOB, isArchived BOOLEAN);",
		"CREATE TABLE IF NOT EXISTS selectionMarkers(plasmidID INTEGER, marker TEXT, CONSTRAINT noDuplicates UNIQUE (plasmidID, marker), FOREIGN KEY(plasmidID) REFERENCES plasmids(id));",
		"CREATE TABLE IF NOT EXISTS plasmidFeatures(plasmidID INTEGER, hasFeature TEXT, CONSTRAINT noDuplicates UNIQUE (plasmidID, hasFeature), FOREIGN KEY(plasmidID) REFERENCES plasmids(id));",
		"CREATE TABLE IF NOT EXISTS plasmidORFs(plasmidID, hasORF TEXT, CONSTRAINT noDuplicates UNIQUE (plasmidID, hasORF), FOREIGN KEY(plasmidID) REFERENCES plasmids(id));",

		"CREATE TABLE IF NOT EXISTS microorganisms(id TEXT PRIMARY KEY, createdBy TEXT, initials TEXT, labNotes TEXT, organism TEXT, resistance TEXT, plasmid TEXT, timeOfEntry INTEGER, timeOfCreation INTEGER, destroyed BOOLEAN, FOREIGN KEY (plasmid) REFERENCES plasmids(id));",

		"CREATE TABLE IF NOT EXISTS storageLocations(location TEXT, plasmidID TEXT, host TEXT, CONSTRAINT locUnique UNIQUE (location), FOREIGN KEY(plasmidID) REFERENCES plasmids(id));",

		"CREATE VIRTUAL TABLE  IF NOT EXISTS search USING FTS5(id, createdBy, initials, labNotes, description, backbonePlasmid, misc);",

		"CREATE TABLE IF NOT EXISTS idCounter(key TEXT, value INTEGER);",
		"CREATE TABLE IF NOT EXISTS printers(url TEXT, name TEXT, location TEXT, secret TEXT);"
	]

	def initialize(file)
		@db = SQLite3::Database.open(file)
		@db.results_as_hash = true;

		@@createStatements.each{ |stmt|
			@db.execute(stmt);
		}
	end

	# Plasmids

	def insertPlasmid(plasmid)
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
			stm.bind_param(4, plasmid.labNotes)
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

			# Insert ORF data
			plasmid.ORFs.each { |orf|
				stm = @db.prepare("INSERT INTO plasmidORFs(plasmidID, hasORF) VALUES (?, ?);")
				stm.bind_param(1, plasmid.id)
				stm.bind_param(2, orf)
				stm.execute
			}

			# Increment the global ID counter to get a fresh ID next time
			incrementIdCounter()

			# Update search index
			misc = plasmid.selectionMarkers.to_a.concat(plasmid.features.to_a).concat(plasmid.ORFs.to_a).join(' ')
			stm = @db.prepare("INSERT INTO search(id, createdBy, initials, labNotes, description, backbonePlasmid, misc) VALUES(?, ?, ?, ?, ?, ?, ?);")
			stm.bind_param(1, plasmid.id)
			stm.bind_param(2, plasmid.createdBy)
			stm.bind_param(3, plasmid.initials)
			stm.bind_param(4, plasmid.labNotes)
			stm.bind_param(5, plasmid.description)
			stm.bind_param(6, plasmid.backbonePlasmid)
			stm.bind_param(7, misc)
			stm.execute

			return plasmid.id
		else
			raise CloneStoreDatabaseError, 'Trying to insert a non-plasmid as a plasmid'
		end
	end

	def getPlasmid(id)
		stm = @db.prepare("SELECT * FROM plasmids WHERE id = ?;")
		stm.bind_param(1, id)
		rs = stm.execute.next # Get only the first returned value

		return nil if rs == nil

		plasmid = Plasmid::fromHash(rs)

		# Fetch features from database
		getPlasmidFeatures(id).each{ |row|
			plasmid.addFeature(row['hasFeature'])
		}

		# Fetch selectionMarkers from database
		getSelectionMarkers(id).each{ |row|
			plasmid.addSelectionMarker(row['marker'])
		}

		# Fetch ORFs from database
		getPlasmidORFs(id).each{ |row|
			plasmid.addORF(row['hasORF'])
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

	def getPlasmidORFs(id)
		stm = @db.prepare("SELECT hasORF FROM plasmidORFs WHERE plasmidID = ?;")
		stm.bind_param(1, id)
		stm.execute
	end

	def archivePlasmid(id, flag = 1)
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

	# Microorganisms

	def insertMicroorganism(microorganism)
		if microorganism.is_a? Microorganism
			# Perform sanity check
			microorganism.sanityCheck

			# Calculate ID if not already set
			if microorganism.id == nil
				microorganism.setIdNum(getNewId())
			end

			# Insert main plasmid data
			stm = @db.prepare("INSERT INTO microorganisms(id, createdBy, initials, labNotes, organism, resistance, plasmid, timeOfEntry, timeOfCreation, destroyed) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, 0);")
			stm.bind_param(1, microorganism.id)
			stm.bind_param(2, microorganism.createdBy)
			stm.bind_param(3, microorganism.initials)
			stm.bind_param(4, microorganism.labNotes)
			stm.bind_param(5, microorganism.organism)
			stm.bind_param(6, microorganism.resistance)
			stm.bind_param(7, microorganism.plasmid == '' ? nil : microorganism.plasmid)
			stm.bind_param(8, microorganism.timeOfEntry)
			stm.bind_param(9, microorganism.timeOfCreation)

			begin
				stm.execute
			rescue SQLite3::ConstraintException
				raise CloneStoreDatabaseError, "Could not save microorganism - ID is not unique or referenced plasmid does not exist"
			end

			# Increment the global ID counter to get a fresh ID next time
			incrementIdCounter()

			return microorganism.id
		else
			raise CloneStoreDatabaseError, 'Trying to insert a non-microorganism as a microorganism'
		end
	end

	def getMicroorganism(id)
		stm = @db.prepare("SELECT * FROM microorganisms WHERE id = ?;")
		stm.bind_param(1, id)
		rs = stm.execute.next # Get only the first returned value

		return nil if rs == nil

		Microorganism::fromHash(rs)
	end

	def archiveMicroorganism(id, flag = 1)
		stm = @db.prepare("UPDATE microorganisms SET destroyed = ? WHERE id = ?;")
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

	def getPrintRemote(frontendURL)
		stm = @db.prepare("SELECT url, secret FROM printers LIMIT 1;")
		data = stm.execute.next

		if data == nil
			raise CloneStoreDatabaseError, "No printer configured"
		end

		PrintRemote.new(data['url'], data['secret'], frontendURL)
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

	def getStorageLocations(plasmidID)
		stm = @db.prepare("SELECT location, host FROM storageLocations WHERE plasmidID = ?;")
		stm.bind_param(1, plasmidID)
		stm.execute
	end

	# Search

	def search(mode, term)
		case mode
			when :id
				stm = @db.prepare("SELECT id, createdBy, description FROM search WHERE id MATCH ? ORDER BY rank;")
			when :createdBy
				stm = @db.prepare("SELECT id, createdBy, description FROM search WHERE createdBy MATCH ? ORDER BY rank;")
			when :description
				stm = @db.prepare("SELECT id, createdBy, description FROM search WHERE description MATCH ? ORDER BY rank;")
			when :backbonePlasmid
				stm = @db.prepare("SELECT id, createdBy, description FROM search WHERE backbonePlasmid MATCH ? ORDER BY rank;")
			when :any
				stm = @db.prepare("SELECT id, createdBy, description FROM search WHERE search MATCH ? ORDER BY rank;")
			else
				raise CloneStoreDatabaseError, "Incorrect mode supplied to search function"
		end

		stm.bind_param(1, term)
		stm.execute
	end

	# ID generation

	def getNewId
		stm = @db.prepare("SELECT value FROM idCounter WHERE key = 'global';")
		rs = stm.execute.next

		# Insert first value if counter is not initialized
		if rs == nil
			stm = @db.prepare("INSERT INTO idCounter(key, value) VALUES ('global', 1);")
			stm.execute
			return 1
		else
			return rs['value']
		end
	end

	def incrementIdCounter
		stm = @db.prepare("UPDATE idCounter SET value = value + 1 WHERE key = 'global';")
		stm.execute
	end

end

class CloneStoreDatabaseError < CloneStoreRuntimeError
end