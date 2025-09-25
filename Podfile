platform :ios, '14.0'

#plugin 'cocoapods-binary'
use_frameworks!

def shared_pods
  
  pod 'TTServiceKit', path: '.'
  pod 'DTProto', path: '.'
  pod 'SignalCoreKit', git: 'https://github.com/signalapp/SignalCoreKit.git' #, :commit =>'1d6e3bd'
  pod 'HKDFKit', git: 'https://github.com/signalapp/HKDFKit.git'
  pod 'Curve25519Kit', git: 'https://github.com/TempTalkOrg/Curve25519Kit', branch: 'temptalk'
  pod 'OpenSSL-Universal', git: 'https://github.com/signalapp/GRKOpenSSLFramework'

  # third party pods
  pod 'AFNetworking/NSURLSession', '4.0.1'
  pod 'JSQMessagesViewController',  git: 'https://github.com/signalapp/JSQMessagesViewController.git', branch: 'mkirk/share-compatible', :inhibit_warnings => true
  pod 'Mantle', git: 'https://github.com/TempTalkOrg/Mantle.git', branch: 'temptalk'
  pod 'PureLayout', '3.1.8', :inhibit_warnings => true
  pod 'Reachability', '3.2', :inhibit_warnings => true
  pod 'SocketRocket', '~> 0.7.0', :inhibit_warnings => true
  pod 'YYImage', git: 'https://github.com/TempTalkOrg/YYImage.git', branch: 'temptalk', :inhibit_warnings => true
  pod 'YYImage/libwebp', git: 'https://github.com/TempTalkOrg/YYImage.git', branch: 'temptalk', :inhibit_warnings => true
  pod 'SDWebImage', '~> 5.0'
  pod 'SVProgressHUD', '2.2.5', :inhibit_warnings => true
  pod 'MJRefresh', '3.7.5'
  
  pod 'GRDB.swift/SQLCipher', '6.20.2'
  pod 'SQLCipher', ">= 4.0.1"
  pod 'SwiftProtobuf', ">= 1.14.0"
  pod 'FTS5SimpleTokenizer', :path => 'Modules/FTS5SimpleTokenizer'
  
  pod 'PanModal', :git => 'https://github.com/TempTalkOrg/PanModal.git', branch: 'temptalk'
  pod 'SnapKit', '5.7.1'
end

def crashlytics_pods
  pod 'FirebaseAnalytics', '~> 10.24.0'
  pod 'FirebaseCrashlytics', '~> 10.24.0'
  pod 'FirebasePerformance', '~> 10.24.0'
end

target 'TempTalk' do
  shared_pods
  crashlytics_pods
  pod 'SSZipArchive', '2.4.2', :inhibit_warnings => true
  pod 'ZLPhotoBrowser', :git => 'https://github.com/TempTalkOrg/ZLPhotoBrowser.git', branch: 'temptalk'
  pod 'JXCategoryView', :git => 'https://github.com/TempTalkOrg/JXCategoryView.git', branch: 'temptalk'
  pod 'JXPagingView/Pager', :git => 'https://github.com/TempTalkOrg/JXPagingView.git', branch: 'temptalk'
  pod 'ZXingObjC', '~> 3.6.4'
  pod 'lottie-ios', '4.5.1'
  pod 'libPhoneNumber-iOS', git: 'https://github.com/signalapp/libPhoneNumber-iOS', branch: 'signal-master'
  pod 'DSF_QRCode', '~> 23.0.0'
  pod 'BlockiesSwift'
  pod 'GoogleMLKit/Translate', '~> 5.0.0'
  pod 'GoogleMLKit/LanguageID', '~> 5.0.0'
  
  target 'TempTalkTests' do
    inherit! :search_paths
  end
end

target 'ShareExtension' do
  shared_pods
end

target 'TTMessaging' do
  shared_pods
end

target 'NSE' do
  shared_pods
end

post_install do |installer|
  # Disable some asserts when building for tests
#  set_building_for_tests_config(installer, 'TTServiceKit')
  enable_extension_support_for_purelayout(installer)
  disable_application_extension_api_only(installer)
  promote_minimum_supported_version(installer)
  configure_testable_build(installer)
  configure_simulator_archs(installer)
  strip_bitcode()
end

def configure_testable_build(installer)
  installer.pods_project.targets.each do |target|
    
    if target.name == 'TTServiceKit'
      target.build_configurations.each do | config |
        flag = config.name.upcase
        config.build_settings['OTHER_SWIFT_FLAGS'] ||= '$(inherited)'
        config.build_settings['OTHER_SWIFT_FLAGS'] << " -D#{flag}"
        #        config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = "$(inherited) #{flag}"
      end
    end
    
    if target.name == 'OAuthSwift'
        # 遍历每个目标的构建配置
        target.build_configurations.each do |config|
          config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'NO'
        end
    end
    
    target.build_configurations.each do |build_configuration|
      next unless ["Debug", "Debug_test", "Release_test"].include?(build_configuration.name)
#      build_configuration.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
      build_configuration.build_settings['OTHER_CFLAGS'] ||= '$(inherited)'
      build_configuration.build_settings['OTHER_CFLAGS'] << ' -DTESTABLE_BUILD'
      
      build_configuration.build_settings['OTHER_SWIFT_FLAGS'] ||= '$(inherited)'
      build_configuration.build_settings['OTHER_SWIFT_FLAGS'] << ' -DTESTABLE_BUILD'
      if target.name.end_with? "PureLayout"
        # Avoid overwriting the PURELAYOUT_APP_EXTENSIONS.
      else
        build_configuration.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= '$(inherited)'
        build_configuration.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << ' TESTABLE_BUILD=1'
      end
      
      if build_configuration.to_s.include?("Debug")
        build_configuration.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= '$(inherited)'
        build_configuration.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << ' DEBUG=1'
        build_configuration.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
        build_configuration.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf'
        build_configuration.build_settings['GCC_OPTIMIZATION_LEVEL'] = '0'
        build_configuration.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
      end
      build_configuration.build_settings['ENABLE_TESTABILITY'] = 'YES'
    end
  end
end

# PureLayout by default makes use of UIApplication, and must be configured to be built for an extension.
def enable_extension_support_for_purelayout(installer)
  installer.pods_project.targets.each do |target|
    if target.name.end_with? "PureLayout"
      target.build_configurations.each do |build_configuration|
        build_configuration.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'NO'
        if build_configuration.build_settings['APPLICATION_EXTENSION_API_ONLY'] == 'YES'
          build_configuration.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] = ['$(inherited)', 'PURELAYOUT_APP_EXTENSIONS=1']
        end
      end
    end
  end
end

def disable_application_extension_api_only(installer)
  installer.pods_project.targets.each do |target|
    if target.name == "SVProgressHUD" or target.name == "TTServiceKit"
      target.build_configurations.each do |config|
        config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'No'
      end
    end
  end
end

# Xcode 13 dropped support for some older iOS versions. We only need them
# to support our project's minimum version, so let's bump each Pod's min
# version to our min to suppress these warnings.
def promote_minimum_supported_version(installer)
  project_min_version = current_target_definition.platform.deployment_target

  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |build_configuration|
      target_version_string = build_configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
      target_version = Version.create(target_version_string)

      if target_version < project_min_version
        build_configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = project_min_version.version
      end
    end
  end
end

# fix build error for FTS5SimpleTokenizer
def configure_simulator_archs(installer)
  installer.pods_project.build_configurations.each do |config|
    config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
  end
end

def strip_bitcode()
  bitcode_strip_path = `xcrun --find bitcode_strip`.chop!
  def strip_bitcode_from_framework(bitcode_strip_path, framework_relative_path)
    framework_path = File.join(Dir.pwd, framework_relative_path)
    command = "#{bitcode_strip_path} #{framework_path} -r -o #{framework_path}"
    puts "Stripping bitcode: #{command}"
    system(command)
  end
  
  framework_paths = [
  "/Pods/OpenSSL-Universal/Frameworks/OpenSSL.xcframework/ios-arm64_armv7/OpenSSL.framework/OpenSSL"
  ]
  
  framework_paths.each do |framework_relative_path|
    strip_bitcode_from_framework(bitcode_strip_path, framework_relative_path)
  end
end
