Pod::Spec.new do |spec|
  spec.name         = "DWH"
  spec.version      = "1.7"

  spec.summary      = "DWH Framework data warehouse"
  spec.description  = <<-DESC
                    DWH Framwork use for data warehouse
                   DESC
  spec.homepage     = "http://www.holla.world/"
  spec.license      = { :type => "Copyright", :text => "Copyright 2018 holla.world. All rights reserved.\n" }
  spec.author       = { "毛鹏霖" => "maoepnglin@holla.world" }
  spec.source       = { :git => "https://github.com/holla-world/DWH.git", :tag => spec.version.to_s }

  spec.source_files    = 'DWH/**/*.{h,m}'
  spec.public_header_files = 'DWH/DWH.h', 'DWH/SDK/DWHSDK.h'

  spec.library         = "sqlite3"
  spec.frameworks       = "Foundation", "AdSupport"
  spec.requires_arc    = true
  spec.ios.deployment_target = "8.0"

  spec.dependency "UICKeyChainStore"
end
