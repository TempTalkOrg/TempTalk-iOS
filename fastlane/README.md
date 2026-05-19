# Fastlane Setup Guide

This directory contains template fastlane configuration files. You need to set up your own fastlane configuration based on your project requirements.

## Quick Start

1. **Install fastlane** (if not already installed):
   ```bash
   # Using Homebrew
   brew install fastlane
   
   # Or using RubyGems
   sudo gem install fastlane -NV
   
   # Make sure you have Xcode command line tools
   xcode-select --install
   ```

2. **Set up environment variables**:
   ```bash
   cp .env.example .env
   # Edit .env with your actual values
   ```

3. **Configure your lanes**:
   - Edit `Fastfile` to implement your build, test, and deployment workflows
   - Edit `Matchfile` if you're using fastlane match for code signing
   - Update `Appfile` with your app and team information

## Template Files

- **`Fastfile`**: Main fastlane configuration with template lanes
- **`Matchfile`**: Code signing configuration template  
- **`Appfile`**: Already configured to use environment variables
- **`.env.example`**: Template for environment variables
- **`Scanfile`**: Test configuration (already set up)

## Available Template Actions

### ios build
```sh
[bundle exec] fastlane ios build
```
Build the app (requires implementation)

### ios test
```sh
[bundle exec] fastlane ios test
```
Run tests (requires implementation)

### ios archive
```sh
[bundle exec] fastlane ios archive
```
Create archive for distribution (requires implementation)

### ios upload_dsym
```sh
[bundle exec] fastlane ios upload_dsym
```
Upload debug symbols to crash reporting service (requires implementation)

## Security Notes

- ✅ **DO** use environment variables for sensitive data
- ✅ **DO** add `.env` files to `.gitignore`
- ❌ **DON'T** commit real certificates, API keys, or credentials
- ❌ **DON'T** hardcode sensitive information in fastlane files

## Environment Variables Setup

Create a `.env` file based on `.env.example` with your actual values:

```bash
# Required
SCHEME=YourAppScheme
APP_IDENTIFIER=com.yourcompany.yourapp
TEAM_ID=YOUR_TEAM_ID
APPLE_USERNAME=your.email@example.com

# Optional (depending on your setup)
MATCH_GIT_URL=https://github.com/yourorg/ios-certificates.git
CRASHLYTICS_API_TOKEN=your_token_here
```

## Code Signing with Match

If you're using fastlane match for code signing:

1. Create a private git repository for storing certificates
2. Update `MATCH_GIT_URL` in your `.env` file
3. Run `fastlane match development` to set up development certificates
4. Run `fastlane match appstore` to set up distribution certificates

## Documentation

- [Fastlane Documentation](https://docs.fastlane.tools/)
- [Available Actions](https://docs.fastlane.tools/actions/)
- [Match Documentation](https://docs.fastlane.tools/actions/match/)
- [Gym Documentation](https://docs.fastlane.tools/actions/gym/)
- [Scan Documentation](https://docs.fastlane.tools/actions/scan/)

## Implementation Required

⚠️ **This is a template setup.** You'll need to:
1. Implement the actual build logic in `Fastfile`
2. Configure code signing for your certificates
3. Set up your deployment targets (TestFlight, App Store, etc.)
4. Add any additional tools or services you use

For specific implementation examples, check the fastlane documentation or community examples.
