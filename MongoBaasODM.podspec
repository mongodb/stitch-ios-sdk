Pod::Spec.new do |s|
  s.name         = "MongoBaasODM"
  s.version      = "0.0.1"
  s.summary      = "An ODM wrapper for using the MongoDB service of the MongoDB's Baas."  
  s.homepage     = "https://stitch.mongodb.com"
  s.license      = {
  						:type => "MIT",
  						:file => "LICENSE.md"
  				   }
  s.authors      = "MongoDB"  
  s.platform     = :ios, "9.0"
  s.source       = { 
  						:git => "https://git.zemingo.com/MongoBaaS/mongo-baas-core-ios.git",
  						:tag => "#{s.version}"
  				   }
  s.source_files  = "MongoBaasODM/Sources/**/*.swift"
  s.requires_arc = true
  s.dependency "MongoBaasSDKLogger", "~> 0.0.1"
  s.dependency "MongoExtendedJson", "~> 0.0.1"
  s.dependency "MongoCore", "~> 0.0.1"
  s.dependency "MongoDB", "~> 0.0.1"
end
