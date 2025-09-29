require "sinatra"
require "dotenv/load"
require "json"
require "net/http"
require "uri"

set :bind, "127.0.0.1"
set :port, 4567

put "/" do
  content_type :json
  # Retrieve game name from request body
  request_payload = JSON.parse(request.body.read)
  game_name = request_payload["game_name"]
  # Connect to OBS WebSocket
  uri = URI.parse(ENV["OBS_WEBSOCKET_URL"])
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.request_uri)
  request["Content-Type"] = "application/json"
  # Retrieve current scene collection
  request.body = { "request-type" => "GetProfileList", "message-id" => "1" }.to_json
  response = http.request(request)
  response_data = JSON.parse(response.body)
  current_profile = response_data["currentProfileName"]
  # If scene collection is OBS_PRIMARY_PROFILE_NAME, use twitch primary broadcaster ID and OAuth token, else use secondary
  if current_profile == ENV["OBS_PRIMARY_PROFILE_NAME"]
    broadcaster_id = ENV["TWITCH_PRIMARY_BROADCASTER_ID"]
    oauth_token = ENV["TWITCH_PRIMARY_OAUTH_TOKEN"]
    client_id = ENV["TWITCH_PRIMARY_CLIENT_ID"]
    client_secret = ENV["TWITCH_PRIMARY_CLIENT_SECRET"]
  elsif current_profile == ENV["OBS_SECONDARY_PROFILE_NAME"]
    broadcaster_id = ENV["TWITCH_SECONDARY_BROADCASTER_ID"]
    oauth_token = ENV["TWITCH_SECONDARY_OAUTH_TOKEN"]
    client_id = ENV["TWITCH_SECONDARY_CLIENT_ID"]
    client_secret = ENV["TWITCH_SECONDARY_CLIENT_SECRET"]
  else
    { status: "error", message: "Unknown OBS profile" }.to_json
    return
  end
  # Get game ID from Twitch API by game name
  twitch_uri = URI.parse("https://api.twitch.tv/helix/games")
  twitch_params = { "name" => game_name }
  twitch_uri.query = URI.encode_www_form(twitch_params)
  twitch_request = Net::HTTP::Get.new(twitch_uri.request_uri)
  twitch_request["Client-ID"] = client_id
  twitch_request["Authorization"] = "Bearer #{oauth_token}"
  twitch_http = Net::HTTP.new(twitch_uri.host, twitch_uri.port)
  twitch_http.use_ssl = true
  twitch_response = twitch_http.request(twitch_request)
  twitch_response_data = JSON.parse(twitch_response.body)
  if twitch_response_data["data"] && !twitch_response_data["data"].empty?
    game_id = twitch_response_data["data"][0]["id"]
  else
    { status: "error", message: "Game not found on Twitch" }.to_json
    return
  end
  # Update stream info on Twitch
  update_uri = URI.parse("https://api.twitch.tv/helix/channels")
  update_params = { "broadcaster_id" => broadcaster_id, "game_id" => game_id }
  update_uri.query = URI.encode_www_form(update_params)
  update_request = Net::HTTP::Patch.new(update_uri.request_uri)
  update_request["Client-ID"] = client_id
  update_request["Authorization"] = "Bearer #{oauth_token}"
  update_request["Content-Type"] = "application/json"
  update_http = Net::HTTP.new(update_uri.host, update_uri.port)
  update_http.use_ssl = true
  update_response = update_http.request(update_request)
  if update_response.code.to_i == 200
    { status: "success", message: "Stream info updated successfully" }.to_json
  else
    { status: "error", message: "Failed to update stream info on Twitch" }.to_json
  end
end