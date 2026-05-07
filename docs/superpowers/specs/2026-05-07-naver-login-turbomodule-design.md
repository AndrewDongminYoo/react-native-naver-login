# Naver Login TurboModule — Design Spec

**Date:** 2026-05-07
**Status:** Approved

## Goal

Replace the `multiply` scaffold placeholder with a complete Naver OAuth 2.0 authentication TurboModule. The public API matches `@react-native-seoul/naver-login` (minus `getAgreement`, which is deprecated) to allow drop-in migration.

## Scope

**In scope:**

- `initialize`, `login`, `logout`, `deleteToken`, `getProfile` (5 methods)
- Real SDK integration: iOS `naveridlogin-sdk-ios` CocoaPod + Android `com.navercorp.nid:oauth`
- iOS URL handling via `RCTOpenURLNotification` (no AppDelegate modification required)

**Out of scope:**

- `getAgreement` (deprecated upstream)
- Web implementation (throws not-supported error)
- React Navigation / deep-link wiring (host app responsibility)

## Public API

```typescript
// NaverLoginInitParams
consumerKey: string
consumerSecret: string
appName: string
disableNaverAppAuthIOS?: boolean   // default: false
serviceUrlSchemeIOS?: string

// NaverLoginResponse
isSuccess: boolean
successResponse?: { accessToken, refreshToken, expiresAtUnixSecondString, tokenType }
failureResponse?: { message, isCancel, lastErrorCodeFromNaverSDK?, lastErrorDescriptionFromNaverSDK? }

// GetProfileResponse
resultcode: string
message: string
response: { id, profile_image|null, email, name, birthday|null, age|null,
            birthyear|null, gender|null, mobile|null, mobile_e164|null, nickname|null }

NaverLogin.initialize(params): void
NaverLogin.login(): Promise<NaverLoginResponse>
NaverLogin.logout(): Promise<void>
NaverLogin.deleteToken(): Promise<void>
NaverLogin.getProfile(accessToken: string): Promise<GetProfileResponse>
```

## Architecture

### Data Flow

```
JS call
  └─ NaverLogin.native.tsx  (type-safe wrapper)
       └─ NativeNaverLogin  (TurboModule bridge, codegen-generated)
            ├─ iOS: NaverLogin.mm  ──► NaverThirdPartyLoginConnection
            └─ Android: NaverLoginModule.kt ──► OAuthLoginApi (Naver SDK 5.x)
```

### Codegen Spec (`src/NativeNaverLogin.ts`)

Declares all 5 methods with codegen-compatible types. Object types defined inline (codegen in RN 0.85 supports named object types). Promise-returning methods use `Promise<T>` return type — codegen maps these to native `resolve`/`reject` callbacks.

### JS Layer

| File                        | Role                                                                   |
| --------------------------- | ---------------------------------------------------------------------- |
| `src/NativeNaverLogin.ts`   | TurboModule codegen spec (types + method signatures)                   |
| `src/NaverLogin.native.tsx` | Wraps native module, applies proper TS types, exported as `NaverLogin` |
| `src/NaverLogin.tsx`        | Web stub — throws `Error('NaverLogin is not supported on web')`        |
| `src/index.tsx`             | Re-exports `NaverLogin` (default) + all type interfaces                |

Files removed: `src/multiply.tsx`, `src/multiply.native.tsx`

### iOS Layer

**`NaverLogin.podspec`:** Adds `s.dependency 'naveridlogin-sdk-ios'`

**`ios/NaverLogin.mm`:**

- `initialize`: Configures `NaverThirdPartyLoginConnection.sharedInstance` (consumerKey, consumerSecret, appName, serviceUrlScheme). Registers `RCTOpenURLNotification` observer to handle the Naver app callback URL internally — no AppDelegate change required in the host app.
- `login`: Calls `requestThirdPartyLogin` on the shared instance. Implements `NaverThirdPartyLoginConnectionDelegate` to resolve/reject the Promise.
- `logout`: Calls `requestDeleteToken` (clears token from keychain but keeps the session).
- `deleteToken`: Calls `requestDeleteToken` + `requestUnlink`.
- `getProfile`: HTTP GET `https://openapi.naver.com/v1/nid/me` with `Authorization: Bearer <accessToken>`.

**Delegate pattern for login:** The module implements `NaverThirdPartyLoginConnectionDelegate` and stores a single pending Promise resolver. On `oauth20ConnectionDidFinishRequestACTokenWithAuthCode:` → resolve. On `oauth20Connection:didFailWithRequestType:` → resolve with `isSuccess: false` (not reject — matches upstream behavior). Only one concurrent `login` call is supported; a second call while one is pending rejects immediately.

### Android Layer

**`android/build.gradle`:** Adds `implementation 'com.navercorp.nid:oauth:5.10.0'`

**`android/src/main/java/com/naverlogin/NaverLoginModule.kt`:**

- `initialize`: Calls `OAuthLoginApi.initialize(context, clientId, clientSecret, clientName)`. Stores params for reuse.
- `login`: Calls `OAuthLoginApi.oauthApiClient.authorize(currentActivity, OAuthLoginCallback)`. `OAuthLoginCallback` resolves/rejects the Promise on main thread.
- `logout`: Calls `OAuthLoginApi.oauthApiClient.logout(context)`.
- `deleteToken`: Calls `OAuthLoginApi.oauthApiClient.logout(context)` then `OAuthLoginApi.oauthApiClient.revoke(context, accessToken, callback)`.
- `getProfile`: HTTP GET `https://openapi.naver.com/v1/nid/me` with `Authorization: Bearer <accessToken>` (same as iOS, for cross-platform consistency).

## Error Handling

- `login` never rejects — errors are returned as `{ isSuccess: false, failureResponse: { message, isCancel } }`.
- `getProfile` rejects if the HTTP call fails or the token is invalid.
- `logout` / `deleteToken` resolve on success, reject on network failure.
- Android `lastErrorCodeFromNaverSDK` / `lastErrorDescriptionFromNaverSDK` are populated from `OAuthLoginApi.getLastErrorCode()` / `getLastErrorDesc()`.

## Files Changed

```
src/NativeNaverLogin.ts          modified (spec replacement)
src/NaverLogin.native.tsx        new
src/NaverLogin.tsx               new
src/index.tsx                    modified
src/multiply.tsx                 deleted
src/multiply.native.tsx          deleted
src/__tests__/index.test.tsx     modified (stub test → real smoke test)
ios/NaverLogin.h                 modified
ios/NaverLogin.mm                modified
NaverLogin.podspec               modified (add SDK dependency)
android/build.gradle             modified (add SDK dependency)
android/.../NaverLoginModule.kt  modified (full implementation)
example/src/App.tsx              modified (demo Naver login flow)
```
