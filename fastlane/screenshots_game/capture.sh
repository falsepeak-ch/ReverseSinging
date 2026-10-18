#!/bin/zsh
# Captures Dubloon the Game's App Store screenshots in every locale, from a Debug build on a
# 6.9-inch simulator (1320x2868), using the `-gameShot` launch argument to open each screen.
#
#   fastlane/screenshots_game/capture.sh [locale ...]
#
# Writes <store locale>/01_home.png … 05_scenes.png beside this script. The hero (00_hero.png)
# comes from compose_hero.swift.

set -e
cd "${0:A:h}/../.."

DEVICE=${DEVICE:-19888FB6-E38B-4D9F-A677-EACA1D3D6AFC}
APP=build/GameDD/Build/Products/Debug-iphonesimulator/DubloonGame.app
BUNDLE=com.falsepeak.dubloon-game
OUT=fastlane/screenshots_game

# store locale → app language, region
typeset -A LANGS=(
  en-US "en en_US" es-ES "es es_ES" ca "ca ca_ES" fr-FR "fr fr_FR" it "it it_IT" pt-PT "pt-PT pt_PT"
  de-DE "de de_DE" nl-NL "nl nl_NL" da "da da_DK" sv "sv sv_SE" no "nb nb_NO" fi "fi fi_FI"
  pl "pl pl_PL" cs "cs cs_CZ" el "el el_GR" ru "ru ru_RU" uk "uk uk_UA" tr "tr tr_TR"
  ja "ja ja_JP" ar-SA "ar ar_SA" th "th th_TH"
)
# shot → file, seconds to settle (the stage animates in; rounds wait for the host's line)
SHOTS=(${=SHOTS_OVERRIDE:-home:01_home:7 dub:02_dub:9 imitate:03_imitate:9 sounds:04_sounds:6 scenes:05_scenes:6})

locales=(${@:-${(k)LANGS}})

xcrun simctl status_bar $DEVICE override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl uninstall $DEVICE $BUNDLE 2>/dev/null || true
xcrun simctl install $DEVICE $APP
# Granted up front so no system prompt lands in a shot.
xcrun simctl privacy $DEVICE grant microphone $BUNDLE

for locale in $locales; do
  set -- ${=LANGS[$locale]}
  lang=$1 region=$2
  mkdir -p $OUT/$locale
  for shot in $SHOTS; do
    name=${shot%%:*}; rest=${shot#*:}; file=${rest%%:*}; wait=${rest#*:}
    xcrun simctl launch --terminate-running-process $DEVICE $BUNDLE \
      -forceAccessState unlocked -gameShot $name \
      -AppleLanguages "($lang)" -AppleLocale $region >/dev/null
    sleep $wait
    xcrun simctl io $DEVICE screenshot --type=png $OUT/$locale/$file.png >/dev/null 2>&1
  done
  echo "$locale done"
done
xcrun simctl terminate $DEVICE $BUNDLE 2>/dev/null || true
