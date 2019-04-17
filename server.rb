#!/usr/bin/env ruby
require 'json'
require 'sinatra'
require_relative 'src/database.class'
require_relative 'src/plasmid.class'
require_relative 'src/printremote.class'

version = '0.1.0'

$frontendURL = "http://cs.rec0de.net/?[plasmidid]"
$databaseFile = "test.sqlite"

db = Database.new($databaseFile)
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

# Plasmid ID message
def plasmidIdMsg(id)
	"{\"type\":\"plasmidID\", \"id\":\"#{id}\"}"
end

# Storage location message (plasmidID and bacterial host)
def storageContentMsg(id, host)
	"{\"type\":\"storageLocationContent\", \"id\":\"#{id}\", \"host\": \"#{host}\"}"
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
		id = db.insert(plasmid)
		status 200
		plasmidIdMsg(id)
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
		db.setArchiveFlag(params[:id])
		success("Plasmid archived successfully")
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

# Print label
post '/print/:id' do
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
			when 'backbone'
				mode = :backbonePlasmid
			when 'any'
				mode = :any
			else
				raise CloneStoreRuntimeError, "Invalid search mode"
		end

		res = []
		db.search(mode, query).each{ |row|
			res.push({'id' => row['id'], 'createdBy' => row['createdBy'], 'description' => row['description']})
		}

		return {'type' => 'searchResultList', 'results' => res}.to_json
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end