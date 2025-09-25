# TempTalk iOS

TempTalk iOS is a modern instant messaging application built with iOS native development, using Swift and Objective-C, designed for secure office team communication.

<a href="https://www.temptalk.app/" target="_blank"><img src="https://github.com/user-attachments/assets/a6005000-9f4a-4a68-a7d0-90e5c7cbb76d" width="16" height="16" alt="TempTalk Logo" /></a> **Official Website**: [https://www.temptalk.app/](https://www.temptalk.app/)

## Features

- **Instant Messaging**: Support for text, voice, images, videos and other message types
- **Voice & Video Calls**: High-quality audio and video calling functionality with LiveKit SDK
- **Group Chats**: Create and manage group conversations with advanced features
- **End-to-End Encryption**: Self-developed E2EE solution providing forward secrecy, device local key management, offline message secure transmission and message integrity protection
- **Cross-Platform**: Native iOS application with modern UI
- **File Sharing**: Share documents, images, and other files securely
- **Push Notifications**: Real-time message notifications
- **Multi-language Support**: Internationalization for global teams

## Architecture

### Core Technology Stack
- **Programming Language**: Swift 5.0+ / Objective-C
- **UI Framework**: UIKit combined with modern SwiftUI components
- **Architecture Pattern**: MVVM + Repository Pattern
- **Dependency Management**: CocoaPods
- **Networking Layer**: URLSession + custom networking layer
- **Database**: SQLite with SQLCipher encryption
- **Media Processing**: AVFoundation, WebRTC for calls
- **Image Processing**: Custom image handling and YYImage

### Project Structure
```
TempTalk-iOS/
├── TempTalk/                 # Main application target
├── TTMessaging/             # Messaging module
├── TTServiceKit/            # Service layer and business logic
├── TTShareExtension/        # Share extension
├── NSE/                     # Notification service extension
├── DTProto/                 # Protocol definitions and FFI
├── Pods/                    # CocoaPods dependencies
├── Scripts/                 # Build and utility scripts
├── fastlane/                # Fastlane automation scripts
├── protobuf/                # Protocol buffer definitions
└── Modules/                 # Custom modules (FTS5SimpleTokenizer)
```

## Requirements

- iOS 14.0+
- Xcode 14.0+
- CocoaPods

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/TempTalkOrg/TempTalk-iOS.git
   cd TempTalk-iOS
   ```

2. Install dependencies:
   ```bash
   pod install
   ```

3. Open `Difft.xcworkspace` in Xcode

4. Build and run the project

## Building

For detailed build instructions, please refer to [BUILDING.md](BUILDING.md).

This project uses the following open source libraries:

- **Open Source Libraries**:
  - **[Curve25519Kit](https://github.com/WhisperSystems/Curve25519Kit)** - Elliptic curve cryptography
  - **[Signal iOS](https://github.com/signalapp/Signal-iOS)** - Core messaging and encryption components
  - **[Mantle](https://github.com/Mantle/Mantle)** - Model framework for JSON serialization
  - **[PanModal](https://github.com/slackhq/PanModal)** - Bottom sheet modals
  - **[ZLPhotoBrowser](https://github.com/longitachi/ZLPhotoBrowser)** - Photo picker
  - **[JXCategoryView](https://github.com/pujiaxin33/JXCategoryView)** - Category view components
  - **[JXPagingView](https://github.com/pujiaxin33/JXPagingView)** - Paging view components
  - **[YYImage](https://github.com/ibireme/YYImage)** - Image processing and animation

We thank the Signal team and all open source contributors for their excellent work on secure messaging and their contributions to the open source community.

## License

This project is licensed under the GNU Affero General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions, please:

1. Check the [Building Guide](BUILDING.md) for common issues
2. Search [Issues](https://github.com/TempTalkOrg/TempTalk-iOS/issues)
3. Create a new Issue
4. Contact the development team: opensource@temptalk.app

## Links

- [Official Website](https://www.temptalk.app/) - TempTalk official website
- [Project Homepage](https://github.com/TempTalkOrg/TempTalk-iOS)

---

**TempTalk iOS** - Making communication simpler and connections more secure.