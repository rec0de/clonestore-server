#!/usr/bin/env ruby
require 'json'
require 'sinatra'
require_relative 'src/database.class'
require_relative 'src/plasmid.class'
require_relative 'src/printremote.class'

version = '0.1.0'

db = Database.new('test.sqlite')
printRemote = nil

# Error message JSON helper
def errmsg(msg)
	"{\"type\":\"error\", \"details\":\"#{msg}\"}"
end

# Success message JSON
def success(msg)
	"{\"type\":\"success\", \"details\":\"#{msg}\"}"
end

# Get server info
get '/' do
	"{\"type\": \"clonestore-server\", \"version\": \"#{version}\"}"
end

# Get plasmid
get '/plasmid/:id' do
	idNum = params[:id].sub(/^p[^0-9]+/, '').to_i
	begin
		plasmid = db.getPlasmid(idNum)
		if plasmid == nil
			status 404
			"No plasmid with given ID"
		else
			plasmid.to_json
		end
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Add plasmid
post '/plasmid' do
	begin
		plasmid = Plasmid::fromJSON(params['data'])
		id = db.insert(plasmid)
		status 200
		"{\"success\": true, \"id\": \"#{id}\"}"
	rescue CloneStoreRuntimeError => e
		status 400
		errmsg(e.message)
	end
end

# Archive plasmid
delete '/plasmid/:id' do
	begin
		idNum = params[:id].sub(/^p[^0-9]+/, '').to_i
		db.setArchiveFlag(idNum)
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Printer status
get '/print' do
	begin
		# Initialize remote if necessary
		printRemote = db.getPrintRemote if printRemote == nil
		"{\"type\": \"printerStatus\", \"online\": #{printRemote.status}}"	
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Printer setup
put '/print' do
	begin
		if params['url'] == nil || params['secret'] == nil || params['secret'] == '' || params['url'] == ''
			raise CloneStoreRuntimeError, "Printer URL or secret missing"
		end
		db.setupPrinter(params['url'], params['name'], params['location'], params['secret'])
		# Re-Initialize remote
		printRemote = db.getPrintRemote
		success('Printer setup successfully')
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end

# Print label
post '/print/:id' do
	begin
		idNum = params[:id].sub(/^p[^0-9]+/, '').to_i
		plasmid = db.getPlasmid(idNum)
		if plasmid == nil
			status 404
			errmsg("No plasmid with given ID")
		else
			# Initialize remote if necessary
			printRemote = db.getPrintRemote if printRemote == nil
			plasmid.to_json
			printRemote.print(plasmid)
			success("Printing completed")
		end
	rescue CloneStoreRuntimeError => e
		status 500
		errmsg(e.message)
	end
end