# Submits Dubloon the Game's editable version for App Review together with everything that has
# to be reviewed alongside a first version: the in-app purchase, the subscriptions and their
# group, and the Game Center leaderboards and achievements. Pass --dry-run to build the
# submission and list its items without sending it.
#
#   LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bundle exec ruby fastlane/game_products/submit_game_review.rb [--dry-run]

require "jwt"
require "net/http"
require "json"
require "openssl"

KEY_ID = "DGSCB63J99"
ISSUER = "59e10bb5-bb9e-43ce-b654-26849e933f8c"
KEY_PATH = File.expand_path("../AuthKey_#{KEY_ID}.p8", __dir__)
BUNDLE_ID = "com.falsepeak.dubloon-game"
DRY_RUN = ARGV.include?("--dry-run")

def token
  key = OpenSSL::PKey::EC.new(File.read(KEY_PATH))
  JWT.encode({ iss: ISSUER, iat: Time.now.to_i, exp: Time.now.to_i + 1200, aud: "appstoreconnect-v1" },
             key, "ES256", { kid: KEY_ID, typ: "JWT" })
end

def api(method, path, body = nil, raise_on_error: true)
  uri = URI(path.start_with?("http") ? path : "https://api.appstoreconnect.apple.com#{path}")
  request = Net::HTTP.const_get(method.capitalize).new(uri)
  request["Authorization"] = "Bearer #{token}"
  request["Content-Type"] = "application/json"
  request.body = body.to_json if body
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  json = response.body.to_s.empty? ? {} : JSON.parse(response.body)
  if raise_on_error && !response.code.to_i.between?(200, 299)
    raise "#{method.upcase} #{uri.request_uri} → #{response.code}: #{response.body}"
  end
  [response.code.to_i, json]
end

def all(path)
  items = []
  loop do
    _, page = api(:get, path)
    items.concat(page["data"] || [])
    path = page.dig("links", "next") or break
  end
  items
end

def rel(type, id) = { data: { type: type, id: id } }

_, apps = api(:get, "/v1/apps?filter[bundleId]=#{BUNDLE_ID}")
app = apps["data"].first or abort "no app"
version = all("/v1/apps/#{app['id']}/appStoreVersions?filter[platform]=IOS")
  .find { |v| %w[PREPARE_FOR_SUBMISSION READY_FOR_REVIEW DEVELOPER_REJECTED REJECTED METADATA_REJECTED].include?(v["attributes"]["appStoreState"]) } or abort "no editable version"
_, build = api(:get, "/v1/appStoreVersions/#{version['id']}/build")
abort "version has no build" unless build["data"]
puts "version #{version['attributes']['versionString']} build #{build.dig('data', 'attributes', 'version')}"

# Reuse an open draft submission rather than making a second one.
drafts = all("/v1/reviewSubmissions?filter[app]=#{app['id']}&filter[platform]=IOS&filter[state]=READY_FOR_REVIEW")
submission = drafts.first || api(:post, "/v1/reviewSubmissions", {
  data: { type: "reviewSubmissions", attributes: { platform: "IOS" }, relationships: { app: rel("apps", app["id"]) } }
})[1]["data"]
puts "submission #{submission['id']}"

def add_item(submission, kind, type, id, label)
  code, json = api(:post, "/v1/reviewSubmissionItems", {
    data: { type: "reviewSubmissionItems",
            relationships: { reviewSubmission: rel("reviewSubmissions", submission["id"]), kind => rel(type, id) } }
  }, raise_on_error: false)
  detail = json.dig("errors", 0, "detail")
  puts "  + #{label}: #{code.between?(200, 299) ? 'added' : "#{code} #{detail}"}"
end

add_item(submission, :appStoreVersion, "appStoreVersions", version["id"], "version")

# Newest version of each versioned item, the one that awaits review.
def latest(path) = all(path).max_by { |v| v.dig("attributes", "createdDate").to_s }

all("/v1/apps/#{app['id']}/inAppPurchasesV2").each do |iap|
  v = latest("/v2/inAppPurchases/#{iap['id']}/versions")
  v ? add_item(submission, :inAppPurchaseVersion, "inAppPurchaseVersions", v["id"], iap["attributes"]["productId"])
    : puts("  ! #{iap['attributes']['productId']}: no version resource")
end
all("/v1/apps/#{app['id']}/subscriptionGroups").each do |group|
  gv = latest("/v1/subscriptionGroups/#{group['id']}/versions")
  gv ? add_item(submission, :subscriptionGroupVersion, "subscriptionGroupVersions", gv["id"], "group #{group['attributes']['referenceName']}")
     : puts("  ! group: no version resource")
  all("/v1/subscriptionGroups/#{group['id']}/subscriptions").each do |sub|
    v = latest("/v1/subscriptions/#{sub['id']}/versions")
    v ? add_item(submission, :subscriptionVersion, "subscriptionVersions", v["id"], sub["attributes"]["productId"])
      : puts("  ! #{sub['attributes']['productId']}: no version resource")
  end
end

_, detail = api(:get, "/v1/apps/#{app['id']}/gameCenterDetail")
gc = detail.dig("data", "id")
if gc
  all("/v1/gameCenterDetails/#{gc}/gameCenterLeaderboards").each do |board|
    v = latest("/v1/gameCenterLeaderboards/#{board['id']}/versions") rescue nil
    v ? add_item(submission, :gameCenterLeaderboardVersion, "gameCenterLeaderboardVersions", v["id"], board["attributes"]["vendorIdentifier"])
      : puts("  · #{board['attributes']['vendorIdentifier']}: no separate version (goes with the app)")
  end
  all("/v1/gameCenterDetails/#{gc}/gameCenterAchievements").each do |award|
    v = latest("/v1/gameCenterAchievements/#{award['id']}/versions") rescue nil
    v ? add_item(submission, :gameCenterAchievementVersion, "gameCenterAchievementVersions", v["id"], award["attributes"]["vendorIdentifier"])
      : puts("  · #{award['attributes']['vendorIdentifier']}: no separate version (goes with the app)")
  end
end

items = all("/v1/reviewSubmissions/#{submission['id']}/items")
puts "items in submission: #{items.size} (#{items.map { |i| i.dig('attributes', 'state') }.tally})"

if DRY_RUN
  puts "dry run: not submitted"
else
  api(:patch, "/v1/reviewSubmissions/#{submission['id']}", {
    data: { type: "reviewSubmissions", id: submission["id"], attributes: { submitted: true } }
  })
  _, now = api(:get, "/v1/reviewSubmissions/#{submission['id']}")
  puts "submitted: #{now.dig('data', 'attributes', 'state')}"
end
