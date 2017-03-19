Pod::Spec.new do |spec|
  spec.name = "DataCache"
  spec.version = "0.5.0"
  spec.summary = "From JSON to Core Data and back."
  spec.homepage = "https://github.com/andersblehr/DataCache"
  spec.license = { type: 'MIT', file: 'LICENSE' }
  spec.authors = { "Anders Blehr" => 'anders@andersblehr.co' }
  spec.social_media_url = "http://twitter.com/andersblehr"

  spec.platform = :ios, "9.0"
  spec.requires_arc = true
  spec.source = { git: "https://github.com/andersblehr/DataCache.git", tag: "v#{spec.version}" }
  spec.source_files = "DataCache/**/*.{h,swift}"
end