# Unity iOS Build Pipeline with Gitea Actions

This directory contains the necessary configuration files to set up an automated build pipeline for Unity iOS projects using Gitea Actions.

## Prerequisites

1. Unity Project set up for iOS build
2. Apple Developer Account
3. App Store Connect API Key
4. Match repository for code signing
5. macOS runner for Gitea Actions

## Setup Instructions

### 1. Unity Project Configuration

1. Open your Unity project
2. Go to Build Settings (File > Build Settings)
3. Switch platform to iOS
4. Configure Player Settings (Edit > Project Settings > Player):
   - Set your Bundle Identifier
   - Configure signing settings

### 2. Code Signing Setup

1. Set up a private repository for match (code signing)
2. Initialize match:
```bash
fastlane match init
```
3. Generate necessary certificates and profiles:
```bash
fastlane match appstore
```

### 3. Gitea Actions Configuration

Add the following secrets to your repository:

- `APPLE_CONNECT_EMAIL`: Your App Store Connect email
- `APPLE_DEVELOPER_EMAIL`: Your Apple Developer email
- `APPLE_TEAM_ID`: Your Apple Team ID
- `MATCH_REPOSITORY`: URL of your match repository
- `MATCH_DEPLOY_KEY`: SSH deploy key for match repository
- `MATCH_PASSWORD`: Password for match repository
- `APPSTORE_ISSUER_ID`: App Store Connect API Issuer ID
- `APPSTORE_KEY_ID`: App Store Connect API Key ID
- `APPSTORE_P8`: App Store Connect API Private Key
- `IOS_BUNDLE_ID`: Your app's bundle identifier
- `PROJECT_NAME`: Your Unity project name

### 4. Available Workflows

The pipeline includes the following workflows:

1. **Build for iOS**: Builds the Unity project for iOS platform
2. **Release to App Store**: Processes the iOS build and uploads to App Store

### 5. Usage

The workflow can be triggered:
- Automatically on push to main branch
- Manually through Gitea Actions UI

## File Structure

- `build.yml`: Main workflow file
- `fastlane/Fastfile`: Fastlane configuration
- `Gemfile`: Ruby dependencies

## Notes

- The pipeline uses `game-ci/unity-builder` for Unity builds
- iOS builds require a macOS runner
- App Store rate limits apply for uploads
- Make sure your Unity license is properly configured

## References
- [Fastlane Match](https://docs.fastlane.tools/actions/match/)
- [Fastlane Code Signing Xcode settings](https://docs.fastlane.tools/codesigning/xcode-project/)
- [Fastlane App Store Deployment](https://docs.fastlane.tools/getting-started/ios/appstore-deployment/)
- [GameCI iOS Deployment](https://game.ci/docs/github/deployment/ios)
- [Build and Deploy the App to TestFlight using GitHub Actions with Fastlane](https://medium.com/swiftable/build-and-deploy-the-app-to-testflight-using-github-actions-with-fastlane-and-app-distribution-ff1786a8bf72)