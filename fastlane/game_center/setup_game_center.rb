# Sets up Game Center for Dubloon the Game in App Store Connect: the leaderboards and the
# achievements the app reports to (DubloonGame/Services/GameCenter/GameCenterCatalog.swift),
# with their English text and the achievement artwork in ./achievements.
#
# Safe to run again: anything that already exists, by vendor identifier, is left alone.
#
#   LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bundle exec ruby fastlane/game_center/setup_game_center.rb
#
# Needs the app record for com.falsepeak.dubloon-game to exist (App Store Connect has no API
# for creating apps).

require "jwt"
require "net/http"
require "json"
require "openssl"
require "digest"

Encoding.default_external = Encoding::UTF_8

KEY_ID = "DGSCB63J99"
ISSUER = "59e10bb5-bb9e-43ce-b654-26849e933f8c"
KEY_PATH = File.expand_path("../AuthKey_#{KEY_ID}.p8", __dir__)
BUNDLE_ID = "com.falsepeak.dubloon-game"
IMAGES = File.expand_path("achievements", __dir__)

# The weekly race restarts every Monday at 00:00 UTC; GameScorebook.weekStart matches it.
WEEKLY_START = "2026-10-19T00:00:00Z"

LEADERBOARDS = [
  { id: "dubloon.game.leaderboard.show_points", ref: "Show Points", name: "Show Points",
    suffix: " points", singular: " point" },
  { id: "dubloon.game.leaderboard.imitation_points", ref: "Sound Imitation Points", name: "Sound Imitation",
    suffix: " points", singular: " point" },
  { id: "dubloon.game.leaderboard.dub_points", ref: "Movie Scene Dub Points", name: "Movie Scene Dub",
    suffix: " points", singular: " point" },
  { id: "dubloon.game.leaderboard.imitation_stars", ref: "Imitation Stars", name: "Stars Collected",
    suffix: " stars", singular: " star" },
  { id: "dubloon.game.leaderboard.weekly_show", ref: "Weekly Show", name: "This Week's Show",
    suffix: " points", singular: " point", weekly: true },
].freeze

# Points add up to 1000, Game Center's ceiling for an app.
ACHIEVEMENTS = [
  { id: "dubloon.game.achievement.first_take", ref: "First Take", points: 50, file: "first_take.png",
    name: "On Air", before: "Finish your first take.", after: "You finished your first take. Welcome to the show!" },
  { id: "dubloon.game.achievement.first_three_stars", ref: "First Three Stars", points: 100, file: "first_three_stars.png",
    name: "Star of the Show", before: "Win three stars on a sound.", after: "Three stars on a sound. The crowd goes wild!" },
  { id: "dubloon.game.achievement.ten_three_stars", ref: "Ten Three Stars", points: 150, file: "ten_three_stars.png",
    name: "Encore x10", before: "Win three stars on ten sounds.", after: "Three stars on ten sounds. Encore!" },
  { id: "dubloon.game.achievement.every_sound", ref: "Every Sound", points: 100, file: "every_sound.png",
    name: "Sound Collector", before: "Try every sound in Sound Imitation.", after: "You tried every sound in the show." },
  { id: "dubloon.game.achievement.first_dub", ref: "First Dub", points: 50, file: "first_dub.png",
    name: "Voice Actor", before: "Dub your first movie line.", after: "You dubbed your first movie line." },
  { id: "dubloon.game.achievement.great_dub", ref: "Great Dub", points: 100, file: "great_dub.png",
    name: "Lip Sync Legend", before: "Score 90 or more on a dubbed line.", after: "90 or more on a dubbed line. Spot on!" },
  { id: "dubloon.game.achievement.scene_wrapped", ref: "Scene Wrapped", points: 100, file: "scene_wrapped.png",
    name: "That's a Wrap", before: "Dub every line of a movie scene.", after: "You dubbed a whole scene. That's a wrap!" },
  { id: "dubloon.game.achievement.perfect_take", ref: "Perfect Take", points: 150, file: "perfect_take.png",
    name: "Perfect Take", before: "Get a perfect grade on any take.", after: "A perfect take. Take a bow!" },
  { id: "dubloon.game.achievement.hundred_stars", ref: "Hundred Stars", points: 150, file: "hundred_stars.png",
    name: "Superstar", before: "Collect 100 stars in Sound Imitation.", after: "100 stars collected. A true superstar!" },
].freeze

def token
  key = OpenSSL::PKey::EC.new(File.read(KEY_PATH))
  JWT.encode({ iss: ISSUER, iat: Time.now.to_i, exp: Time.now.to_i + 1200, aud: "appstoreconnect-v1" },
             key, "ES256", { kid: KEY_ID, typ: "JWT" })
end

def api(method, path, body = nil, attempts: 3)
  uri = URI(path.start_with?("http") ? path : "https://api.appstoreconnect.apple.com#{path}")
  request = Net::HTTP.const_get(method.capitalize).new(uri)
  request["Authorization"] = "Bearer #{token}"
  request["Content-Type"] = "application/json"
  request.body = body.to_json if body
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  if response.code.to_i >= 500 && attempts > 1
    sleep 2
    return api(method, path, body, attempts: attempts - 1)
  end
  unless response.code.to_i.between?(200, 299)
    raise "#{method.upcase} #{uri.path} → #{response.code}: #{response.body}"
  end
  response.body.to_s.empty? ? {} : JSON.parse(response.body)
end

def relationship(type, id) = { data: { type: type, id: id } }

app = api(:get, "/v1/apps?filter[bundleId]=#{BUNDLE_ID}")["data"].first
abort "No App Store Connect app for #{BUNDLE_ID} yet: create it on the website first." unless app
puts "app #{app['attributes']['name']} (#{app['id']})"

detail = begin
  api(:get, "/v1/apps/#{app['id']}/gameCenterDetail")["data"]
rescue RuntimeError => e
  raise unless e.message.include?("404")
  nil
end
detail ||= api(:post, "/v1/gameCenterDetails", {
  data: { type: "gameCenterDetails", attributes: { challengeEnabled: true },
          relationships: { app: relationship("apps", app["id"]) } }
})["data"]
puts "game center detail #{detail['id']}"

existing_boards = api(:get, "/v1/gameCenterDetails/#{detail['id']}/gameCenterLeaderboards?limit=200")["data"]
  .map { |l| l["attributes"]["vendorIdentifier"] }
LEADERBOARDS.each do |board|
  if existing_boards.include?(board[:id])
    puts "leaderboard #{board[:id]}: exists"
    next
  end
  attributes = {
    referenceName: board[:ref], vendorIdentifier: board[:id], defaultFormatter: "INTEGER",
    submissionType: "BEST_SCORE", scoreSortType: "DESC",
  }
  attributes.merge!(recurrenceStartDate: WEEKLY_START, recurrenceDuration: "P7D") if board[:weekly]
  created = api(:post, "/v1/gameCenterLeaderboards", {
    data: { type: "gameCenterLeaderboards", attributes: attributes,
            relationships: { gameCenterDetail: relationship("gameCenterDetails", detail["id"]) } }
  })["data"]
  api(:post, "/v1/gameCenterLeaderboardLocalizations", {
    data: { type: "gameCenterLeaderboardLocalizations",
            attributes: { locale: "en-US", name: board[:name],
                          formatterSuffix: board[:suffix], formatterSuffixSingular: board[:singular] },
            relationships: { gameCenterLeaderboard: relationship("gameCenterLeaderboards", created["id"]) } }
  })
  puts "leaderboard #{board[:id]}: created #{created['id']}"
end

def upload_image(localization_id, path)
  bytes = File.binread(path)
  reservation = api(:post, "/v1/gameCenterAchievementImages", {
    data: { type: "gameCenterAchievementImages",
            attributes: { fileName: File.basename(path), fileSize: bytes.bytesize },
            relationships: { gameCenterAchievementLocalization:
                               relationship("gameCenterAchievementLocalizations", localization_id) } }
  })["data"]
  reservation["attributes"]["uploadOperations"].each do |op|
    uri = URI(op["url"])
    request = Net::HTTP.const_get(op["method"].capitalize).new(uri)
    op["requestHeaders"].each { |h| request[h["name"]] = h["value"] }
    request.body = bytes.byteslice(op["offset"], op["length"])
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
    raise "image upload → #{response.code}" unless response.code.to_i.between?(200, 299)
  end
  api(:patch, "/v1/gameCenterAchievementImages/#{reservation['id']}", {
    data: { type: "gameCenterAchievementImages", id: reservation["id"], attributes: { uploaded: true } }
  })
end

existing_awards = api(:get, "/v1/gameCenterDetails/#{detail['id']}/gameCenterAchievements?limit=200")["data"]
  .map { |a| a["attributes"]["vendorIdentifier"] }
ACHIEVEMENTS.each do |award|
  if existing_awards.include?(award[:id])
    puts "achievement #{award[:id]}: exists"
    next
  end
  created = api(:post, "/v1/gameCenterAchievements", {
    data: { type: "gameCenterAchievements",
            attributes: { referenceName: award[:ref], vendorIdentifier: award[:id], points: award[:points],
                          showBeforeEarned: true, repeatable: false },
            relationships: { gameCenterDetail: relationship("gameCenterDetails", detail["id"]) } }
  })["data"]
  localization = api(:post, "/v1/gameCenterAchievementLocalizations", {
    data: { type: "gameCenterAchievementLocalizations",
            attributes: { locale: "en-US", name: award[:name],
                          beforeEarnedDescription: award[:before], afterEarnedDescription: award[:after] },
            relationships: { gameCenterAchievement: relationship("gameCenterAchievements", created["id"]) } }
  })["data"]
  upload_image(localization["id"], File.join(IMAGES, award[:file]))
  puts "achievement #{award[:id]}: created #{created['id']}"
end

puts "Done. Total achievement points: #{ACHIEVEMENTS.sum { |a| a[:points] }}"
