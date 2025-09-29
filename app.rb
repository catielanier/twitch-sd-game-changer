require "sinatra"
require "dotenv/load"
require "json"
require "net/http"
require "uri"

set :bind, "127.0.0.1"
set :port, 4567

put "/" do
  content_type :json
end