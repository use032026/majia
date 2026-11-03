# Android Web Core regression tests

From `example/android`, run both variants:

```bash
./gradlew :stmini_flutter:testReleaseUnitTest :stmini_flutter:testDebugUnitTest --no-daemon
```

`OnlineWebCoreTest` covers exact configured HTTPS origins, top-level-frame
enforcement, redirect authority revocation, callback envelopes, HTTP(S)
navigation and browser history back behaviour. HTTP requires the global
`webSecurity.allowInsecureHTTP` opt-in before HTTP can navigate or use Bridge.
