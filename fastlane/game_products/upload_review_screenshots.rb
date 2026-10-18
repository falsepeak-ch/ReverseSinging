# Uploads the App Store review screenshot (the paywall, as a player sees it) to each of Dubloon
# the Game's products, replacing any screenshot already there.
#
#   LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bundle exec ruby fastlane/game_products/upload_review_screenshots.rb <paywall.png>

require "jwt"
require "net/http"
require "json"
require "openssl"
require "digest"

KEY_ID = "DGSCB63J99"
ISSUER = "59e10bb5-bb9e-43ce-b654-26849e933f8c"
KEY_PATH = File.expand_path("../AuthKey_#{KEY_ID}.p8", __dir__)
BUNDLE_ID = "com.falsepeak.dubloon-game"
GROUP_NAME = "Dubloon Pro"

path = ARGV[0] or abort "usage: upload_review_screenshots.rb <paywall.png>"
bytes = File.binread(path)

def token
  key = OpenSSL::PKey::EC.new(File.read(KEY_PATH))
  JWT.encode({ iss: ISSUER, iat: Time.now.to_i, exp: Time.now.to_i + 1200, aud: "appstoreconnect-v1" },
             key, "ES256", { kid: KEY_ID, typ: "JWT" })
end

def api(method, path, body = nil)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  request = Net::HTTP.const_get(method.capitalize).new(uri)
  request["Authorization"] = "Bearer #{token}"
  request["Content-Type"] = "application/json"
  request.body = body.to_json if body
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  raise "#{method.upcase} #{uri.path} → #{response.code}: #{response.body}" unless response.code.to_i.between?(200, 299)
  response.body.to_s.empty? ? {} : JSON.parse(response.body)
end

# Reserves, uploads and commits one screenshot. `kind` is the resource type, `owner` the
# relationship name and type it hangs off.
def upload(kind, owner_key, owner_type, owner_id, bytes, filename)
  reservation = api(:post, "/v1/#{kind}", {
    data: { type: kind, attributes: { fileName: filename, fileSize: bytes.bytesize },
            relationships: { owner_key => { data: { type: owner_type, id: owner_id } } } }
  })["data"]
  reservation["attributes"]["uploadOperations"].each do |op|
    uri = URI(op["url"])
    request = Net::HTTP.const_get(op["method"].capitalize).new(uri)
    op["requestHeaders"].each { |h| request[h["name"]] = h["value"] }
    request.body = bytes.byteslice(op["offset"], op["length"])
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
    raise "upload → #{response.code}" unless response.code.to_i.between?(200, 299)
  end
  api(:patch, "/v1/#{kind}/#{reservation['id']}", {
    data: { type: kind, id: reservation["id"],
            attributes: { uploaded: true, sourceFileChecksum: Digest::MD5.hexdigest(bytes) } }
  })
end

def replace_existing(path)
  existing = api(:get, path)["data"]
  api(:delete, "/v1/#{existing['type']}/#{existing['id']}") if existing
rescue RuntimeError => e
  raise unless e.message.include?("404")
end

app = api(:get, "/v1/apps?filter[bundleId]=#{BUNDLE_ID}")["data"].first or abort "no app"
name = File.basename(path)

api(:get, "/v1/apps/#{app['id']}/inAppPurchasesV2")["data"].each do |iap|
  replace_existing("/v2/inAppPurchases/#{iap['id']}/appStoreReviewScreenshot")
  upload("inAppPurchaseAppStoreReviewScreenshots", :inAppPurchaseV2, "inAppPurchases", iap["id"], bytes, name)
  puts "#{iap['attributes']['productId']}: screenshot uploaded"
end

group = api(:get, "/v1/apps/#{app['id']}/subscriptionGroups")["data"]
  .find { |g| g["attributes"]["referenceName"] == GROUP_NAME } or abort "no group"
api(:get, "/v1/subscriptionGroups/#{group['id']}/subscriptions")["data"].each do |sub|
  replace_existing("/v1/subscriptions/#{sub['id']}/appStoreReviewScreenshot")
  upload("subscriptionAppStoreReviewScreenshots", :subscription, "subscriptions", sub["id"], bytes, name)
  puts "#{sub['attributes']['productId']}: screenshot uploaded"
end
