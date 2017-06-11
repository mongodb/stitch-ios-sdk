Pod::Spec.new do |s|
  s.name         = "MongoDB"
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
  						 :git => "https://git.zemingo.com/MongoBaaS/mongo-baas-core-ios.git",
  						 :tag => "#{s.version}"
  				   }
  s.source_files  = "MongoDB/MongoDB/**/*.swift"
  s.requires_arc = true
  s.dependency "MongoBaasSDKLogger", "~> 0.0.1"
  s.dependency "MongoExtendedJson", "~> 0.0.1"
  s.dependency "MongoCore", "~> 0.0.1"
end
