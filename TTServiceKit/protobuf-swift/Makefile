# See README.md in this dir for prerequisite setup.

#PROTOC=protoc \
#		--plugin=/usr/local/bin/protoc-gen-objc \
#		--proto_path="${HOME}/src/signal/protobuf-objc/src/compiler/" \
#		--proto_path="${HOME}/src/signal/protobuf-objc/src/compiler/google/protobuf/" \
#		--proto_path='./'
#
#signal_service_proto: OWSSignalServiceProtos.proto
#	$(PROTOC) --objc_out=../src/Messages/ \
#		OWSSignalServiceProtos.proto
#
#provisioning_protos: OWSProvisioningProtos.proto
#	$(PROTOC) --objc_out=../src/Devices/ \
#		OWSProvisioningProtos.proto
#
#fingerprint_protos: OWSFingerprintProtos.proto
#	$(PROTOC) --objc_out=../src/Security/ \
#		OWSFingerprintProtos.proto
#
#websocket_protos: WebSocketResources.proto
#	$(PROTOC) --objc_out=../src/Network/WebSockets/ \
#		WebSocketResources.proto

PROTOC=protoc \
		--proto_path='./'
WRAPPER_SCRIPT=../../Scripts/ProtoWrappers.py \
		--proto-dir='./' --verbose

#all: signal_service_proto provisioning_protos fingerprint_protos websocket_protos

all: difft_service_protos websocket_protos provisioning_protos fingerprint_protos difft_ios_protos e2eemessage_protos

difft_service_protos: DifftService.proto
	$(PROTOC) --swift_out=../src/Protos/Generated \
		DifftService.proto
	$(WRAPPER_SCRIPT) --dst-dir=../src/Protos/Generated \
		--wrapper-prefix=DSKProto --proto-prefix=DifftServiceProtos --proto-file=DifftService.proto

websocket_protos: WebSocketResources.proto
	$(PROTOC) --swift_out=../src/Protos/Generated \
		WebSocketResources.proto
	$(WRAPPER_SCRIPT) --dst-dir=../src/Protos/Generated \
		--wrapper-prefix=WebSocketProto --proto-prefix=WebSocketProtos --proto-file=WebSocketResources.proto

provisioning_protos: Provisioning.proto
	$(PROTOC) --swift_out=../src/Protos/Generated \
		Provisioning.proto
	$(WRAPPER_SCRIPT) --dst-dir=../src/Protos/Generated \
		--wrapper-prefix=ProvisioningProto --proto-prefix=ProvisioningProtos --proto-file=Provisioning.proto

fingerprint_protos: Fingerprint.proto
	$(PROTOC) --swift_out=../src/Protos/Generated \
		Fingerprint.proto
	$(WRAPPER_SCRIPT) --dst-dir=../src/Protos/Generated \
		--wrapper-prefix=FingerprintProto --proto-prefix=FingerprintProtos --proto-file=Fingerprint.proto

difft_ios_protos: DifftIOS.proto
	$(PROTOC) --swift_out=../src/Protos/Generated \
		DifftIOS.proto
	$(WRAPPER_SCRIPT) --dst-dir=../src/Protos/Generated \
		--wrapper-prefix=IOSProto --proto-prefix=IOSProtos --proto-file=DifftIOS.proto

e2eemessage_protos: E2EEMessage.proto
	$(PROTOC) --swift_out=../src/EncryptedMessage \
		E2EEMessage.proto
	$(WRAPPER_SCRIPT) --dst-dir=../src/EncryptedMessage \
		--wrapper-prefix=E2EEMessageProto --proto-prefix=E2EEMessageProtos --proto-file=E2EEMessage.proto
