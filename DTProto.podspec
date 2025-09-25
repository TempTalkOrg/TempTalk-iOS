

Pod::Spec.new do |s|

  PROTOVERSION = "0.5.1"
  
  s.name             = "DTProto"
  s.version          = "#{PROTOVERSION}"
  s.summary          = "message protocol"

  s.description      = <<-DESC
message protocol.
  DESC

  s.homepage         = "https://difft.org"
  s.license          = 'GPLv3'
  s.author           = { "Kris" => "kris@difft.org" }
  s.source           = { :git => "https://difft.org", :tag => s.version.to_s }

  s.platform     = :ios, '10.0'
  #s.ios.deployment_target = '9.0'
  #s.osx.deployment_target = '10.9'
  s.requires_arc = true
  s.source_files = 'DTProto/*.swift'

#  s.ios.vendored_library = 'DTProto/*.a'
  
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/DTProto/dtprotoFFI',
    'SWIFT_INCLUDE_PATHS' => '$(HEADER_SEARCH_PATHS)',
    'DTPROTOTARGETLIB' => "libdtproto_ffi_#{PROTOVERSION}",
    'DTPROTOLIBROOT' => '${PODS_TARGET_SRCROOT}/DTProto/libdtproto_ffi',
    'DTPROTO_FFI_LIB_TO_LINK' => '${DTPROTOLIBROOT}/${DTPROTOTARGETLIB}/${PLATFORM_NAME}/libdtproto_ffi.a',
    'OTHER_LDFLAGS' => '$(DTPROTO_FFI_LIB_TO_LINK)'
  }
  
  s.script_phases = [
      { name: 'Download and cache libdtproto_ffi',
        execution_position: :before_compile,
        script: %q(
           set -euo pipefail
           DTPROTOTARGETLIBZIP="${DTPROTOTARGETLIB}.zip"
           if [ -e "${DTPROTOLIBROOT}/${DTPROTOTARGETLIB}/${PLATFORM_NAME}/libdtproto_ffi.a" ]; then
             # exists
             exit 0
           fi
                   
           mkdir -p "${DTPROTOLIBROOT}"
           cd "${DTPROTOLIBROOT}"
                   
           curl -O "https://difft-proto-binary.s3.ap-southeast-1.amazonaws.com/${DTPROTOTARGETLIBZIP}"

           if [ -e "${DTPROTOTARGETLIBZIP}" ]; then
             unzip "${DTPROTOTARGETLIBZIP}"  -x '__MACOSX/*'
           fi
           if [ -e "${DTPROTOTARGETLIBZIP}" ]; then
             rm "${DTPROTOTARGETLIBZIP}"
           fi
        )
      }
  ]
  
  
end
