# Dubloon website

The landing page and the dub pack guide, served by Firebase Hosting from the `reverso-87e1a` project.

Plain HTML, with no build step. Each page carries its own CSS and script. The images are downscaled copies of the App Store screenshots and app illustrations.

Preview it locally, then deploy it:

    cd Website
    firebase serve --only hosting --port 5055
    firebase deploy --only hosting

Add a custom domain under Firebase console → Hosting → Add custom domain.

## Pages

- `index.html` leads with movie dubbing. The booth in the hero has two tabs: a working dub of two lines from Camp Rules, and the reverse-singing booth. Both use Web Audio and the microphone, so they need HTTPS or localhost, and nothing is uploaded. `/#reverse` opens the reverse tab.
- `dub-packs.html` (served at `/dub-packs`) is the guide to importing community dub packs, the page meant to be found by people looking for The Choicer Voicer's Dub Mode on iPhone or Mac. Keep it factual and keep the "not affiliated" line.
- `privacy.html`, `terms.html`, `404.html`.

## The dub demo

`public/media/` holds the first 8.7 s of the Camp Rules starter pack (Sprite Fright, CC BY 4.0): the muted picture, the music-and-effects bed and the two original lines. They are cut from `ReverseSinging/Resources/StarterPacks/CampRules.zip` with ffmpeg. The cue times, and the `REF` waveform string (the lines' level every 50 ms, 0-9), live in the `SCENE` block of the script in `index.html`; change them together with the media. The attribution under the booth and in the footer is required by the licence.

## SEO

Meta, Open Graph and JSON-LD (the app with its App Store rating, the FAQ, the how-to and breadcrumbs on the guide) live in each page, plus `robots.txt` and `sitemap.xml`. They all point at `https://reverso-87e1a.web.app/`: after adding a custom domain, replace that URL everywhere under `public/`. The FAQ text appears twice in each page, once visible and once in the JSON-LD; keep the two identical.

The rating in the JSON-LD and the hero is a snapshot (4.4 from 68, 2026-09-30, from `itunes.apple.com/lookup?id=6754534073`). The share image `img/og-dub.jpg` is a 1200×630 render of the hero; give it a new file name when it changes, since social sites cache by URL.
