Pod::Spec.new do |s|
  s.name         = "MongoDBODM"
  s.version      = "0.1.0"
  s.summary      = "An ODM wrapper for using Stitch's MongoDB service."  
  s.homepage     = "https://stitch.mongodb.com"
  s.license      = {
  						:type => "Apache 2",
  						:file => "./LICENSE"
  				   }
  s.authors      = "MongoDB"  
  s.platform     = :ios, "9.0"
  s.source       = { 
  						:git => "https://github.com/mongodb/stitch-ios-sdk.git",
  						:tag => "#{s.version}"
  				   }
  s.source_files  = "MongoDBODM/MongoDBODM/**/*.swift"
  s.requires_arc = true
  s.dependency "StitchLogger", "~> 0.1.0"
  s.dependency "ExtendedJson", "~> 0.1.0"
  s.dependency "StitchCore", "~> 0.1.0"
  s.dependency "MongoDBService", "~> 0.1.0"
end
