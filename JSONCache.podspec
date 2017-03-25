Pod::Spec.new do |s|
  s.name         = "JSONCache"
  s.version      = "1.0.4"
  s.summary      = "JSON to Core Data and back."
  s.description  = <<-DESC
                   JSONCache is a thin layer on top of Core Data that seamlessly consumes, persists and produces JSON data, converting between `snake_case` and `camelCase` as needed while establishing and preserving relationships between Core Data objects created from JSON records.
                   DESC
  s.homepage     = "https://github.com/andersblehr/JSONCache"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Anders Blehr" => "anders@andersblehr.co" }
  s.social_media_url   = "http://twitter.com/andersblehr"

  #  When using multiple platforms
  s.ios.deployment_target = "9.3"
  s.osx.deployment_target = "10.11"
  s.watchos.deployment_target = "3.0"
  s.tvos.deployment_target = "9.2"

  s.source       = { :git => "https://github.com/andersblehr/JSONCache.git", :tag => "#{s.version}" }
  s.source_files  = "JSONCache/**/*.{h,swift}"
  s.dependency 'Result', '~> 3.2.1'
  s.requires_arc = true
end
