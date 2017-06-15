# coding: utf-8
Pod::Spec.new do |s|

  s.name         = "StitchGCM"
  s.version      = "0.0.1"
  s.summary      = "A helper library to easily have Google Cloud Messaging running on your application"
  s.license      = {
                                                :type => "Apache 2",
                                                :file => "./LICENSE"
                                   }
  s.platform     = :ios, "9.0"
  s.authors              = "MongoDB"
  s.homepage     = "https://stitch.mongodb.com"
  s.source       = {
                                                :git => "https://github.com/10gen/stitch-ios-sdk.git",
                                                :tag => "#{s.version}"
  }
  
  
  s.source_files  = "StitchGCM/StitchGCM/**/*.{h,m}"
  s.public_header_files = "StitchGCM/StitchGCM/*.h"
  s.requires_arc = true

  s.frameworks = 'SafariServices'
  s.pod_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/GoogleCloudMessaging',
    'OTHER_LDFLAGS' => '$(inherited) -undefined dynamic_lookup'
  }
  s.dependency "Google/CloudMessaging"

  #s.dependency "Google/CloudMessaging"
  #s.dependency "Google/AdMob"

end
