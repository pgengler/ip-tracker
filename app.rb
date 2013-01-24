require 'rubygems'
require 'sinatra'
require 'sinatra/activerecord'
require 'socket'

set :database, 'postgres://ip:ip@localhost/ips'

def hostname(ip)
	begin
		address_parts = ip.split(/\./).map(&:to_i)
		hostname = Socket.gethostbyaddr(address_parts.pack('CCCC')).first
	rescue SocketError
		hostname = nil
	end
	hostname
end

class IP < ActiveRecord::Base
	attr_accessible :name, :ip
end

get '/' do
	@ip = env['REMOTE_ADDR']
	@hostname = hostname(@ip) if @ip
	@forwarded = env['HTTP_X_FORWARDED_FOR']
	@forwarded_host = hostname(@forwarded) if @forwarded

	erb :'index.html'
end

get '/:host' do |host|
	@host = host
	record = IP.find_by_host(host)
	if record
		@ip = record.ip
		erb :'show.html'
	else
		erb :'unknown.html'
	end
end

post '/:host' do |host|
	record = IP.find_by_host(host)
	unless record
		record = IP.new
		record.host = host
	end

	record.ip = env['REMOTE_ADDR']

	record.save!

	redirect "/#{host}"
end
