# Dubloon website

The landing page, served by Firebase Hosting from the `reverso-87e1a` project.

Plain HTML, with no build step. The images are downscaled copies of the App Store screenshots and app illustrations.

Preview it locally, then deploy it:

    cd Website
    firebase emulators:start --only hosting
    firebase deploy --only hosting

Add a custom domain under Firebase console → Hosting → Add custom domain.

The hero has a working reverse-singing booth (Web Audio, nothing uploaded), so it needs HTTPS or localhost for the microphone.

SEO lives in `index.html` (meta, Open Graph, JSON-LD with the app, its App Store rating and the FAQ), `robots.txt` and `sitemap.xml`. They all point at `https://reverso-87e1a.web.app/`: after adding a custom domain, replace that URL everywhere under `public/`. The rating in the JSON-LD and the hero is a snapshot (4.3 from 69, 2026-09-29).
