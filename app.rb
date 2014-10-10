require 'rubygems'
require 'sinatra'
require 'sinatra/activerecord'
require 'socket'
require_relative './relative_date'

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

def ip_addr
	env['HTTP_X_REAL_IP'] || env['REMOTE_ADDR']
end

class IP < ActiveRecord::Base
end

get '/' do
	@ip = ip_addr
	@hostname = hostname(@ip) if @ip
	@forwarded = env['HTTP_X_FORWARDED_FOR']
	@forwarded_host = hostname(@forwarded) if @forwarded

	erb :'index.html'
end

get %r{/ip/([^\/?#\.]+)(?:\.|%2E)?([^\/?#]+)?} do |host, format|
	@record = IP.find_by_host(host)
	pass unless @record

	if format == 'txt'
		content_type :txt
		@record.ip
	else
		erb :'show.html'
	end
end

post %r{/ip/([^\/?#\.]+)(?:\.|%2E)?([^\/?#]+)?} do |host, format|
	record = IP.find_or_initialize_by_host(host)

	record.ip = ip_addr

	record.save!

	format = ".#{format}" if format
	redirect "/ip/#{host}#{format}"
end
