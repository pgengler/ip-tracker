require 'rubygems'
require 'sinatra'
require 'sinatra/activerecord'
require 'socket'
require_relative './relative_date'

if ENV['DATABASE_URL']
	set :database, ENV['DATABASE_URL']
elsif production?
	set :database,
		adapter: 'postgresql',
		host: ENV['DB_HOST'],
		port: ENV['DB_PORT'],
		database: ENV['POSTGRES_DB'],
		username: ENV['POSTGRES_USER'],
		password: ENV['POSTGRES_PASSWORD']
else
	set :database, 'postgres://ip:ip@localhost/ips'
end

# /up is exempt so the container health check works regardless of Host header.
set :host_authorization,
	permitted_hosts: %w[ip.pgengler.net localhost 127.0.0.1] + (ENV['PERMITTED_HOSTS'] || '').split(',').map(&:strip),
	allow_if: ->(env) { env['PATH_INFO'] == '/up' }

def hostname(ip)
	begin
		hostname = Addrinfo.ip(ip).getnameinfo[0]
		hostname = nil if hostname == ip
	rescue SocketError
		hostname = nil
	end
	hostname
end

def client_ip
	cf_ip = request.env['HTTP_CF_CONNECTING_IP'].to_s.strip
	return cf_ip unless cf_ip.empty?

	forwarded = request.env['HTTP_X_FORWARDED_FOR']
	return forwarded.split(',').first.strip if forwarded

	request.env['REMOTE_ADDR']
end

class IP < ActiveRecord::Base
end

get '/' do
	@ip = client_ip
	@hostname = hostname(@ip) if @ip

	erb :'index.html'
end

get '/up' do
	'ok'
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

	record.ip = client_ip

	record.save!

	format = ".#{format}" if format
	redirect "/ip/#{host}#{format}"
end
