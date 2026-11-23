#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint stmini_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'stmini_flutter'
  s.version          = '0.1.1'
  s.summary          = 'Flutter host for verified local STMini programs.'
  s.description      = <<-DESC
Reusable Flutter host for opening verified existing local STMini packages.
                       DESC
  s.homepage         = 'https://github.com/fsst-ios/stmini_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'FSST iOS' => 'https://github.com/fsst-ios' }
  s.source           = { :path => '.' }
  # STMini is vendored with the plugin so the consuming Flutter App has no
  # dependency on a different App project's absolute source path.
  s.source_files = 'Classes/**/*', 'STMini/classes/**/*'
  s.resource_bundles = {
    'STMini' => ['STMini/assets/*.bundle'],
    'stmini_flutter_localizations' => ['Resources/Language/*.json'],
    # STMini persists its own Mini storage through UserDefaults.  This
    # manifest must be bundled with the SDK for every consuming App Store
    # archive; an app-level manifest cannot declare usage for this framework.
    'stmini_flutter_privacy' => ['Resources/PrivacyInfo.xcprivacy']
  }
  s.dependency 'Flutter'
  s.dependency 'ZIPFoundation', '0.9.19'
  s.dependency 'Masonry'
  s.dependency 'SDWebImage'
  s.dependency 'HXWRefresh'
  s.dependency 'Toast-Swift'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

end
