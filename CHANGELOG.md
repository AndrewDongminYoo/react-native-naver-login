# Changelog

All notable changes to this project will be documented in this file.

See [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) for the format,
and [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for versioning.

## [Unreleased]

## [0.1.1] - 2026-05-08

### Added

- Korean README (`README.ko.md`) covering requirements, setup, full API reference, migration guide, and troubleshooting
- English README updated with badges (npm, license, platform, New Architecture) and a migration guide from `@react-native-seoul/naver-login`
- React Native New Architecture (`RCTNewArchEnabled`, Hermes) and Apple Privacy Manifest (`PrivacyInfo.xcprivacy`) enabled in the example project

### Fixed

- Example iOS `Info.plist` was missing `CFBundleURLSchemes` (only `CFBundleURLName` was set), causing Naver SDK callback URLs to fail with `LSApplicationWorkspace Code=115`; also adds `LSApplicationQueriesSchemes` for `naversearchapp` and `naversearchthirdlogin`
- Example Android `AndroidManifest.xml` was missing `OAuthLoginActivity` registration
- iOS `initialize`: codegen emits `NSString *` for string fields, not `std::string`; replaced `stringWithUTF8String:c_str()` with direct assignment and nil-checked `serviceUrlSchemeIOS`

### Changed

- Package renamed from `react-native-naver-login` to `@dongminyu/react-native-naver-login` (scoped npm package)
- Example URL scheme constant updated to `naverloginexample` in `Info.plist` and `App.tsx`
- CocoaPods version bumped to 1.16.2
- CI workflow simplified: removed redundant per-platform build jobs, added bot guard (dependabot/renovate/github-actions) and a production dependency security-audit job; default permissions set to `read-all`
- Development tool configs extracted to dedicated files (`.prettierrc.mjs`, `.release-it.json`, `bob.config.js`, `jest.config.js`)
- Node.js version updated to `v24.15.0`; added `.npmignore` to trim published package size
- cspell added with a project-specific custom dictionary
- Multiple dependency bumps across the workspace (React Native 0.85.2, TypeScript 6.0.3, Turbo 2.9.8, release-it 20.0.1, and others)

## [0.1.0] - 2026-05-07

### Added

- Initial release: React Native New Architecture (TurboModule / Fabric) Naver OAuth login for iOS and Android
- iOS implementation via `naveridlogin-sdk-ios` CocoaPod
- Android implementation via `com.navercorp.nid:oauth` (Maven)
- `initialize()`, `login()`, `logout()`, `deleteToken()`, and `getProfile()` API — drop-in compatible with `@react-native-seoul/naver-login`
- JavaScript wrapper (`NaverLogin.native.tsx`) and web stub with clear unsupported-platform error
- Unit tests for the JS wrapper (happy-path and all error paths)
- Full Naver Login demo UI in the example app (initialize, login, profile display, logout, token deletion)
- Trunk linter suite (ESLint, ktlint, Prettier, shellcheck, markdownlint, yamllint, actionlint, cspell)
- Design spec and implementation plan under `docs/specs/` and `docs/plans/`

[Unreleased]: https://github.com/AndrewDongminYoo/react-native-naver-login/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/AndrewDongminYoo/react-native-naver-login/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/AndrewDongminYoo/react-native-naver-login/releases/tag/v0.1.0
