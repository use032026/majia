# iOS 15 Configuration Validation

Generated: 2026-09-29T18:02:40+08:00

## Static evidence

- `ios/Podfile`: `platform :ios, '15.0'`; post-install sets every Pod target `IPHONEOS_DEPLOYMENT_TARGET` to `15.0`.
- `ios/Runner.xcodeproj/project.pbxproj`: Debug, Profile, and Release are all `15.0`.
- `ios/Flutter/AppFrameworkInfo.plist`: `MinimumOSVersion` is `15.0`.
- `ios/Runner/Info.plist`: `ITSAppUsesNonExemptEncryption` is the boolean `false` value, equivalent to `NO`.
- `pod install`: completed; generated Pods project has 18 effective deployment-target entries and all are `15.0`.
- Podfile Ruby syntax and both edited plist files passed static parsing.

## Focused Release build

An unsigned Xcode Release build used a task-local temporary DerivedData directory. The build passed, the built app plist reported `MinimumOSVersion=15.0` and `ITSAppUsesNonExemptEncryption=false`, and `vtool` reported iOS `minos 15.0` with SDK 26.5. The temporary DerivedData directory was removed after inspection.

The standard Flutter unsigned archive was then regenerated with:

```sh
fvm flutter build ipa --release --no-codesign --no-pub
```

Result: passed. `build/ios/archive/Runner.xcarchive` reports `MinimumOSVersion=15.0`, `ITSAppUsesNonExemptEncryption=false`, and Mach-O `minos 15.0`.

## Evidence limits

- This is static and unsigned build/archive evidence, not iOS 15 simulator or physical-device runtime proof.
- The archive remains unsigned, uses placeholder Bundle ID `com.example.paceJar`, and is not uploadable.
- No App Store upload, processing, TestFlight, or App Review action was performed.
