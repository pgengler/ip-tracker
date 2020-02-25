require 'rubygems'
require 'sinatra'
require 'sinatra/activerecord'
require 'socket'
require_relative './relative_date'

set :database, 'postgres://ip:ip@localhost/ips'

def hostname(ip)
	begin
		hostname = Addrinfo.ip('::1').getnameinfo[0]
	rescue SocketError
		hostname = nil
	end
	hostname
end

class IP < ActiveRecord::Base
end

get '/' do
	@ip = env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR']
	@hostname = hostname(@ip) if @ip

	erb :'index.html'
end

get %r{/ip/([^\/?#\.]+)(?:\.|%2E)?([^\/?#]+)?} do |host, format|
	@record = IP.find_by(host: host)
	pass unless @record

	if format == 'txt'
		content_type :txt
		@record.ip
	else
		erb :'show.html'
	end
end

post %r{/ip/([^\/?#\.]+)(?:\.|%2E)?([^\/?#]+)?} do |host, format|
	record = IP.find_or_initialize_by(host: host)

	record.ip = env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR']

	record.save!

	format = ".#{format}" if format
	redirect "/ip/#{host}#{format}"
end
