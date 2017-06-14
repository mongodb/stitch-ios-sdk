Pod::Spec.new do |s|
  s.name         = "MongoDBService"
  s.version      = "0.0.1"
  s.summary      = "An SDK to use the MongoDB service of the MongoDB's Baas."
  s.license      = {
  						:type => "MIT",
  						:file => "LICENSE.md"
  				   }
  s.platform     = :ios, "9.0"
  s.authors		 = "MongoDB"
  s.homepage     = "https://stitch.mongodb.com"
  s.source       = {
  						 :git => "https://github.com/10gen/stitch-ios-sdk.git",
  						 :tag => "#{s.version}"
  				   }
  s.source_files  = "MongoDBService/MongoDBService/**/*.swift"
  s.requires_arc = true
  s.dependency "StitchLogger", "~> 0.0.1"
  s.dependency "ExtendedJson", "~> 0.0.1"
  s.dependency "StitchCore", "~> 0.0.1"
end
