Pod::Spec.new do |s|
  s.name         = "StitchCore"
  s.version      = "3.0.1"
  s.authors	 = "MongoDB"
  s.homepage     = "https://mongodb.com/cloud/stitch"
  s.summary      = "An SDK to use MongoDB's Stitch Core features."
  s.license      = {
    :type => "Apache 2",
    :file => "./LICENSE"
  }
  s.platform     = :ios, "9.0"

  s.source       = { 
    :git => "https://github.com/mongodb/stitch-ios-sdk.git",
    :tag => "#{s.version}",
    :submodules => true
  }

  s.source_files  = "StitchCore/StitchCore/**/*.swift"

  s.requires_arc = true

  s.dependency "PromiseKit/CorePromise", "~> 6.1.0"
  s.dependency "StitchLogger", "~> 2.0.0"
  s.dependency "ExtendedJson", "~> 2.0.2"
end
