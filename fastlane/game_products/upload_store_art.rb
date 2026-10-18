# Uploads Dubloon the Game's product page header and search-result art into the app's asset
# library and places it on the editable version's localizations, replacing any placement of the
# same type. Make the art first with fastlane/screenshots_game/compose_store_art.swift.
#
#   LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bundle exec ruby fastlane/game_products/upload_store_art.rb <art dir> [locale ...]
#
# <art dir>/<locale>/header.png and search.png, one folder per App Store locale.

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

def api(method, path, body = nil, raise_on_error: true)
  uri = URI(path.start_with?("http") ? path : "https://api.appstoreconnect.apple.com#{path}")
  request = Net::HTTP.const_get(method.capitalize).new(uri)
  request["Authorization"] = "Bearer #{token}"
  request["Content-Type"] = "application/json"
  request.body = body.to_json if body
  # A long run over many images meets the odd connection that never opens; try again.
  attempts = 0
  begin
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 120) { |http| http.request(request) }
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, OpenSSL::SSL::SSLError
    attempts += 1
    raise if attempts > 3
    sleep 5 * attempts
    retry
  end
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


DIR = ARGV[0]
ONLY = ARGV[1..] || []
_, apps = api(:get, "/v1/apps?filter[bundleId]=#{BUNDLE_ID}")
APP = apps["data"].first or abort "no app"
LIB = APP["id"]
# The version being prepared: placements can't be added once it is waiting for review.
version = all("/v1/apps/#{LIB}/appStoreVersions?filter[platform]=IOS")
  .find { |v| %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED].include?(v["attributes"]["appStoreState"]) } or abort "no editable version"
V = version["id"]
puts "version #{version['attributes']['versionString']}"
KINDS = { "header" => "PRODUCT_PAGE_HEADER_ASSET", "search" => "APP_STORE_SEARCH_RESULTS_ASSET" }

# An older image under the same reference name, from an earlier run, holds the name: delete it,
# or, if the library keeps it, rename it out of the way and archive it.
def clear_reference(ref)
  all("/v1/appAssetLibraries/#{LIB}/images?limit=200").select { |i| i.dig("attributes", "referenceName") == ref }.each do |old|
    all("/v1/appAssetLibraryImages/#{old['id']}/placements").each { |p| api(:delete, "/v1/appAssetLibraryPlacements/#{p['id']}") } rescue nil
    code, = api(:delete, "/v1/appAssetLibraryImages/#{old['id']}", raise_on_error: false)
    next if code.between?(200, 299)
    api(:patch, "/v1/appAssetLibraryImages/#{old['id']}", { data: { type: "appAssetLibraryImages", id: old["id"],
      attributes: { referenceName: "#{ref} (replaced #{Time.now.to_i})", archived: true } } }, raise_on_error: false)
  end
end

def upload(path, ref)
  clear_reference(ref)
  bytes = File.binread(path)
  _, img = api(:post, "/v1/appAssetLibraryImages", { data: { type: "appAssetLibraryImages",
    attributes: { category: "CREATIVE_ASSETS", fileName: File.basename(path), fileSize: bytes.bytesize, referenceName: ref },
    relationships: { assetLibrary: { data: { type: "appAssetLibraries", id: LIB } } } } })
  id = img["data"]["id"]
  img["data"]["attributes"]["uploadOperations"].each do |op|
    uri = URI(op["url"])
    req = Net::HTTP.const_get(op["method"].capitalize).new(uri)
    (op["requestHeaders"] || []).each { |h| req[h["name"]] = h["value"] }
    req.body = bytes.byteslice(op["offset"], op["length"])
    attempts = 0
    begin
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 300) { |h| h.request(req) }
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, OpenSSL::SSL::SSLError
      attempts += 1
      raise if attempts > 3
      sleep 5 * attempts
      retry
    end
    raise "chunk #{res.code}" unless res.code.to_i.between?(200, 299)
  end
  api(:patch, "/v1/appAssetLibraryImages/#{id}", { data: { type: "appAssetLibraryImages", id: id, attributes: { uploaded: true } } })
  state = nil
  40.times do
    _, j = api(:get, "/v1/appAssetLibraryImages/#{id}")
    state = j.dig("data", "attributes", "state")
    break unless %w[AWAITING_UPLOAD UPLOAD_COMPLETE].include?(state)
    sleep 3
  end
  raise "#{path}: #{state}" if state == "FAILED"
  id
end

locs = all("/v1/appStoreVersions/#{V}/appStoreVersionLocalizations").to_h { |l| [l["attributes"]["locale"], l["id"]] }
Dir.children(DIR).sort.each do |locale|
  next unless ONLY.empty? || ONLY.include?(locale)
  loc = locs[locale] or (puts "#{locale}: no localization"; next)
  existing = all("/v1/appStoreVersionLocalizations/#{loc}/placements") rescue []
  KINDS.each do |file, type|
    path = File.join(DIR, locale, "#{file}.png")
    existing.select { |p| p.dig("attributes", "placementType") == type }.each { |p| api(:delete, "/v1/appAssetLibraryPlacements/#{p['id']}") }
    image = upload(path, "Dubloon the Game #{file} #{locale}")
    code, body = api(:post, "/v1/appAssetLibraryPlacements", { data: { type: "appAssetLibraryPlacements",
      attributes: { placementType: type, placementGroup: "DEFAULT_PROFILE" },
      relationships: { image: { data: { type: "appAssetLibraryImages", id: image } },
                       appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: loc } } } } }, raise_on_error: false)
    puts "#{locale} #{file}: #{code} #{body.dig('data', 'attributes', 'state') || body.dig('errors', 0, 'detail')}"
  end
end
