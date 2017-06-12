Pod::Spec.new do |s|
  s.name         = "StitchCore"
  s.version      = "0.0.1"
  s.authors		 = "MongoDB"
  s.homepage     = "https://stitch.mongodb.com"
  s.summary      = "An SDK to use MongoDB's Baas Core features."
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
  s.source_files  = "StitchCore/StitchCore/**/*.swift"
  s.exclude_files = "StitchCore/StitchCore/Frameworks/Alamofire/**/*"
  s.requires_arc = true
  s.dependency "StitchLogger", "~> 0.0.1"
  s.dependency "ExtendedJson", "~> 0.0.1"
  s.dependency "Alamofire", "~> 4.3.0"
end
