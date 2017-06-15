Pod::Spec.new do |s|
  s.name         = "MongoBaasODM"
  s.version      = "0.0.1"
  s.summary      = "An ODM wrapper for using the MongoDB service of the MongoDB's Baas."  
  s.homepage     = "https://stitch.mongodb.com"
  s.license      = {
  						:type => "Apache 2",
  						:file => "LICENSE"
  				   }
  s.authors      = "MongoDB"  
  s.platform     = :ios, "9.0"
  s.source       = { 
  						:git => "https://github.com/10gen/stitch-ios-sdk.git",
  						:tag => "#{s.version}"
  				   }
  s.source_files  = "MongoBaasODM/Sources/**/*.swift"
  s.requires_arc = true
  s.dependency "StitchLogger", "~> 0.0.1"
  s.dependency "ExtendedJson", "~> 0.0.1"
  s.dependency "StitchCore", "~> 0.0.1"
  s.dependency "MongoDBService", "~> 0.0.1"
end
