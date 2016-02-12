################################################################################
# Anonymous port booting entrypoint
################################################################################
require 'trollop'
require 'json'

options = Trollop::options do
	opt :etcd_key, "Nginx proxy configuration root", :type => :string, :required => true
	opt :host_name, "Host to be configured", :type => :string, :required => true
end

########################################
# Service discovery
########################################
require 'etcd'

document = JSON.generate({
	:name => options.host_name,
	:host => options.host_name,
	:http => { }
})

puts document.inspect

etcd = Etcd.client
etcd.set( options.etcd_key + "/" + options.host_name + "/config", { value: document } )
