Pod::Spec.new do |s|  
  s.name         = "MongoBaasSDKLogger"
  s.version      = "0.0.1"
  s.authors		 = "MongoDB"
  s.homepage     = "www.mongodb.com"
  s.summary      = "A small logging library."
  #s.license      = "MIT"
  s.platform     = :ios, "9.0"
  s.requires_arc = true
  # s.source = { :git => '/Users/ofer/Documents/Dev/mongo-baas-core-ios', :commit => '072e819cb534e8c4b45d563141904be79246a18c' }
  s.source       = { 
  						 :git => 'https://git.zemingo.com/MongoBaaS/mongo-baas-core-ios.git',
					     #:tag => '#{s.version}',
						 :branch => 'feature/cocoapods',
						 :commit => '072e819cb534e8c4b45d563141904be79246a18c'
					}
  s.source_files  = "MongoBaasSDKLogger/MongoBaasSDKLogger/**/*.swift"
end
