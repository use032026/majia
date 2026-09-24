# PlotProof Lab / 图证实验室

An offline-first bilingual Flutter lab for learning how chart scales, outliers,
sample composition, and risk framing can change a claim. Eight bundled labs are
always available, and an optional versioned content pack adds weekly public-data
labs generated from Our World in Data and World Bank APIs.

## Product loop

1. Commit a judgment before seeing the explanation.
2. Change one experimental parameter.
3. Compare the same synthetic data under a fairer representation.
4. Read the reasoning and save the result locally.
5. Retry recent mistakes from the review queue.

The app has no account, application-owned backend, advertising, or analytics.
It periodically fetches a read-only JSON lesson pack over HTTPS and stores only
the validated pack, language preference, and learning attempts in local
`SharedPreferences`. Settings includes manual refresh and a confirmed clear-all
action. The active catalog is capped at 56 labs: eight bundled labs remain
fixed, while up to 48 dynamic labs are retained in insertion order. Once full,
each new dynamic lab evicts the oldest one; an existing ID is updated in place.
A failed refresh never removes the bundled or last valid content.

The checked-in `content/lesson_pack.json` is regenerated weekly by
`tool/generate_lesson_pack.py`. Set `PLOTPROOF_LESSON_PACK_URL` with
`--dart-define` to use another HTTPS distribution endpoint.

The iOS app supports iOS 15.0 and later.

## Run and test

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Product and release evidence is under `docs/product/` and `docs/release/`.
`com.example.plotproofLab`, public URLs, signing, physical-device evidence, and
App Store metadata are placeholders or missing release inputs, not submission
proof.
