# Runtime observations

Date: 2026-09-22. These are bounded simulator observations, not physical-device or App Store evidence.

## iPhone 16e / iOS 18.3 simulator

- Inspected empty state, experiment creation, Today with real local data, check-in sheet, saved entry, correction/undo entry points, Journey, and Settings.
- Switched Chinese/English, light/dark appearance, and larger system content size. Core controls remained reachable in the inspected paths.
- Persisted evidence: `iphone-16e-ios18_3-today-en-light.png`. It uses the explicitly recorded `seed-ipad.json` stress fixture to avoid treating manual keyboard test text as product content.

## iPad Pro 11-inch (M4) / iOS 18.3 simulator

- Loaded `seed-ipad.json`: a 31-calendar-day English experiment with 27 practice days, four pauses, recovery entries, and 7/14/21 milestone reviews.
- Inspected Today, Journey top, responsive statistics and stage path, then scrolled to the oldest daily observation at the report tail.
- Persisted evidence: `ipad-pro-11-ios18_3-journey-top.png` and `ipad-pro-11-ios18_3-journey-tail.png`.

## Not established by this run

- No physical device, iOS 15 runtime, Android runtime, VoiceOver/TalkBack, landscape, background kill, low-storage failure, true airplane mode, time-zone move, signed install, upload, TestFlight, or App Review was tested.
- Dark mode and several modal interactions were visually inspected during the run but not retained as screenshot artifacts; automated tests are the durable evidence for their covered state transitions.
