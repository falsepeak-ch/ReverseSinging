# Dubloon the Game — UI sound selection

Every file listed here is CC0 1.0 (public domain). You can bundle them in a commercial app with no attribution. The Kenney packs ship a `License.txt` confirming CC0. Each Freesound and OpenGameArt page was checked by hand and shows CC0. For the OGA countdown, CC0 is one of the licences the page offers, and this selection uses that option.

I picked these by filename, description, duration and a rough pitch-contour check. **I have not listened to any of them.** Audition them before shipping.

Paths are relative to `DesignAssets/game-sfx/`.

| Role | Picked file | Source file | Pack / source | Licence |
|---|---|---|---|---|
| Button tap | `picked/tap.ogg` | `downloads/interface-sounds/Audio/click_001.ogg` | Kenney Interface Sounds | CC0 |
| Button pop (alt, cartoon) | `picked/tap-pop-alt.mp3` | `downloads/freesound-245646/245646_cartoon-pop-distorted-hq.mp3` | Freesound #245646 "Cartoon Pop (Distorted)" by unfa | CC0 |
| Menu select / confirm | `picked/select-confirm.ogg` | `downloads/interface-sounds/Audio/confirmation_001.ogg` | Kenney Interface Sounds | CC0 |
| Back | `picked/back.ogg` | `downloads/interface-sounds/Audio/back_002.ogg` | Kenney Interface Sounds | CC0 |
| Countdown beep (3, 2, 1) | `picked/countdown-beep.ogg` | `downloads/digital-audio/Audio/tone1.ogg` | Kenney Digital Audio | CC0 |
| "Go" beep | `picked/go-beep.ogg` | `downloads/digital-audio/Audio/highUp.ogg` | Kenney Digital Audio (rising tone) | CC0 |
| Full 3-2-1-go (alt, one file, 4.25 s) | `picked/countdown-321-go.ogg` | `downloads/oga-race-start-countdown/countdown.ogg` | OpenGameArt "Race Start Countdown" by kheetor | CC0 (multi-licence; CC0 chosen) |
| Star 1 ding | `picked/star-1.ogg` | `downloads/interface-sounds/Audio/glass_002.ogg` | Kenney Interface Sounds (~1 kHz ding) | CC0 |
| Star 2 ding | `picked/star-2.wav` | derived from star-1, +4 semitones (ffmpeg asetrate) | Kenney Interface Sounds (derived) | CC0 |
| Star 3 ding | `picked/star-3.wav` | derived from star-1, +7 semitones | Kenney Interface Sounds (derived) | CC0 |
| Score tally tick | `picked/tally-tick.ogg` | `downloads/interface-sounds/Audio/tick_002.ogg` | Kenney Interface Sounds | CC0 |
| Big win fanfare | `picked/big-win.wav` | `downloads/oga-win-sound-effect/Win sound.wav` | OpenGameArt "Win sound effect" (4.4 s) | CC0 |
| Big win (alt, shorter fanfare) | `picked/big-win-alt-fanfare.ogg` | `downloads/oga-classic-fanfare-lick/fanfare_3.ogg` | OpenGameArt "Classic fanfare lick" (2.9 s, made in GarageBand) | CC0 |
| Fail / aww (trombone) | `picked/fail-trombone.mp3` | `downloads/freesound-175409/175409_wah-wah-sad-trombone-hq.mp3` | Freesound #175409 "wah wah sad trombone" by kirbydx (real trombone, 5.2 s) | CC0 |
| Fail (alt, short) | `picked/fail-short.ogg` | `downloads/music-jingles/Audio/Sax jingles/jingles_SAX01.ogg` | Kenney Music Jingles (falling sax, about 459 to 262 Hz, 0.9 s) | CC0 |
| Crowd cheer / applause | `picked/crowd-cheer.mp3` | `downloads/freesound-859009/859009_small-auditorium-applause-cheering-hq.mp3` | Freesound #859009 "Small Auditorium Crowd Applause and Cheering" by ElevatorFan2020 (6.2 s) | CC0 |
| Crowd cheer (alt, long, whoops) | `picked/crowd-cheer-long.mp3` | `downloads/freesound-346689/346689_crowd-cheer-2-hq.mp3` | Freesound #346689 "Crowd cheer 2" (25 s) | CC0 |
| Applause (alt, long bed) | `picked/applause-long.wav` | `downloads/oga-applause-church/applause-clapping-church-crowd-immersive.wav` | OpenGameArt "Applause in a large hall or church" (39 s) | CC0 |
| Confetti pop | `picked/confetti-pop.mp3` | `downloads/freesound-26349/26349_partypopper-hq.mp3` | Freesound #26349 "partypopper" by Streety (0.6 s) | CC0 |
| Record start "on air" buzz | `picked/on-air-buzz.mp3` | `downloads/freesound-164089/164089_buzzer2-hq.mp3` | Freesound #164089 "buzzer2" by hypocore ("fits a game show setting") | CC0 |
| Transition swoosh | `picked/transition-swoosh.mp3` | `downloads/freesound-449996/449996_whoosh-short-mid-hq.mp3` | Freesound #449996 "whoosh_short_mid" by DJT4NN3R | CC0 |
| Coin | `picked/coin.ogg` | `downloads/rpg-audio/Audio/handleCoins.ogg` | Kenney RPG Audio (coins jingling in hand) | CC0 |
| Reward chime (alt for coin) | `picked/reward-chime.ogg` | `downloads/digital-audio/Audio/powerUp2.ogg` | Kenney Digital Audio | CC0 |

## Notes

- **Freesound files are the public HQ previews**, 128 kbps MP3. The original WAV/FLAC downloads need a Freesound login, so I skipped them. The previews are fine for UI cues. If you want lossless masters, log in yourself and download the originals from the same pages.
- **Star 2 and star 3** are pitch-shifted copies of star 1, saved as WAV because this ffmpeg build has no Vorbis encoder. Shifting the pitch this way also makes each copy shorter. If you'd rather have three separate samples, `interface-sounds/Audio/pluck_001.ogg` (about 441 Hz) and `pluck_002.ogg` (about 612 Hz) are also tonal.
- **Confetti** has an alternative: Freesound #458398 "Balloon Pop / Christmas cracker / Confetti Cannon" by Breviceps, at `downloads/freesound-458398/`.
- **Wah-wah fail** has a shorter real-brass alternative: Freesound #362206 "horn_fail_wahwah_1" by TaranP, at `downloads/freesound-362206/`.
- **On-air buzz:** a game-show buzzer can sound like "wrong answer". If that reads badly at record start, try `digital-audio/Audio/zapTwoTone.ogg` or `interface-sounds/Audio/switch_001.ogg` instead.
- **Back whoosh:** for a more whooshy back sound, try `interface-sounds/Audio/minimize_005.ogg` or the CC0 OpenGameArt "Swishes Sound Pack" in `downloads/oga-swishes-sound-pack/swishes/` (13 short swishes, about 0.1 to 0.2 s).
- **Other Kenney options:** `interface-sounds/Audio/` also has `select_*`, `maximize_*`, `drop_*` and `pluck_*` variants. `music-jingles/Audio/` has 85 short jingles (8-bit, Hit, Pizzicato, Sax, Steel) for round stings.

## Source URLs

Kenney (CC0, https://kenney.nl):
- Interface Sounds: https://kenney.nl/assets/interface-sounds (zip: https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip)
- UI Audio: https://kenney.nl/assets/ui-audio (zip: https://kenney.nl/media/pages/assets/ui-audio/490d233f68-1677590494/kenney_ui-audio.zip)
- Digital Audio: https://kenney.nl/assets/digital-audio (zip: https://kenney.nl/media/pages/assets/digital-audio/216eac4753-1677590265/kenney_digital-audio.zip)
- Impact Sounds: https://kenney.nl/assets/impact-sounds (zip: https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip)
- Casino Audio: https://kenney.nl/assets/casino-audio (zip: https://kenney.nl/media/pages/assets/casino-audio/2472606a04-1721639069/kenney_casino-audio.zip)
- Music Jingles: https://kenney.nl/assets/music-jingles (zip: https://kenney.nl/media/pages/assets/music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip)
- RPG Audio: https://kenney.nl/assets/rpg-audio (zip: https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip)

OpenGameArt (CC0):
- https://opengameart.org/content/win-sound-effect
- https://opengameart.org/content/classic-fanfare-lick
- https://opengameart.org/content/race-start-countdown
- https://opengameart.org/content/applause-in-a-large-hall-or-church
- https://opengameart.org/content/swishes-sound-pack

Freesound (CC0, https://creativecommons.org/publicdomain/zero/1.0/):
- https://freesound.org/people/ElevatorFan2020/sounds/859009/
- https://freesound.org/people/deleted_user_2104797/sounds/346689/ (posted by a since-deleted user)
- https://freesound.org/people/kirbydx/sounds/175409/
- https://freesound.org/people/TaranP/sounds/362206/
- https://freesound.org/people/Streety/sounds/26349/
- https://freesound.org/people/Breviceps/sounds/458398/
- https://freesound.org/people/hypocore/sounds/164089/
- https://freesound.org/people/DJT4NN3R/sounds/449996/
- https://freesound.org/people/unfa/sounds/245646/
