require 'sqlite3'
require_relative 'plasmid.class'
require_relative 'microorganism.class'
require_relative 'genericobject.class'
require_relative 'printremote.class'

class Database
	@@createStatements = [
		"PRAGMA foreign_keys = ON;",

		"CREATE TABLE IF NOT EXISTS plasmids(id TEXT PRIMARY KEY, createdBy TEXT, initials TEXT, labNotes TEXT, description TEXT, backbonePlasmid TEXT, timeOfEntry INTEGER, timeOfCreation INTEGER, geneData BLOB, isArchived BOOLEAN);",
		"CREATE TABLE IF NOT EXISTS selectionMarkers(plasmidID INTEGER, marker TEXT, CONSTRAINT noDuplicates UNIQUE (plasmidID, marker), FOREIGN KEY(plasmidID) REFERENCES plasmids(id));",
		"CREATE TABLE IF NOT EXISTS plasmidFeatures(plasmidID INTEGER, hasFeature TEXT, CONSTRAINT noDuplicates UNIQUE (plasmidID, hasFeature), FOREIGN KEY(plasmidID) REFERENCES plasmids(id));",
		"CREATE TABLE IF NOT EXISTS plasmidORFs(plasmidID, hasORF TEXT, CONSTRAINT noDuplicates UNIQUE (plasmidID, hasORF), FOREIGN KEY(plasmidID) REFERENCES plasmids(id));",

		"CREATE TABLE IF NOT EXISTS microorganisms(id TEXT PRIMARY KEY, createdBy TEXT, initials TEXT, labNotes TEXT, organism TEXT, resistance TEXT, storageLocation TEXT, plasmid TEXT, timeOfEntry INTEGER, timeOfCreation INTEGER, destroyed BOOLEAN, FOREIGN KEY (plasmid) REFERENCES plasmids(id), CONSTRAINT noDuplicateLocation UNIQUE (storageLocation));",

		"CREATE TABLE IF NOT EXISTS genericobjects(id TEXT PRIMARY KEY, createdBy TEXT, initials TEXT, labNotes TEXT, description TEXT, storageLocation TEXT, timeOfEntry INTEGER, timeOfCreation INTEGER, destroyed BOOLEAN, plasmidRef TEXT, organismRef TEXT, genericRef TEXT, FOREIGN KEY (plasmidRef) REFERENCES plasmids(id), FOREIGN KEY (organismRef) REFERENCES microorganisms(id), FOREIGN KEY (genericRef) REFERENCES genericobjects(id), CONSTRAINT noDuplicateLocation UNIQUE (storageLocation));",

		"CREATE TABLE IF NOT EXISTS storageLocations(location TEXT, plasmidID TEXT, host TEXT, CONSTRAINT locUnique UNIQUE (location), FOREIGN KEY(plasmidID) REFERENCES plasmids(id));",

		"CREATE VIRTUAL TABLE  IF NOT EXISTS search USING FTS5(id, type, createdBy, initials, labNotes, description, misc);",

		"CREATE TABLE IF NOT EXISTS idCounter(key TEXT, value INTEGER);",
		"CREATE TABLE IF NOT EXISTS printers(url TEXT, name TEXT, location TEXT, secret TEXT);",
		"CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY, startTime INTEGER)"
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

			begin
				@db.transaction

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

			
				stm.execute

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
				misc = plasmid.selectionMarkers.to_a.concat(plasmid.features.to_a).concat(plasmid.ORFs.to_a).join(' ') + ' ' + plasmid.backbonePlasmid.to_s
				stm = @db.prepare("INSERT INTO search(id, type, createdBy, initials, labNotes, description, misc) VALUES(?, 'plasmid', ?, ?, ?, ?, ?);")
				stm.bind_param(1, plasmid.id)
				stm.bind_param(2, plasmid.createdBy)
				stm.bind_param(3, plasmid.initials)
				stm.bind_param(4, plasmid.labNotes)
				stm.bind_param(5, plasmid.description)
				stm.bind_param(6, misc)
				stm.execute

				@db.commit

			rescue SQLite3::ConstraintException => e
				@db.rollback
				if e.to_s == "UNIQUE constraint failed: plasmids.id"
					msg = "ID is not unique"
				else
					msg = "Unknown database constraint error: '#{e.to_s}'"
				end
					
				raise CloneStoreDatabaseError, "Could not save plasmid - #{msg}"
			rescue RuntimeError => e
				@db.rollback
				raise CloneStoreDatabaseError, "Unknown exception trying to insert plasmid: '#{e.to_s}'"
			end

			return plasmid.id
		else
			raise CloneStoreDatabaseError, 'Trying to insert a non-plasmid as a plasmid'
		end
	end

	def getPlasmid(id)
		stm = @db.prepare("SELECT *, (isArchived = 1) AS archived FROM plasmids WHERE id = ?;")
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

			begin
				@db.transaction

				# Insert main plasmid data
				stm = @db.prepare("INSERT INTO microorganisms(id, createdBy, initials, labNotes, organism, resistance, plasmid, storageLocation, timeOfEntry, timeOfCreation, destroyed) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);")
				stm.bind_param(1, microorganism.id)
				stm.bind_param(2, microorganism.createdBy)
				stm.bind_param(3, microorganism.initials)
				stm.bind_param(4, microorganism.labNotes)
				stm.bind_param(5, microorganism.organism)
				stm.bind_param(6, microorganism.resistance)
				stm.bind_param(7, microorganism.plasmid == '' ? nil : microorganism.plasmid)
				stm.bind_param(8, microorganism.storageLocation)
				stm.bind_param(9, microorganism.timeOfEntry)
				stm.bind_param(10, microorganism.timeOfCreation)
				stm.execute

				# Increment the global ID counter to get a fresh ID next time
				incrementIdCounter()

				# Update search index
				misc = microorganism.storageLocation + ' ' + microorganism.resistance.to_s
				description = microorganism.organism.to_s + ' ' + microorganism.plasmid.to_s
				stm = @db.prepare("INSERT INTO search(id, type, createdBy, initials, labNotes, description, misc) VALUES(?, 'microorganism', ?, ?, ?, ?, ?);")
				stm.bind_param(1, microorganism.id)
				stm.bind_param(2, microorganism.createdBy)
				stm.bind_param(3, microorganism.initials)
				stm.bind_param(4, microorganism.labNotes)
				stm.bind_param(5, description)
				stm.bind_param(6, misc)
				stm.execute

				@db.commit

			rescue SQLite3::ConstraintException => e
				@db.rollback
				if e.to_s == "FOREIGN KEY constraint failed"
					msg = "Referenced plasmid does not exist"
				elsif e.to_s == "UNIQUE constraint failed: microorganisms.storageLocation"
					msg = "Storage location is already occupied"
				else
					msg = "Unknown database constraint error: '#{e.to_s}'"
				end
					
				raise CloneStoreDatabaseError, "Could not save microorganism - #{msg}"
			rescue RuntimeError => e
				@db.rollback
				raise CloneStoreDatabaseError, "Unknown exception trying to insert microorganism: '#{e.to_s}'"
			end

			return microorganism.id
		else
			raise CloneStoreDatabaseError, 'Trying to insert a non-microorganism as a microorganism'
		end
	end

	def getMicroorganism(id)
		stm = @db.prepare("SELECT *, (destroyed = 1) AS archived FROM microorganisms WHERE id = ?;")
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

	def updateMicroorganismStorageLocation(id, newLocation)
		begin
			stm = @db.prepare("UPDATE microorganisms SET storageLocation = ? WHERE id = ?;")
			stm.bind_param(1, newLocation)
			stm.bind_param(2, id)
			stm.execute
		rescue SQLite3::ConstraintException => e
			if e.to_s == "UNIQUE constraint failed: microorganisms.storageLocation"
				msg = "Storage location is already occupied"
			else
				msg = "Unknown database constraint error: '#{e.to_s}'"
			end
					
			raise CloneStoreDatabaseError, "Could not update microorganism location - #{msg}"
		rescue RuntimeError => e
			raise CloneStoreDatabaseError, "Unknown exception trying to update microorganism location: '#{e.to_s}'"
		end
	end

	# Generic Objects

	def insertGeneric(generic)
		if generic.is_a? GenericObject
			# Perform sanity check
			generic.sanityCheck

			# Calculate ID if not already set
			if generic.id == nil
				generic.setIdNum(getNewId())
			end

			begin
				@db.transaction

				# Insert main plasmid data
				stm = @db.prepare("INSERT INTO genericobjects(id, createdBy, initials, labNotes, description, storageLocation, timeOfEntry, timeOfCreation, destroyed, plasmidRef, organismRef, genericRef) VALUES(?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?);")
				stm.bind_param(1, generic.id)
				stm.bind_param(2, generic.createdBy)
				stm.bind_param(3, generic.initials)
				stm.bind_param(4, generic.labNotes)
				stm.bind_param(5, generic.description)
				stm.bind_param(6, generic.storageLocation)
				stm.bind_param(7, generic.timeOfEntry)
				stm.bind_param(8, generic.timeOfCreation)

				pRef = nil
				mRef = nil
				gRef = nil

				if generic.refType == 'plasmid'
					pRef = generic.refID
				elsif generic.refType == 'microorganism'
					mRef = generic.refID
				else
					gRef = generic.refID
				end
				
				stm.bind_param(9, pRef)
				stm.bind_param(10, mRef)
				stm.bind_param(11, gRef)
				stm.execute

				# Increment the global ID counter to get a fresh ID next time
				incrementIdCounter()

				# Update search index
				misc = generic.storageLocation + ' ' + generic.refID.to_s
				stm = @db.prepare("INSERT INTO search(id, type, createdBy, initials, labNotes, description, misc) VALUES(?, 'genericobject', ?, ?, ?, ?, ?);")
				stm.bind_param(1, generic.id)
				stm.bind_param(2, generic.createdBy)
				stm.bind_param(3, generic.initials)
				stm.bind_param(4, generic.labNotes)
				stm.bind_param(5, generic.description)
				stm.bind_param(6, misc)
				stm.execute
				@db.commit

			rescue SQLite3::ConstraintException => e
				@db.rollback
				if e.to_s == "FOREIGN KEY constraint failed"
					msg = "Referenced object does not exist"
				elsif e.to_s == "UNIQUE constraint failed: genericobjects.storageLocation"
					msg = "Storage location is already occupied"
				else
					msg = "Unknown database constraint error: '#{e.to_s}'"
				end
					
				raise CloneStoreDatabaseError, "Could not save generic object - #{msg}"
			rescue RuntimeError => e
				@db.rollback
				raise CloneStoreDatabaseError, "Unknown exception trying to insert generic object: '#{e.to_s}'"
			end

			return generic.id
		else
			raise CloneStoreDatabaseError, 'Trying to insert a non-genericobject as a generic object'
		end
	end

	def getGeneric(id)
		stm = @db.prepare("SELECT *, (destroyed = 1) AS archived FROM genericobjects WHERE id = ?;")
		stm.bind_param(1, id)
		rs = stm.execute.next # Get only the first returned value

		return nil if rs == nil

		if rs['plasmidRef'] != nil
			rs['referenceType'] = 'plasmid'
			rs['referenceID'] = rs['plasmidRef']
		elsif rs['organismRef'] != nil
			rs['referenceType'] = 'microorganism'
			rs['referenceID'] = rs['organismRef']
		else
			rs['referenceType'] = 'generic'
			rs['referenceID'] = rs['genericRef']
		end

		GenericObject::fromHash(rs)
	end

	def archiveGeneric(id, flag = 1)
		stm = @db.prepare("UPDATE genericobjects SET destroyed = ?, storageLocation = NULL WHERE id = ?;")
		stm.bind_param(1, flag)
		stm.bind_param(2, id)
		stm.execute
	end

	def updateGenericStorageLocation(id, newLocation)
		begin
			stm = @db.prepare("UPDATE genericobjects SET storageLocation = ? WHERE id = ?;")
			stm.bind_param(1, newLocation)
			stm.bind_param(2, id)
			stm.execute
		rescue SQLite3::ConstraintException => e
			if e.to_s == "UNIQUE constraint failed: genericobjects.storageLocation"
				msg = "Storage location is already occupied"
			else
				msg = "Unknown database constraint error: '#{e.to_s}'"
			end
					
			raise CloneStoreDatabaseError, "Could not update generic object location - #{msg}"
		rescue RuntimeError => e
			raise CloneStoreDatabaseError, "Unknown exception trying to update generic object location: '#{e.to_s}'"
		end
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
				stm = @db.prepare("SELECT id, type, createdBy, description FROM search WHERE id MATCH ? ORDER BY rank;")
			when :createdBy
				stm = @db.prepare("SELECT id, type, createdBy, description FROM search WHERE createdBy MATCH ? ORDER BY rank;")
			when :description
				stm = @db.prepare("SELECT id, type, createdBy, description FROM search WHERE description MATCH ? ORDER BY rank;")
			when :any
				stm = @db.prepare("SELECT id, type, createdBy, description FROM search WHERE search MATCH ? ORDER BY rank;")
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

	# Session management

	def registerSessionToken(token)
		stm = @db.prepare("INSERT INTO sessions(token, startTime) VALUES (?, ?);")
		stm.bind_param(1, token)
		stm.bind_param(2, Time.now.to_i)
		stm.execute
	end

	def getSessionByToken(token)
		stm = @db.prepare("SELECT startTime FROM sessions WHERE token = ?;")
		stm.bind_param(1, token)
		stm.execute
	end

	def revokeSessionToken(token)
		stm = @db.prepare("DELETE FROM sessions WHERE token = ?;")
		stm.bind_param(1, token)
		stm.execute
	end

end

class CloneStoreDatabaseError < CloneStoreRuntimeError
end