Pod::Spec.new do |s|  
  s.name         = "StitchLogger"
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
  						 :git => "https://github.com/10gen/stitch-ios-sdk.git",
					     :tag => "#{s.version}"
					}
  s.source_files  = "StitchLogger/StitchLogger/**/*.swift"
end
