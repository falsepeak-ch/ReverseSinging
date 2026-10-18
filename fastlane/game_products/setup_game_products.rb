# Creates Dubloon the Game's in-app products in App Store Connect, matching the RevenueCat
# project "Dubloon the Game" (PurchaseConfiguration under DUBLOON_GAME):
#
#   com.falsepeak.dubloon_game.lifetime  non-consumable   3.99 USD
#   com.falsepeak.dubloon_game.yearly    auto-renewable   5.99 USD / year, 3-day free trial
#   com.falsepeak.dubloon_game.monthly   auto-renewable   0.99 USD / month
#
# Available in every territory, prices equalised from the US one. Safe to run again: what
# exists is left alone, and a subscription's missing territory prices or trials are filled in.
#
#   LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bundle exec ruby fastlane/game_products/setup_game_products.rb
#
# Still for a human afterwards: a review screenshot for each product, then submit them with
# the first version.

require "jwt"
require "net/http"
require "json"
require "openssl"

Encoding.default_external = Encoding::UTF_8

KEY_ID = "DGSCB63J99"
ISSUER = "59e10bb5-bb9e-43ce-b654-26849e933f8c"
KEY_PATH = File.expand_path("../AuthKey_#{KEY_ID}.p8", __dir__)
BUNDLE_ID = "com.falsepeak.dubloon-game"
REVIEW_NOTE = "Dubloon Pro unlocks unlimited takes in both games (Movie Scene Dub and Sound Imitation). " \
              "Without it, players get three free takes in total; the paywall appears when they run out, " \
              "and from the gold Pro button on the home stage."

LIFETIME = { id: "com.falsepeak.dubloon_game.lifetime", ref: "Dubloon Game Lifetime", price: "3.99",
             name: "Dubloon Pro Lifetime", description: "Unlimited takes in every game, forever." }
SUBSCRIPTIONS = [
  { id: "com.falsepeak.dubloon_game.yearly", ref: "Dubloon Game Yearly", period: "ONE_YEAR", level: 1,
    price: "5.99", trial: "THREE_DAYS", name: "Dubloon Pro Yearly", description: "Unlimited takes in every game." },
  { id: "com.falsepeak.dubloon_game.monthly", ref: "Dubloon Game Monthly", period: "ONE_MONTH", level: 2,
    price: "0.99", name: "Dubloon Pro Monthly", description: "Unlimited takes in every game." },
].freeze

def token
  key = OpenSSL::PKey::EC.new(File.read(KEY_PATH))
  JWT.encode({ iss: ISSUER, iat: Time.now.to_i, exp: Time.now.to_i + 1200, aud: "appstoreconnect-v1" },
             key, "ES256", { kid: KEY_ID, typ: "JWT" })
end

def api(method, path, body = nil, attempts: 4)
  uri = URI(path.start_with?("http") ? path : "https://api.appstoreconnect.apple.com#{path}")
  request = Net::HTTP.const_get(method.capitalize).new(uri)
  request["Authorization"] = "Bearer #{token}"
  request["Content-Type"] = "application/json"
  request.body = body.to_json if body
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  if (response.code.to_i >= 500 || response.code.to_i == 429) && attempts > 1
    sleep 3
    return api(method, path, body, attempts: attempts - 1)
  end
  raise "#{method.upcase} #{uri.request_uri} → #{response.code}: #{response.body}" unless response.code.to_i.between?(200, 299)
  response.body.to_s.empty? ? {} : JSON.parse(response.body)
end

# Every page of a list.
def all(path)
  items = []
  included = []
  loop do
    page = api(:get, path)
    items.concat(page["data"])
    included.concat(page["included"] || [])
    path = page.dig("links", "next")
    break unless path
  end
  [items, included]
end

def rel(type, id) = { data: { type: type, id: id } }
def rels(type, ids) = { data: ids.map { |id| { type: type, id: id } } }

app = api(:get, "/v1/apps?filter[bundleId]=#{BUNDLE_ID}")["data"].first or abort "No app for #{BUNDLE_ID}"
puts "app #{app['attributes']['name']} (#{app['id']})"
territories = all("/v1/territories?limit=200").first.map { |t| t["id"] }
puts "#{territories.size} territories"

# MARK: - Lifetime

iaps = all("/v1/apps/#{app['id']}/inAppPurchasesV2?limit=200").first
lifetime = iaps.find { |i| i["attributes"]["productId"] == LIFETIME[:id] }
if lifetime
  puts "lifetime: exists (#{lifetime['id']})"
else
  lifetime = api(:post, "/v2/inAppPurchases", {
    data: { type: "inAppPurchases",
            attributes: { name: LIFETIME[:ref], productId: LIFETIME[:id], inAppPurchaseType: "NON_CONSUMABLE",
                          reviewNote: REVIEW_NOTE, familySharable: true },
            relationships: { app: rel("apps", app["id"]) } }
  })["data"]
  api(:post, "/v1/inAppPurchaseLocalizations", {
    data: { type: "inAppPurchaseLocalizations",
            attributes: { locale: "en-US", name: LIFETIME[:name], description: LIFETIME[:description] },
            relationships: { inAppPurchaseV2: rel("inAppPurchases", lifetime["id"]) } }
  })
  api(:post, "/v1/inAppPurchaseAvailabilities", {
    data: { type: "inAppPurchaseAvailabilities", attributes: { availableInNewTerritories: true },
            relationships: { inAppPurchase: rel("inAppPurchases", lifetime["id"]),
                             availableTerritories: rels("territories", territories) } }
  })
  points = all("/v2/inAppPurchases/#{lifetime['id']}/pricePoints?filter[territory]=USA&limit=200").first
  point = points.find { |p| p["attributes"]["customerPrice"] == LIFETIME[:price] } or abort "no USA point at #{LIFETIME[:price]}"
  api(:post, "/v1/inAppPurchasePriceSchedules", {
    data: { type: "inAppPurchasePriceSchedules",
            relationships: { inAppPurchase: rel("inAppPurchases", lifetime["id"]),
                             baseTerritory: rel("territories", "USA"),
                             manualPrices: rels("inAppPurchasePrices", ["${price}"]) } },
    included: [{ type: "inAppPurchasePrices", id: "${price}", attributes: { startDate: nil },
                 relationships: { inAppPurchasePricePoint: rel("inAppPurchasePricePoints", point["id"]) } }]
  })
  puts "lifetime: created #{lifetime['id']} at #{LIFETIME[:price]} USD"
end

# MARK: - Subscriptions

groups = all("/v1/apps/#{app['id']}/subscriptionGroups?limit=200").first
group = groups.find { |g| g["attributes"]["referenceName"] == "Dubloon Pro" }
unless group
  group = api(:post, "/v1/subscriptionGroups", {
    data: { type: "subscriptionGroups", attributes: { referenceName: "Dubloon Pro" },
            relationships: { app: rel("apps", app["id"]) } }
  })["data"]
  api(:post, "/v1/subscriptionGroupLocalizations", {
    data: { type: "subscriptionGroupLocalizations", attributes: { locale: "en-US", name: "Dubloon Pro" },
            relationships: { subscriptionGroup: rel("subscriptionGroups", group["id"]) } }
  })
  puts "group: created #{group['id']}"
end

existing = all("/v1/subscriptionGroups/#{group['id']}/subscriptions?limit=200").first
SUBSCRIPTIONS.each do |sub|
  record = existing.find { |s| s["attributes"]["productId"] == sub[:id] }
  unless record
    record = api(:post, "/v1/subscriptions", {
      data: { type: "subscriptions",
              attributes: { name: sub[:ref], productId: sub[:id], subscriptionPeriod: sub[:period],
                            groupLevel: sub[:level], familySharable: true, reviewNote: REVIEW_NOTE },
              relationships: { group: rel("subscriptionGroups", group["id"]) } }
    })["data"]
    api(:post, "/v1/subscriptionLocalizations", {
      data: { type: "subscriptionLocalizations",
              attributes: { locale: "en-US", name: sub[:name], description: sub[:description] },
              relationships: { subscription: rel("subscriptions", record["id"]) } }
    })
    # Availability before any price, or Apple rejects the prices.
    api(:post, "/v1/subscriptionAvailabilities", {
      data: { type: "subscriptionAvailabilities", attributes: { availableInNewTerritories: true },
              relationships: { subscription: rel("subscriptions", record["id"]),
                               availableTerritories: rels("territories", territories) } }
    })
    puts "#{sub[:id]}: created #{record['id']}"
  end

  priced, = all("/v1/subscriptions/#{record['id']}/prices?include=territory&limit=200")
  priced_territories = priced.map { |p| p.dig("relationships", "territory", "data", "id") }.compact
  usa_points = all("/v1/subscriptions/#{record['id']}/pricePoints?filter[territory]=USA&limit=200").first
  usa = usa_points.find { |p| p["attributes"]["customerPrice"] == sub[:price] } or abort "no USA point at #{sub[:price]}"
  equalized, = all("/v1/subscriptionPricePoints/#{usa['id']}/equalizations?include=territory&limit=200")
  targets = [["USA", usa["id"]]] + equalized.map { |p| [p.dig("relationships", "territory", "data", "id"), p["id"]] }
  added = 0
  targets.each do |territory, point_id|
    next if territory.nil? || priced_territories.include?(territory)
    api(:post, "/v1/subscriptionPrices", {
      data: { type: "subscriptionPrices", attributes: { preserveCurrentPrice: false },
              relationships: { subscription: rel("subscriptions", record["id"]),
                               subscriptionPricePoint: rel("subscriptionPricePoints", point_id),
                               territory: rel("territories", territory) } }
    })
    added += 1
  rescue RuntimeError => e
    warn "#{sub[:id]} price #{territory}: #{e.message[0, 160]}"
  end
  puts "#{sub[:id]}: #{added} prices added (#{priced_territories.size + added} territories)"

  next unless sub[:trial]
  offers, = all("/v1/subscriptions/#{record['id']}/introductoryOffers?include=territory&limit=200")
  offered = offers.map { |o| o.dig("relationships", "territory", "data", "id") }.compact
  trials = 0
  territories.each do |territory|
    next if offered.include?(territory)
    api(:post, "/v1/subscriptionIntroductoryOffers", {
      data: { type: "subscriptionIntroductoryOffers",
              attributes: { offerMode: "FREE_TRIAL", duration: sub[:trial], numberOfPeriods: 1 },
              relationships: { subscription: rel("subscriptions", record["id"]),
                               territory: rel("territories", territory) } }
    })
    trials += 1
  rescue RuntimeError => e
    warn "#{sub[:id]} trial #{territory}: #{e.message[0, 160]}"
  end
  puts "#{sub[:id]}: #{trials} free trials added"
end

puts "Done."
