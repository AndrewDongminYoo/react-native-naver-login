# Changelog

All notable changes to this project will be documented in this file.

See [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) for the format,
and [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for versioning.

## [Unreleased]

## [0.1.5] - 2026-07-09

### Added

- `NaverLogin.refreshToken()`: reissues the access token using the SDK-stored refresh token, resolving with the same `NaverLoginResponse` shape as `login()` (never rejects — an expired refresh token resolves as `{ isSuccess: false }`). Backed by `requestAccessTokenWithRefreshToken` (iOS) and `NidOAuthLogin().callRefreshAccessTokenApi` (Android). This method is additive beyond the `@react-native-seoul/naver-login` API surface.

### Changed

- **Package renamed** from `@dongminyu/react-native-naver-login` to `react-native-naver-login-turbo` (personal scope dropped for an unscoped name). The exact unscoped `react-native-naver-login` is taken by an unrelated legacy package, so the `-turbo` suffix both frees the name and signals the New-Architecture (TurboModule) differentiator. Update your import path and dependency to `react-native-naver-login-turbo`.

### Fixed

- iOS `login()` and `refreshToken()` now preserve the never-reject contract for in-progress calls by resolving `{ isSuccess: false }` instead of rejecting with `*_IN_PROGRESS`.
- Corrected the Android Manifest troubleshooting text: the current library manifest is empty, so host apps must declare `OAuthLoginActivity` exactly once.
- Removed absent `cpp` and `react-native.config.js` entries from the npm package `files` list.

### Docs

- Added iOS troubleshooting guidance for stale `ios/.xcode.env.local` `NODE_BINARY` paths causing missing `ReactCodegen` generated-file build failures.
- Corrected the `getAgreement` migration note in `README.md`, `README.ko.md`, and the design spec. It was incorrectly labelled "Naver API deprecated"; the endpoint (`/v1/nid/agreement`) is still live and documented and upstream still ships it. It is deliberately not ported because it is a niche "약관 동의 대행" REST-only feature that callers can hit directly with their own API client — not because of any deprecation.

## [0.1.4] - 2026-07-02

### Fixed

- Corrected the GitHub repository URL in `NaverLogin.podspec` so CocoaPods and the npm "repository" link resolve to the right project.
- Corrected the author's GitHub username (`AndrewDongminYuu` → `AndrewDongminYoo`) in `README.md`, `README.ko.md`, and the TurboModule implementation plan.

### Changed

- Replaced `release-it` with the skill-based release workflow.
- Bumped Trunk plugin versions and pinned linter tool dependencies.

## [0.1.3] - 2026-05-14

### Added

- `NaverProfileData.ci` (optional `string | null`): exposes the Connecting Information returned by Naver's `/v1/nid/me` endpoint when the Naver application has business-info registration and the CI scope is granted. Native code already passes the field through; this release types it on the JS side so callers can read `profile.response.ci` without a cast.

## [0.1.2] - 2026-05-12

### Fixed

- Android `deleteToken()` failed to compile against `com.navercorp.nid:oauth` 5.x because `callDeleteTokenApi` was called on `NaverIdLoginSDK` with a `Context` argument. In SDK 5.x the method lives on `NidOAuthLogin` and takes only the callback; switched to `NidOAuthLogin().callDeleteTokenApi(callback)`.

### Changed

- Replaced the deprecated `currentActivity` synthetic property access in `NaverLoginModule.kt` with the explicit `reactApplicationContext.getCurrentActivity()` call recommended in React Native 0.80+.

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

[Unreleased]: https://github.com/AndrewDongminYoo/react-native-naver-login/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/AndrewDongminYoo/react-native-naver-login/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/AndrewDongminYoo/react-native-naver-login/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/AndrewDongminYoo/react-native-naver-login/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/AndrewDongminYoo/react-native-naver-login/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/AndrewDongminYoo/react-native-naver-login/releases/tag/v0.1.0
