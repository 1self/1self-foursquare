require 'sinatra'
require 'omniauth'
require 'omniauth-foursquare'
require 'rest-client'
require 'time'
require 'foursquare2'
require_relative './1self_foursquare'

CALLBACK_BASE_URI = ENV['CALLBACK_BASE_URI'] || 'http://localhost:4567'

CLIENT_ID = ENV['CLIENT_ID'] || 'DOWYGA5X3PVX3WXXDL0S3MMCZSAQBMJZHWYJSHLGU4B5O1BH'
CLIENT_SECRET = ENV['CLIENT_SECRET'] || 'DPSNOMYFT2WETDZBIQTHAUW352C0CWJ5S2POQH1UHK2RZVES'
API_BASE_URL = ENV['API_BASE_URL'] || 'http://localhost:5000'

use OmniAuth::Builder do
  provider :foursquare, CLIENT_ID, CLIENT_SECRET
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
  erb :index
end

get '/auth/foursquare/callback' do
  username = request.env['omniauth.auth']['uid']
  auth_token = request.env['omniauth.auth']['credentials']['token']

  callback_url = "#{CALLBACK_BASE_URI}/sync?username=#{username}&auth_token=#{auth_token}&latestSyncField={{latestSyncField}}&streamid={{streamid}}"

  stream_resp = Foursquare1SelfLib.register_stream(session['oneselfUsername'], session['registrationToken'], callback_url)
  stream = JSON.parse(stream_resp)
  puts 'Registered stream'

  checkins = Foursquare1SelfLib.fetch_checkins(auth_token)
  puts 'Fetched checkins'

  oneself_events = Foursquare1SelfLib.convert_to_1self_events(checkins)
  puts 'Converted to 1self events'

  Foursquare1SelfLib.send_to_1self(stream['streamid'], stream['writeToken'], oneself_events)
  redirect(API_BASE_URL + '/integrations')
end

get '/sync' do
  latest_sync_field = params[:latestSyncField]
  streamid = params[:streamid]
  # username = params[:username]
  auth_token = params[:auth_token]
  write_token = request.env['HTTP_AUTHORIZATION']

  checkins = Foursquare1SelfLib.fetch_checkins(auth_token, latest_sync_field)
  puts 'Fetched checkins'

  oneself_events = Foursquare1SelfLib.convert_to_1self_events(checkins)
  puts 'Converted to 1self events'

  Foursquare1SelfLib.send_to_1self(streamid, write_token, oneself_events)
  puts 'Sent to 1self'
  'Success'
end
