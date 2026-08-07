Pod::Spec.new do |s|
  s.name = "MapConductorForMapTiler"
  s.version = "1.2.0"
  s.summary = "MapConductor's MapTiler provider."
  s.license = { :type => "Apache-2.0", :file => "LICENSE" }
  s.author = "MapConductor"
  s.homepage = "https://github.com/MapConductor/ios-for-maptiler"
  s.source = { :path => __dir__ }
  s.platform = :ios, "15.1"
  s.swift_version = "5.9"
  s.source_files = "Sources/MapConductorForMapTiler/**/*.swift"
  s.dependency "MapConductorCore"
  s.dependency "MapLibre", "~> 6.20"
end
