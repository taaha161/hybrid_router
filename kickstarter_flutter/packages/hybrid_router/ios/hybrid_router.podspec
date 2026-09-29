Pod::Spec.new do |s|
  s.name             = 'hybrid_router'
  s.version          = '0.0.1'
  s.summary          = 'Typed Pigeon bridge for hybrid_router (Flutter add-to-app routing).'
  s.homepage         = 'https://github.com/taaha161/hybrid_router'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Taaha Rauf'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
