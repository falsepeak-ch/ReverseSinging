# Dubloon website

The landing page, served by Firebase Hosting from the `reverso-87e1a` project.

Plain HTML, with no build step. The images are downscaled copies of the App Store screenshots and app illustrations.

Preview it locally, then deploy it:

    cd Website
    firebase emulators:start --only hosting
    firebase deploy --only hosting

Add a custom domain under Firebase console → Hosting → Add custom domain.
