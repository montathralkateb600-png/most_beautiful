def flutter_install_all_ios_pods(ios_application_path = nil)
  native_targets = post_install_targets
  native_targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end

def flutter_additional_ios_build_settings(target)
  return unless target.platform_name == :ios
  target.build_configurations.each do |config|
    config.build_settings['ENABLE_BITCODE'] = 'NO'
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
  end
end