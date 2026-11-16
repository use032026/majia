Pod::Spec.new do |s|
  s.name = 'stmini_flutter'
  s.version = '0.1.1'
  s.summary = 'STMini main foundation subset for Deynu.'
  s.description = 'Stage one: native host initialization and localization, without Mini/Web loaders.'
  s.homepage = 'https://github.com/fsst-ios/stmini_flutter'
  s.license = { :file => '../LICENSE' }
  s.author = { 'FSST iOS' => 'https://github.com/fsst-ios' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*.swift', 'STMini/classes/frame/STMiniLocalization.swift'
  s.resource_bundles = {
    'stmini_flutter_localizations' => ['Resources/Language/*.json'],
    'stmini_flutter_privacy' => ['Resources/PrivacyInfo.xcprivacy']
  }
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
