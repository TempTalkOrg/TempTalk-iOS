# Building

## Prerequisites

### System Requirements
- **macOS** (required for iOS development)
- **Xcode 14.0+** (required for iOS development)
- **Homebrew** (for package management)

### Development Tools
- **Git** (for repository cloning and submodule management)
- **Ruby 3.2.2** (specified in `.ruby-version` file)
- **Bundler 2.3.16** (specified in `Gemfile.lock`)
- **CocoaPods 1.16.2** (specified in `Gemfile`)

## 1. Clone Repository

Clone the repo to a working directory:

```bash
git clone https://github.com/TempTalkOrg/TempTalk-iOS.git
cd TempTalk-iOS
```

## 2. Environment Setup

### 2.1 Verify Ruby Version

Ensure your Ruby version is 3.2.2 (project requirement). If not installed or incorrect version, please install or configure a Ruby version manager yourself.

Verify Ruby version:

```bash
ruby --version
# Should output: ruby 3.2.2
```

### 2.3 Install Bundler

Install the specific bundler version required:

```bash
gem install bundler:2.3.16
```

### 2.4 Set Environment Variables

Set UTF-8 encoding to avoid CocoaPods issues (temporary setting, valid for current session only):

```bash
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
```

## 3. Install Dependencies

[CocoaPods](http://cocoapods.org) is used to manage the dependencies in our static library. Pods are setup easily and are distributed via a ruby gem. Follow the simple instructions on the website to setup.

**Recommended approach** (using bundler):

```bash
bundle install
bundle exec pod install
```

**Important**: Always use `bundle exec pod install` instead of `pod install` to ensure the correct CocoaPods version is used.

**Direct CocoaPods usage** (not recommended):

```bash
pod install
```

If you are having build issues, first make sure your pods are up to date:

```bash
pod repo update
pod install
```

Occasionally, CocoaPods itself will need to be updated:

```bash
gem update cocoapods
pod repo update
pod install
```

## 4. Xcode Configuration

### 4.1 Open Workspace

Open the `Difft.xcworkspace` in Xcode:

```bash
open Difft.xcworkspace
```

## 5. Build and Run

After completing all the above steps:

1. Select your target device or simulator
2. Build the project (⌘+B)
3. Run the project (⌘+R)

Build and Run and you are ready to go!

## Troubleshooting

### Common Issues

#### Ruby Version Issues
If you encounter Ruby version errors:
```bash
# Check current Ruby version
ruby --version

# Ensure you're using the correct version
rbenv local 3.2.2
eval "$(rbenv init -)"
```

#### CocoaPods Issues
If CocoaPods fails with encoding errors:
```bash
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
bundle exec pod install
```

#### Bundle Issues
If bundler version conflicts occur:
```bash
gem install bundler:2.3.16
bundle install
```

## Known Issues

Features related to push notifications are known to be not working for third-party contributors since Apple's Push Notification service pushes will only work with the production code signing certificate.

If you have any other issues, please:

1. Check the [Issues](https://github.com/TempTalkOrg/TempTalk-iOS/issues) page
2. Create a new issue with detailed error information
3. Contact the development team: opensource@temptalk.app