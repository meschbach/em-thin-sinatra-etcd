################################################################################
# Anonymous port booting entrypoint
################################################################################
require 'trollop'

options = Trollop::options do
	opt :port, "Port to listen on", :default => 0
	opt :etcd_discovery, "EtcD discovery", :default => false
	opt :etcd_key, "EtcD key to store location under", :default => nil, :type => :string
end

########################################
# Service discovery
########################################
require 'etcd'
def notify_service_available( cli, url )
	return true unless cli[:etcd_discovery]

	begin
		key = cli[:etcd_key]
		key = "/http/proxy/em-thin-etcd" unless key

		etcd = Etcd.client
		puts "EtcD+ #{key} => #{url}"
		response = etcd.set( key, value: url )
		puts "Response: #{response.inspect}"
		etcd = nil
	rescue Exception => problem
		puts "Failed to notify EtcD #{problem.inspect}"
		return false
	end

	EM.add_shutdown_hook do
		puts "EtcD- #{key} => #{url}"
		shutdown_client = Etcd.client
		shutdown_client.delete( key, value: url )
	end
	return true
end

########################################
# Web service startup
########################################
require 'sinatra/base'
require 'thin'

class WebAPI < Sinatra::Base
	enable :logging

	get '/' do
		"up"
	end

	get '/binding' do
		notice = notify_service_available( settings.options, settings.http_service.backend.to_s )
		notice.to_s
	end
end

EM.run do
	http_service = Thin::Server.new WebAPI, 'localhost', options[:port], :signals => false
	http_service.start
	puts http_service.backend.to_s

	WebAPI.set :http_service, http_service
	WebAPI.set :options, options

	notify_service_available( options, http_service.backend.to_s )

	trap "INT" do
		EventMachine.stop
	end
end
