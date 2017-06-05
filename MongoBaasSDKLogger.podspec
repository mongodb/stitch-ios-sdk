Pod::Spec.new do |s|  
  s.name         = "MongoBaasSDKLogger"
  s.version      = "0.0.1"
  s.authors		 = "MongoDB"
  s.homepage     = "https://stitch.mongodb.com"
  s.summary      = "A small logging library."
  s.license      = {
  						:type => "MIT",
  						:file => "LICENSE.md"
  				   }
  s.platform     = :ios, "9.0"
  s.requires_arc = true
  s.source       = { 
  						 :git => "https://git.zemingo.com/MongoBaaS/mongo-baas-core-ios.git",
					     :tag => "#{s.version}"
					}
  s.source_files  = "MongoBaasSDKLogger/MongoBaasSDKLogger/**/*.swift"
end
