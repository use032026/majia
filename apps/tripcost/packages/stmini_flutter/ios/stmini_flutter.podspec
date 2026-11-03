#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint stmini_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'stmini_flutter'
  s.version          = '0.1.1'
  s.summary          = 'Flutter host for ordinary online Web documents.'
  s.description      = <<-DESC
Reusable Flutter host for ordinary HTTPS Web documents.
                       DESC
  s.homepage         = 'https://github.com/fsst-ios/stmini_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'FSST iOS' => 'https://github.com/fsst-ios' }
  s.source           = { :path => '.' }
  # The legacy local runtime and its resources are removed from this pod.
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

end
