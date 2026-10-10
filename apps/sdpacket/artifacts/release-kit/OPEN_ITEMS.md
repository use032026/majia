# Open items

- The published privacy page identifies the operator as the independent
  developer of KIFXPRO. Confirm the legal individual or business name before
  submission if the target store or applicable jurisdiction requires it.
- Confirm the production website hosting provider and its connection/security
  log-retention configuration. The current privacy copy intentionally leaves
  retention dependent on the actual provider configuration.
- Android now uses the production application ID `com.kifxpro.lite` and has a
  local upload keystore. Configure the four `SDPACKET_ANDROID_*` Repository
  Secrets and verify the cloud-built AAB fingerprint before any Play upload.
- The app's English Privacy action currently routes to
  `https://kifxpro.com/index.html?lang=en`, although the published English
  privacy page is `https://kifxpro.com/privacy.html?lang=en`. Confirm and fix
  this app route before release. This material-only run did not edit app
  behavior.
- Legal review, physical-device checks, and Play Console presentation were not
  performed as part of static release-material generation.
