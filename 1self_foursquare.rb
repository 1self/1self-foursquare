# Foursquare 1self lib
require_relative './crypt'

module Foursquare1SelfLib

  extend self

  APP_ID = ENV['APP_ID'] || 'app-id-fsqf3dsd91d9a3e715ff98bb9eedbd0a'
  APP_SECRET = ENV['APP_SECRET'] || 'app-secret-fsq2d606d784d87c0324335dadsddbd39b0f14c3196df6f128ff8ee8f36d14cd'
  API_BASE_URL = ENV['API_BASE_URL'] || 'http://localhost:5000'

  def register_stream(oneself_username, registration_token, callback_url)
    headers =  {Authorization: "#{APP_ID}:#{APP_SECRET}", 'registration-token' => registration_token,
                'content-type' => 'application/json'}

    response =  RestClient::Request.execute(
      method: :post,
      payload: {:callbackUrl => callback_url}.to_json,
      url: "#{API_BASE_URL}/v1/users/#{oneself_username}/streams",
      headers: headers,
      accept: :json
    )
    response
  end

  def fetch_checkins(encrypted_auth_token, afterTimestamp=nil)
    checkins = []
    offset = 0
    auth_token = Crypt.decrypt(encrypted_auth_token)
    client = Foursquare2::Client.new(:oauth_token => auth_token, :api_version => Time.now.strftime("%Y%m%d"))

    if !afterTimestamp || afterTimestamp.empty?
      checkins_response = client.user_checkins(limit: 100, offset: offset)

      total_checkins = checkins_response['count']
      puts "Total checkins count is #{total_checkins}"
      checkins = checkins + checkins_response['items']

      while offset <= total_checkins
        offset += 100
        puts "Hitting with offset #{offset}"
        checkins_response = client.user_checkins(limit: 100, offset: offset)
        checkins += checkins_response['items']
      end

    else
      afterTimestampEpoch = afterTimestamp.to_i + 1
      checkins_response = client.user_checkins(limit: 250, afterTimestamp: afterTimestampEpoch)
      checkins += checkins_response['items']
    end

    checkins
  end

  def fetch_followers(username, encrypted_auth_token)
    auth_token = Crypt.decrypt(encrypted_auth_token)
    client = Foursquare2::Client.new(:oauth_token => auth_token, :api_version => Time.now.strftime("%Y%m%d"))
    user = client.user(username)
    user.friends["count"]
  end

  def convert_to_1self_events(checkins, followers_count)
    oneself_events = []

    # Create checkins event
    checkins.each do |checkin|
      if checkin["venue"].nil?
        next
      end
      checkin_event = get_checkin_event(checkin)
      oneself_events << checkin_event
    end

    # Create followers count event
    followers_event = get_followers_event(followers_count)
    oneself_events << followers_event

    oneself_events
  end

  def send_to_1self(streamid, writeToken, oneself_events)
    url = API_BASE_URL + '/v1/streams/' + streamid + '/events/batch'
    puts("Authorization header is ", writeToken)
    request = lambda { |evts|  RestClient.post url, evts.to_json, content_type: :json, accept: :json, Authorization: writeToken  }
    request.call(create_sync_start_event)

    sliced_oneself_events = oneself_events.each_slice(200).to_a
    sliced_oneself_events.each do |events|
      response = request.call(events)
    end
    request.call(create_sync_complete_event)
  end


  private

  def get_event_common
    {
      source: '1self-foursquare',
      version: '0.0.1',
      properties: {},
      dateTime: Time.now.utc.iso8601,
      latestSyncField: 0
    }
  end


  def get_checkin_event(checkin)
    data = {}
    data[:dateTime] =  Time.at(checkin['createdAt']).utc.iso8601
    data[:latestSyncField] = checkin['createdAt']
    data[:objectTags] = ['internet', 'social-network', 'foursquare']
    data[:actionTags] = ['checkin', 'publish']
    data[:properties] = {}
    data[:location] = {}
    data[:properties][:name] = checkin['venue']['name']
    data[:properties][:address] = checkin['venue']['location']['address']
    data[:properties][:city] = checkin['venue']['location']['city']
    data[:properties][:state] = checkin['venue']['location']['state']
    data[:properties][:country] = checkin['venue']['location']['country']
    data[:properties][:cc] = checkin['venue']['location']['cc']
    data[:properties][:crossStreet] = checkin['venue']['location']['crossStreet']
    data[:location][:lat] =  checkin['venue']['location']['lat']
    data[:location][:lng] =  checkin['venue']['location']['lng']

    checkin_event = get_event_common
    checkin_event.merge(data)
  end

  def get_followers_event(followers_count)
    followers_event = {}

    followers_event[:dateTime] =  Time.now.utc.iso8601
    followers_event[:latestSyncField] = 0
    followers_event[:objectTags] = ["internet", "social-network", "foursquare", "social-graph", "inbound", "follower"]
    followers_event[:actionTags] = ['sample']
    followers_event[:properties] = {}
    followers_event[:properties][:source] = "1self-foursquare"
    followers_event[:properties][:count] = followers_count

    follower_event = get_event_common
    follower_event.merge(followers_event)
  end

  def create_sync_start_event
    [
      { dateTime: Time.now.utc.iso8601,
        objectTags: ['sync'],
        actionTags: ['start'],
        properties: {
          source: '1self-foursquare'
        }
      }]
  end

  def create_sync_complete_event
    [
      { dateTime:  Time.now.utc.iso8601,
        objectTags: ['sync'],
        actionTags: ['complete'],
        properties: {
          source: '1self-foursquare'
        }
      }]
  end

end
