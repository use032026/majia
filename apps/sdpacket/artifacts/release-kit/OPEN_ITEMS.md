# Open items

- The published privacy page identifies the operator as the independent
  developer of KIFXPRO. Confirm the legal individual or business name before
  submission if the target store or applicable jurisdiction requires it.
- Confirm the production website hosting provider and its connection/security
  log-retention configuration. The current privacy copy intentionally leaves
  retention dependent on the actual provider configuration.
- Android still uses the development application ID
  `com.starburst.moving_box`, and local release builds fall back to debug
  signing when no release keystore is provided. Confirm the final Play package
  identity and release signing separately before any upload.
- The app's English Privacy action currently routes to
  `https://kifxpro.com/index.html?lang=en`, although the published English
  privacy page is `https://kifxpro.com/privacy.html?lang=en`. Confirm and fix
  this app route before release. This material-only run did not edit app
  behavior.
- Legal review, physical-device checks, and Play Console presentation were not
  performed as part of static release-material generation.
