# The Halloween deal as its own yearly plan: the first year at 2.99 USD (equalised per
# territory), then the normal yearly price. Only the Halloween banner over the games sells it
# (HalloweenOffer.swift), so the paywall keeps its usual prices: an introductory offer on the
# normal yearly plan would apply on the paywall too.
#
# One plan per app, in the app's existing "Dubloon Pro" group, at the yearly plan's level and
# full price. The introductory offer ends on FINISH; the plan stays on sale but nothing
# offers it afterwards.
#
#   LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bundle exec ruby fastlane/halloween_offer/setup_halloween_plan.rb studio|game
#
# Safe to run again: what exists is left alone and missing prices or offers are filled in.
# Still for afterwards: a review screenshot (the banner), the product in RevenueCat attached to
# the Pro entitlement, and the plan submitted with the build that adds the banner.

require "jwt"
require "net/http"
require "json"
require "openssl"

Encoding.default_external = Encoding::UTF_8

KEY_ID = "DGSCB63J99"
ISSUER = "59e10bb5-bb9e-43ce-b654-26849e933f8c"
KEY_PATH = File.expand_path("../AuthKey_#{KEY_ID}.p8", __dir__)

FINISH = "2026-11-04"
DEAL_USD = "2.99"

APPS = {
  "studio" => { group: "22404585", product: "com.falsepeak.reverse_singing_ios.yearly_halloween",
                ref: "Dubloon Yearly Halloween", price: "12.99", level: 1 },
  "game" => { group: "22490155", product: "com.falsepeak.dubloon_game.yearly_halloween",
              ref: "Dubloon Game Yearly Halloween", price: "5.99", level: 1 },
}.freeze
NAME = "Dubloon Pro Yearly"
DESCRIPTION = "Halloween deal: your first year at a special price."
REVIEW_NOTE = "Halloween deal, 20 Oct to 3 Nov 2026. This plan is only sold from the Halloween banner pinned " \
              "over the games on the home screen: its first year is a 2.99 USD pay-up-front introductory " \
              "offer, then it renews at the normal yearly price. The regular paywall keeps the normal " \
              "yearly plan and its prices. Same Dubloon Pro access as the other plans."

config = APPS[ARGV[0]] or abort "usage: setup_halloween_plan.rb studio|game"

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
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 60) { |http| http.request(request) }
  if (response.code.to_i >= 500 || response.code.to_i == 429) && attempts > 1
    sleep 3
    return api(method, path, body, attempts: attempts - 1)
  end
  raise "#{method.upcase} #{uri.request_uri} → #{response.code}: #{response.body.to_s.gsub(/\s+/, ' ')}" unless response.code.to_i.between?(200, 299)
  response.body.to_s.empty? ? {} : JSON.parse(response.body)
end

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

# The equalised price point in every territory, from the USA one at `usd`.
def points_for(subscription_id, usd)
  usa_points = all("/v1/subscriptions/#{subscription_id}/pricePoints?filter[territory]=USA&limit=200").first
  usa = usa_points.find { |p| p["attributes"]["customerPrice"] == usd } or abort "no USA point at #{usd}"
  equalized, = all("/v1/subscriptionPricePoints/#{usa['id']}/equalizations?include=territory&limit=200")
  ([["USA", usa["id"]]] + equalized.map { |p| [p.dig("relationships", "territory", "data", "id"), p["id"]] }).to_h
end

territories = all("/v1/territories?limit=200").first.map { |t| t["id"] }
existing = all("/v1/subscriptionGroups/#{config[:group]}/subscriptions?limit=200").first
record = existing.find { |s| s["attributes"]["productId"] == config[:product] }

if record
  puts "#{config[:product]}: exists (#{record['id']}, #{record['attributes']['state']})"
else
  record = api(:post, "/v1/subscriptions", {
    data: { type: "subscriptions",
            attributes: { name: config[:ref], productId: config[:product], subscriptionPeriod: "ONE_YEAR",
                          groupLevel: config[:level], familySharable: true, reviewNote: REVIEW_NOTE },
            relationships: { group: rel("subscriptionGroups", config[:group]) } },
  })["data"]
  api(:post, "/v1/subscriptionLocalizations", {
    data: { type: "subscriptionLocalizations",
            attributes: { locale: "en-US", name: NAME, description: DESCRIPTION },
            relationships: { subscription: rel("subscriptions", record["id"]) } },
  })
  # Availability before any price, or Apple rejects the prices.
  api(:post, "/v1/subscriptionAvailabilities", {
    data: { type: "subscriptionAvailabilities", attributes: { availableInNewTerritories: true },
            relationships: { subscription: rel("subscriptions", record["id"]),
                             availableTerritories: rels("territories", territories) } },
  })
  puts "#{config[:product]}: created #{record['id']}"
end

# Full price, equalised from the USA one.
priced, = all("/v1/subscriptions/#{record['id']}/prices?include=territory&limit=200")
priced_territories = priced.map { |p| p.dig("relationships", "territory", "data", "id") }.compact
added = 0
failed = []
points_for(record["id"], config[:price]).each do |territory, point_id|
  next if territory.nil? || priced_territories.include?(territory)
  begin
    api(:post, "/v1/subscriptionPrices", {
      data: { type: "subscriptionPrices", attributes: { preserveCurrentPrice: false },
              relationships: { subscription: rel("subscriptions", record["id"]),
                               subscriptionPricePoint: rel("subscriptionPricePoints", point_id),
                               territory: rel("territories", territory) } },
    })
    added += 1
  rescue RuntimeError => e
    failed << "price #{territory}"
    warn "price #{territory}: #{e.message[0, 300]}"
  end
end
puts "prices: #{added} added (#{priced_territories.size + added} territories)"

# The Halloween first year.
offers, = all("/v1/subscriptions/#{record['id']}/introductoryOffers?include=territory&limit=200")
offered = offers.map { |o| o.dig("relationships", "territory", "data", "id") }.compact
deal = points_for(record["id"], DEAL_USD)
made = 0
territories.each do |territory|
  next if offered.include?(territory)
  begin
    api(:post, "/v1/subscriptionIntroductoryOffers", {
      data: { type: "subscriptionIntroductoryOffers",
              attributes: { offerMode: "PAY_UP_FRONT", duration: "ONE_YEAR", numberOfPeriods: 1, endDate: FINISH },
              relationships: { subscription: rel("subscriptions", record["id"]), territory: rel("territories", territory),
                               subscriptionPricePoint: rel("subscriptionPricePoints", deal.fetch(territory)) } },
    })
    made += 1
  rescue RuntimeError, KeyError => e
    failed << "offer #{territory}"
    warn "offer #{territory}: #{e.message[0, 300]}"
  end
end
puts "intro offers: #{made} added (#{offered.size + made} territories)"
puts failed.empty? ? "Done." : "Failed: #{failed.join(', ')}"
