# Foursquare 1self lib

module Foursquare1SelfLib

  extend self

  APP_ID = ENV['APP_ID'] || 'app-id-fsqf3dsd91d9a3e715ff98bb9eedbd0a'
  APP_SECRET = ENV['APP_SECRET'] || 'app-secret-fsq2d606d784d87c0324335dadsddbd39b0f14c3196df6f128ff8ee8f36d14cd'
  API_BASE_URL = ENV['API_BASE_URL'] || 'http://localhost:5000'

  def register_stream(oneself_username, registration_token, callback_url)
    headers =  {Authorization: "#{APP_ID}:#{APP_SECRET}", 'registration-token' => registration_token,
                'content-type' => 'application/json'}

    puts "HEADERS ARE #{headers.inspect}"
    response =  RestClient::Request.execute(
      method: :post,
      payload: {:callbackUrl => callback_url}.to_json,
      url: "#{API_BASE_URL}/v1/users/#{oneself_username}/streams",
      headers: headers,
      accept: :json
    )
    response
  end

  def fetch_checkins(auth_token, afterTimestamp=nil)
    checkins = []
    offset = 0
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

  def convert_to_1self_events(checkins)
    oneself_events = []
    event = {
      source: 'foursquare integration',
      version: '0.0.1',
      objectTags: ['internet', 'social-network', 'foursquare'],
      actionTags: ['checkin', 'publish'],
      properties: {},
      dateTime: Time.now.utc.iso8601,
      latestSyncField: Time.now.utc.to_i
    }

    checkins.each do |checkin|
      if checkin["venue"].nil?
        next
      end

      data = {}
      data[:dateTime] =  Time.at(checkin['createdAt']).utc.iso8601
      data[:latestSyncField] = checkin['createdAt']
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

      oneself_events << event.merge(data)
    end
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

  def create_sync_start_event
    [
      { dateTime: Time.now.utc.iso8601,
        objectTags: ['sync'],
        actionTags: ['start'],
        source: 'foursquare integration',
        properties: {
        }
      }]
  end

  def create_sync_complete_event
    [
      { dateTime:  Time.now.utc.iso8601,
        objectTags: ['sync'],
        actionTags: ['complete'],
        source: 'foursquare integration',
        properties: {
        }
      }]
  end

end
