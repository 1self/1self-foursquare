require 'sinatra'
require 'omniauth'
require 'omniauth-foursquare'
require 'rest-client'
require 'time'
require 'foursquare2'
require 'byebug'
require_relative './1self_foursquare'
require_relative './crypt'

CALLBACK_BASE_URI = ENV['CALLBACK_BASE_URI'] || 'http://localhost:4567'

FOURSQUARE_CLIENT_ID = ENV['FOURSQUARE_CLIENT_ID'] || 'DOWYGA5X3PVX3WXXDL0S3MMCZSAQBMJZHWYJSHLGU4B5O1BH'
FOURSQUARE_CLIENT_SECRET = ENV['FOURSQUARE_CLIENT_SECRET'] || 'DPSNOMYFT2WETDZBIQTHAUW352C0CWJ5S2POQH1UHK2RZVES'
CONTEXT_URI = ENV['CONTEXT_URI'] || 'http://app.1self.dev'

use OmniAuth::Builder do
  provider :foursquare, FOURSQUARE_CLIENT_ID, FOURSQUARE_CLIENT_SECRET
end

configure do
  enable :sessions, :logging
  set :logging, true
  set :session_secret, 'dqgAkAzrmpjt6XVxEAxkk3HKpMJdZsrn'
  set :views, "#{File.dirname(__FILE__)}/views"
  set :public_folder, proc { File.join(root, 'public') }
end

get '/' do
  session['oneselfUsername'] = params[:username]
  session['registrationToken'] = params[:token]
  byebug
  redirect to("/auth/foursquare")
end

get '/auth/foursquare/callback' do
  username = request.env['omniauth.auth']['uid']
  auth_token = request.env['omniauth.auth']['credentials']['token']

  encrypted_auth_token = Crypt.encrypt(auth_token)
  escaped_auth_token =  CGI.escape(encrypted_auth_token)
  callback_url = "#{CALLBACK_BASE_URI}/sync?username=#{username}&auth_token=#{escaped_auth_token}&latestSyncField={{latestSyncField}}&streamid={{streamid}}"

  stream_resp = Foursquare1SelfLib.register_stream(session['oneselfUsername'], session['registrationToken'], callback_url)
  stream = JSON.parse(stream_resp)
  puts 'Registered stream'

  checkins = Foursquare1SelfLib.fetch_checkins(encrypted_auth_token)
  puts 'Fetched checkins'

  followers_count = Foursquare1SelfLib.fetch_followers(username, encrypted_auth_token)
  puts 'Fetched followers count'

  oneself_events = Foursquare1SelfLib.convert_to_1self_events(checkins, followers_count)
  puts 'Converted to 1self events'

  Foursquare1SelfLib.send_to_1self(stream['streamid'], stream['writeToken'], oneself_events)
  redirect(CONTEXT_URI + '/integrations')
end

get '/sync' do
  latest_sync_field = params[:latestSyncField]
  streamid = params[:streamid]
  username = params[:username]

  # username = params[:username]
  encrypted_auth_token = params[:auth_token]
  write_token = request.env['HTTP_AUTHORIZATION']

  checkins = Foursquare1SelfLib.fetch_checkins(encrypted_auth_token, latest_sync_field)
  puts 'Fetched checkins'

  followers_count = Foursquare1SelfLib.fetch_followers(username, encrypted_auth_token)
  puts 'Fetched followers count'

  oneself_events = Foursquare1SelfLib.convert_to_1self_events(checkins, followers_count)
  puts 'Converted to 1self events'

  Foursquare1SelfLib.send_to_1self(streamid, write_token, oneself_events)
  puts 'Sent to 1self'
  'Success'
end
