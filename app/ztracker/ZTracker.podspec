Pod::Spec.new do |s|
  s.name = 'ZTracker'
  s.version = '1.0.0'
  s.summary = 'GPS natif Ziani Transport'
  s.license = 'Proprietary'
  s.homepage = 'https://zianitransport1.github.io/secteur/'
  s.author = 'Ziani Transport'
  s.source = { :git => 'https://github.com/zianitransport1/secteur.git', :tag => s.version.to_s }
  s.source_files = 'ios/Sources/**/*.swift'
  s.ios.deployment_target = '14.0'
  s.dependency 'Capacitor'
  s.swift_version = '5.1'
end
