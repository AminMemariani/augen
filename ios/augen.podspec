#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint augen.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'augen'
  s.version          = '1.4.0'
  s.summary          = 'Flutter AR plugin using ARCore (Android), RealityKit/ARKit (iOS), and WebAssembly (web).'
  s.description      = <<-DESC
Augen is a Flutter plugin that enables pure-Dart AR development across mobile and web.
Uses RealityKit/ARKit on iOS, ARCore on Android, and a WebAssembly marker-detection
bridge on Flutter Web.
                       DESC
  s.homepage         = 'https://github.com/AminMemariani/augen'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Amin Memariani' => 'amin.memariani@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain an i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.swift_version = '5.0'

  # ARKit, RealityKit, and Combine are required.
  s.frameworks = 'ARKit', 'RealityKit', 'Combine'
end
