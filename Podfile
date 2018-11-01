source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
inhibit_all_warnings!
use_frameworks!

abstract_target 'DWHCommon' do
	pod 'UICKeyChainStore'
	target 'DWHSDK' do
	end

	target 'DWH' do
	end
	
	post_install do |installer|
		installer.pods_project.targets.each do |target|
			target.build_configurations.each do |config|
                ##       config.build_settings['ENABLE_BITCODE'] = 'NO'
			  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '8.0'
			end
		end
	end

end
