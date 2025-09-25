#
# Be sure to run `pod lib lint TTServiceKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "TTServiceKit"
  s.version          = "0.9.0"
  s.summary          = "An Objective-C library for communicating with the Signal messaging service."

  s.description      = <<-DESC
An Objective-C library for communicating with the Signal messaging service.
  DESC

  s.homepage         = "https://github.com/signalapp/TTServiceKit"
  s.license          = 'GPLv3'
  s.author           = { "Frederic Jacobs" => "github@fredericjacobs.com" }
  s.source           = { :git => "https://github.com/signalapp/TTServiceKit.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/FredericJacobs'

  s.platform     = :ios, '13.0'
  s.requires_arc = true
  s.source_files = 'TTServiceKit/src/**/*.{h,m,mm,swift}'
  s.private_header_files = "TTServiceKit/src/EncryptedMessage/DTMessageParams.h"

  # We want to use modules to avoid clobbering CocoaLumberjack macros defined
  # by other OWS modules which *also* import CocoaLumberjack. But because we
  # also use Objective-C++, modules are disabled unless we explicitly enable
  # them
  s.compiler_flags = "-fcxx-modules"

  s.prefix_header_file = 'TTServiceKit/src/TSPrefix.h'
  s.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC' }

  s.resources = ["TTServiceKit/Resources/**/*"]

  s.dependency 'Curve25519Kit'
  s.dependency 'CocoaLumberjack'
  s.dependency 'AFNetworking/NSURLSession'
  s.dependency 'HKDFKit'
  s.dependency 'Mantle'
  s.dependency 'SocketRocket'
#  s.dependency 'GRKOpenSSLFramework'
  s.dependency 'OpenSSL-Universal'
  s.dependency 'SAMKeychain'
  s.dependency 'TwistedOakCollapsingFutures'
  s.dependency 'Reachability'
  s.dependency 'SignalCoreKit'
  s.dependency 'GRDB.swift/SQLCipher'
  s.dependency 'SVProgressHUD'
  s.dependency 'SwiftProtobuf'
  s.dependency 'YYImage'
  s.dependency 'libwebp'
  s.dependency 'libPhoneNumber-iOS'
  s.dependency 'DTProto'
  s.dependency 'lottie-ios'

end
