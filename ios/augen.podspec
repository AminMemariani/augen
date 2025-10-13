#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint augen.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'augen'
  s.version          = '0.1.0'
  s.summary          = 'A Flutter plugin for building AR applications using RealityKit on iOS and ARCore on Android.'
  s.description      = <<-DESC
Augen is a Flutter plugin that enables pure Dart AR development without native code.
Uses RealityKit on iOS and ARCore on Android.
                       DESC
  s.homepage         = 'https://github.com/yourusername/augen'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Name' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  
  # RealityKit and ARKit frameworks
  s.frameworks = 'ARKit', 'RealityKit', 'Combine'
end
