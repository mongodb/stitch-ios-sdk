Pod::Spec.new do |s|
  s.name         = "MongoDBService"
  s.version      = "3.0.2"
  s.summary      = "An SDK to use the MongoDB service of the MongoDB's Baas."
  s.license      = {
  						:type => "Apache 2",
  						:file => "./LICENSE"
  				   }
  s.platform     = :ios, "9.0"
  s.authors		 = "MongoDB"
  s.homepage     = "https://stitch.mongodb.com"
  s.source       = {
  						 :git => "https://github.com/mongodb/stitch-ios-sdk.git",
  						 :tag => "#{s.version}"
  				   }
  s.source_files  = "MongoDBService/MongoDBService/**/*.swift"
  s.requires_arc = true
  s.dependency "PromiseKit/CorePromise", "~> 6.1.0"
  s.dependency "StitchLogger", "~> 2.0.0"
  s.dependency "ExtendedJson", "~> 2.0.2"
  s.dependency "StitchCore", "~> 3.0.2"
end
