# The App Store settings for Dubloon the Game that fastlane's deliver does not cover: free to
# download, available everywhere, and the third-party content declaration (the bundled Blender
# open-movie and public-domain scenes). Safe to run again.
#
#   LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bundle exec ruby fastlane/game_products/setup_game_app.rb

require "jwt"
require "net/http"
require "json"
require "openssl"

KEY_ID = "DGSCB63J99"
ISSUER = "59e10bb5-bb9e-43ce-b654-26849e933f8c"
KEY_PATH = File.expand_path("../AuthKey_#{KEY_ID}.p8", __dir__)
BUNDLE_ID = "com.falsepeak.dubloon-game"

def token
  key = OpenSSL::PKey::EC.new(File.read(KEY_PATH))
  JWT.encode({ iss: ISSUER, iat: Time.now.to_i, exp: Time.now.to_i + 1200, aud: "appstoreconnect-v1" },
             key, "ES256", { kid: KEY_ID, typ: "JWT" })
end

def api(method, path, body = nil)
  uri = URI(path.start_with?("http") ? path : "https://api.appstoreconnect.apple.com#{path}")
  request = Net::HTTP.const_get(method.capitalize).new(uri)
  request["Authorization"] = "Bearer #{token}"
  request["Content-Type"] = "application/json"
  request.body = body.to_json if body
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  raise "#{method.upcase} #{uri.request_uri} → #{response.code}: #{response.body}" unless response.code.to_i.between?(200, 299)
  response.body.to_s.empty? ? {} : JSON.parse(response.body)
end

def all(path)
  items = []
  loop do
    page = api(:get, path)
    items.concat(page["data"])
    path = page.dig("links", "next") or break
  end
  items
end

app = api(:get, "/v1/apps?filter[bundleId]=#{BUNDLE_ID}")["data"].first or abort "no app"
id = app["id"]

api(:patch, "/v1/apps/#{id}", {
  data: { type: "apps", id: id, attributes: { contentRightsDeclaration: "USES_THIRD_PARTY_CONTENT" } }
})
puts "content rights: third-party content declared"

manual = begin
  all("/v1/appPriceSchedules/#{id}/manualPrices")
rescue RuntimeError => e
  raise unless e.message.include?("404")
  [] # No schedule yet on a new app.
end
if manual.empty?
  free = all("/v1/apps/#{id}/appPricePoints?filter[territory]=USA&limit=200")
    .find { |p| p["attributes"]["customerPrice"].to_f.zero? } or abort "no free price point"
  api(:post, "/v1/appPriceSchedules", {
    data: { type: "appPriceSchedules",
            relationships: { app: { data: { type: "apps", id: id } },
                             baseTerritory: { data: { type: "territories", id: "USA" } },
                             manualPrices: { data: [{ type: "appPrices", id: "${free}" }] } } },
    included: [{ type: "appPrices", id: "${free}", attributes: { startDate: nil },
                 relationships: { appPricePoint: { data: { type: "appPricePoints", id: free["id"] } } } }]
  })
  puts "price: free"
else
  puts "price: already set"
end

begin
  api(:get, "/v1/apps/#{id}/appAvailabilityV2")
  puts "availability: already set"
rescue RuntimeError => e
  raise unless e.message.include?("404")
  territories = all("/v1/territories?limit=200").map { |t| t["id"] }
  api(:post, "/v2/appAvailabilities", {
    data: { type: "appAvailabilities", attributes: { availableInNewTerritories: true },
            relationships: { app: { data: { type: "apps", id: id } },
                             territoryAvailabilities: { data: territories.map { |t| { type: "territoryAvailabilities", id: "${#{t}}" } } } } },
    included: territories.map { |t|
      { type: "territoryAvailabilities", id: "${#{t}}", attributes: { available: true },
        relationships: { territory: { data: { type: "territories", id: t } } } }
    }
  })
  puts "availability: #{territories.size} territories"
end
