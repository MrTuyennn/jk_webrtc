#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_webrtc'
  s.version          = '0.0.1'
  s.summary          = 'Flutter WebRTC plugin for iOS.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'https://www.runhualink.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'RHWebRTC' => 'haichenghuang@runhualink.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'Libyuv', '1703'
  s.ios.deployment_target = '10.0'
  s.static_framework = true
  s.vendored_frameworks = 'WebRTC.xcframework'
end
