#!/usr/bin/env ruby
require 'json'
require 'sinatra'
require_relative 'src/database.class'
require_relative 'src/plasmid.class'

version = '0.1.0'

db = Database.new('test.sqlite')

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
		e.message
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
		e.message
	end
end

# Archive plasmid
delete '/plasmid/:id' do
	begin
		idNum = params[:id].sub(/^p[^0-9]+/, '').to_i
		db.setArchiveFlag(idNum)
	rescue CloneStoreRuntimeError => e
		status 500
		e.message
	end
end