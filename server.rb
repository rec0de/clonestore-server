#!/usr/bin/env ruby
require 'json'
require 'sinatra'
require_relative 'src/database.class'
require_relative 'src/auth.class'
require_relative 'src/printremote.class'

version = '0.1.0'

$frontendURL = "http://cs.rec0de.net/?[typeid]-[objectid]"
$databaseFile = "test.sqlite"

db = Database.new($databaseFile)
Authenticator::linkDatabase(db)
printRemote = nil

# Listen globally
set :bind, '0.0.0.0'

# Default headers and settings
def defaults
	headers( "Access-Control-Allow-Origin" => "*" )
end

# Error message JSON helper
def errmsg(msg)
	"{\"type\":\"error\", \"details\":\"#{msg}\"}"
end

# Success message JSON
def success(msg)
	"{\"type\":\"success\", \"details\":\"#{msg}\"}"
end

# Object ID message
def objectIdMsg(id)
	"{\"type\":\"objectID\", \"id\":\"#{id}\"}"
end

# Storage location message (plasmidID and bacterial host)
def storageContentMsg(id, host)
	"{\"type\":\"storageLocationContent\", \"id\":\"#{id}\", \"host\": \"#{host}\"}"
end

# Return error message for unauthenticated users
def checkauth

end

# Handle CORS preflight requests
options '*' do
	defaults()
	headers( "Access-Control-Allow-Methods" => "HEAD, GET, PUT, DELETE, OPTIONS" )
end

# Get server info
get '/' do
	defaults()
	"{\"type\": \"clonestore-server\", \"version\": \"#{version}\"}"
end

# Get plasmid
get '/plasmid/:id' do
	defaults()
	begin
		plasmid = db.getPlasmid(params[:id])
		if plasmid == nil
			status 404
			errmsg("Plasmid does not exist")
		else
			"{\"type\": \"plasmid\", \"plasmid\": #{plasmid.to_json}}"
		end
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Add plasmid
post '/plasmid' do
	defaults()
	begin
		plasmid = Plasmid::fromJSON(params['data'])
		id = db.insertPlasmid(plasmid)
		status 200
		objectIdMsg(id)
	rescue CloneStoreRuntimeError => e
		status 400
		errmsg(e.message)
	end
end

# Archive plasmid
delete '/plasmid/:id' do
	defaults()
	begin
		raise CloneStoreRuntimeError, "Plasmid does not exist" if db.getPlasmid(params[:id]) === nil
		db.archivePlasmid(params[:id])
		success("Plasmid archived successfully")
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Get microorganism
get '/organism/:id' do
	defaults()
	begin
		microorganism = db.getMicroorganism(params[:id])
		if microorganism == nil
			status 404
			errmsg("Microorganism does not exist")
		else
			"{\"type\": \"microorganism\", \"microorganism\": #{microorganism.to_json}}"
		end
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Add microorganism
post '/organism' do
	defaults()
	begin
		microorganism = Microorganism::fromJSON(params['data'])
		id = db.insertMicroorganism(microorganism)
		status 200
		objectIdMsg(id)
	rescue CloneStoreRuntimeError => e
		status 400
		errmsg(e.message)
	end
end

# Archive microorganism
delete '/organism/:id' do
	defaults()
	begin
		raise CloneStoreRuntimeError, "Microorganism does not exist" if db.getMicroorganism(params[:id]) === nil
		db.archiveMicroorganism(params[:id])
		success("Microorganism archived successfully")
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Update microorganism location
put '/organism/:id/storageLocation' do
	defaults()
	begin
		raise CloneStoreRuntimeError, "Microorganism does not exist" if db.getMicroorganism(params[:id]) === nil
		raise CloneStoreRuntimeError, "New storage location not set" if params['newLocation'] === nil || params['newLocation'] === ''
		db.updateMicroorganismStorageLocation(params[:id], params['newLocation'])
		success("Microorganism location changed successfully")
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Get genericobject
get '/generic/:id' do
	defaults()
	begin
		genericobject = db.getGeneric(params[:id])
		if genericobject == nil
			status 404
			errmsg("Generic Object does not exist")
		else
			"{\"type\": \"genericobject\", \"genericobject\": #{genericobject.to_json}}"
		end
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Add genericobject
post '/generic' do
	defaults()
	begin
		genericobject = GenericObject::fromJSON(params['data'])
		id = db.insertGeneric(genericobject)
		status 200
		objectIdMsg(id)
	rescue CloneStoreRuntimeError => e
		status 400
		errmsg(e.message)
	end
end

# Archive genericobject
delete '/generic/:id' do
	defaults()
	begin
		raise CloneStoreRuntimeError, "Generic Object does not exist" if db.getGeneric(params[:id]) === nil
		db.archiveGeneric(params[:id])
		success("Generic Object archived successfully")
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Update genericobject location
put '/generic/:id/storageLocation' do
	defaults()
	begin
		raise CloneStoreRuntimeError, "Generic Object does not exist" if db.getGeneric(params[:id]) === nil
		raise CloneStoreRuntimeError, "New storage location not set" if params['newLocation'] === nil || params['newLocation'] === ''
		db.updateGenericStorageLocation(params[:id], params['newLocation'])
		success("Generic Object location changed successfully")
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Printer status
get '/print' do
	defaults()
	begin
		# Initialize remote if necessary
		printRemote = db.getPrintRemote($frontendURL) if printRemote == nil
		"{\"type\": \"printerStatus\", \"online\": #{printRemote.status}}"	
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Printer setup
put '/print' do
	defaults()
	begin
		if params['url'] == nil || params['authKey'] == nil || params['authKey'] == '' || params['url'] == ''
			raise CloneStoreRuntimeError, "Printer URL or secret missing"
		end
		db.setupPrinter(params['url'], params['name'], params['location'], params['authKey'])
		# Re-Initialize remote
		printRemote = db.getPrintRemote($frontendURL)
		success('Printer setup successfully')
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Print plasmid label
post '/print/p/:id' do
	defaults()
	begin
		plasmid = db.getPlasmid(params[:id])
		if plasmid == nil
			status 404
			errmsg("No plasmid with given ID")
		else
			# Initialize remote if necessary
			printRemote = db.getPrintRemote($frontendURL) if printRemote == nil
			copies = params['copies'] ? params['copies'].to_i : 1
			printRemote.print(plasmid, copies, params['host'])
			success("Printing completed")
		end
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Print microorganism label
post '/print/m/:id' do
	defaults()
	begin
		microorganism = db.getMicroorganism(params[:id])
		if microorganism == nil
			status 404
			errmsg("No microorganism with given ID")
		else
			# Initialize remote if necessary
			printRemote = db.getPrintRemote($frontendURL) if printRemote == nil
			copies = params['copies'] ? params['copies'].to_i : 1
			printRemote.print(microorganism, copies)
			success("Printing completed")
		end
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Print genericobject label
post '/print/g/:id' do
	defaults()
	begin
		genericobject = db.getGeneric(params[:id])
		if genericobject == nil
			status 404
			errmsg("No generic object with given ID")
		else
			# Initialize remote if necessary
			printRemote = db.getPrintRemote($frontendURL) if printRemote == nil
			copies = params['copies'] ? params['copies'].to_i : 1
			printRemote.print(genericobject, copies)
			success("Printing completed")
		end
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Set storage slot
put '/storage/:loc' do
	defaults()
	begin
		raise CloneStoreRuntimeError, "Storage slot is already occupied" unless db.getStorageSlot(params[:loc]) === nil
		raise CloneStoreRuntimeError, "No entry set" if params['entry'] == '' or params['entry'] == nil
		raise CloneStoreRuntimeError, "No host bacterium set" if params['host'] == '' or params['host'] == nil
		raise CloneStoreRuntimeError, "Plasmid does not exist" if db.getPlasmid(params['entry']) === nil

		raise CloneStoreRuntimeError, "Could not set storage slot" unless db.setStorageSlot(params[:loc], params['entry'], params['host'])
		success("Storage location set successfully")
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Free storage slot
delete '/storage/:loc' do
	defaults()
	begin
		if db.freeStorageSlot(params[:loc])
			success("Storage slot cleared")
		else
			raise CloneStoreRuntimeError, "Could not clear storage slot"
		end
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Get plasmid storage locations
get '/storage/id/:id' do
	defaults()
	begin
		res = []
		db.getStorageLocations(params[:id]).each{ |row|
			res.push({'location' => row['location'], 'host' => row['host']})
		}
		return {'type' => 'storageLocationList', 'locations' => res}.to_json
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Get plasmid in given location
get '/storage/loc/:loc' do
	defaults()
	begin
		res = db.getStorageSlot(params[:loc])
		
		if res === nil
			status 404
			errmsg("Storage location is empty")
		else
			storageContentMsg(res['id'], res['host'])
		end
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Search endpoint
get '/search/:mode' do
	defaults()
	begin
		raise CloneStoreRuntimeError, "No search query given" if !params['query'] or params['query'] == '' 
		query = params['query']

		case params[:mode]
			when 'creator'
				mode = :createdBy
			when 'description'
				mode = :description
			when 'id'
				mode = :id
			when 'any'
				mode = :any
			else
				raise CloneStoreRuntimeError, "Invalid search mode"
		end

		res = []
		db.search(mode, query).each{ |row|
			res.push({'id' => row['id'], 'type' => row['type'], 'createdBy' => row['createdBy'], 'description' => row['description']})
		}

		return {'type' => 'searchResultList', 'results' => res}.to_json
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Authentication endpoint

post '/auth' do
	defaults()
	begin
		raise CloneStoreRuntimeError, "No authentication token given" if !params['token'] or params['token'] == '' 
		session = Authenticator.authenticate(params['token'])

		if session != nil
			{'type' => 'sessionToken', 'sessionToken' => session}.to_json
		else
			status 403
			errmsg("Authentication failed - invalid token")
		end
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end