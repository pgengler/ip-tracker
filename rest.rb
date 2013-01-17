require 'sinatra'
require 'socket'

def hostname(ip)
	begin
		address_parts = ip.split(/\./).map(&:to_i)
		hostname = Socket.gethostbyaddr(address_parts.pack('CCCC')).first
	rescue SocketError
		hostname = nil
	end
	hostname
end

get '/' do
	@ip = env['REMOTE_ADDR']
	@hostname = hostname(@ip) if @ip
	@forwarded = env['HTTP_X_FORWARDED_FOR']
	@forwarded_host = hostname(@forwarded) if @forwarded

	erb :'index.html'
end
