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

class IP < ActiveRecord::Base
end

get '/' do
	@ip = env['REMOTE_ADDR']
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

	record.ip = env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR']
	record.last_report_at = DateTime.now

	record.save!

	format = ".#{format}" if format
	redirect "/ip/#{host}#{format}"
end
