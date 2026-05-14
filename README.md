# @dongminyu/react-native-naver-login

[![npm version](https://img.shields.io/npm/v/@dongminyu/react-native-naver-login)](https://www.npmjs.com/package/@dongminyu/react-native-naver-login)
[![license](https://img.shields.io/npm/l/@dongminyu/react-native-naver-login)](./LICENSE)
[![platform - ios](https://img.shields.io/badge/platform-iOS%2015.1%2B-blue?logo=apple)](https://developer.apple.com)
[![platform - android](https://img.shields.io/badge/platform-Android%2024%2B-green?logo=android)](https://developer.android.com)
[![new architecture](https://img.shields.io/badge/New%20Architecture-TurboModule-orange)](https://reactnative.dev/docs/the-new-architecture/landing-page)

**React Native New Architecture (TurboModule)** library for Naver OAuth 2.0 login on iOS and Android.

Designed to be API-compatible with [`@react-native-seoul/naver-login`](https://github.com/crossplatformkorea/react-native-naver-login), so it can serve as a drop-in replacement in existing projects.

> **New Architecture only.** This library does not support the legacy Bridge (Old Architecture).

**[한국어 문서 (Korean README)](./README.ko.md)**

---

## Table of Contents

- [Requirements](#requirements)
- [Naver Developer Console Setup](#naver-developer-console-setup)
- [Installation](#installation)
- [iOS Setup](#ios-setup)
- [Android Setup](#android-setup)
- [Usage](#usage)
- [API Reference](#api-reference)
- [Behavior Notes](#behavior-notes)
- [Running the Example App](#running-the-example-app)
- [Migrating from @react-native-seoul/naver-login](#migrating-from-react-native-seoulnaver-login)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Requirements

| Item                  | Minimum version                   |
| --------------------- | --------------------------------- |
| React Native          | 0.76+ (New Architecture required) |
| iOS                   | 15.1+                             |
| Android               | API 24 (Android 7.0)+             |
| Xcode                 | 15+                               |
| Android Gradle Plugin | 8.x+                              |

---

## Naver Developer Console Setup

Before using this library, register your application at the [Naver Developer Console](https://developers.naver.com/apps/#/register).

1. **Register an application** → Select **Naver Login** as the API to use.
2. Configure the login service environment:
   - **iOS**: Enter your iOS Bundle ID (e.g., `com.example.myapp`)
   - **Android**: Enter your Android package name (e.g., `com.example.myapp`)
3. After registration, note your **Client ID** (`consumerKey`) and **Client Secret** (`consumerSecret`).
4. For iOS, decide on a **URL Scheme** for the OAuth callback (e.g., `naverlogin.myapp`).

---

## Installation

```sh
npm install @dongminyu/react-native-naver-login
# or
yarn add @dongminyu/react-native-naver-login
```

### iOS

```sh
cd ios && pod install
```

The podspec automatically pulls in `naveridlogin-sdk-ios` via CocoaPods. No manual SDK download or framework setup is needed.

### Android

`com.navercorp.nid:oauth:5.10.0` is automatically added from Maven Central via `android/build.gradle`. No additional steps required.

---

## iOS Setup

### Info.plist — Register URL Scheme

Register a URL Scheme so your app can receive the OAuth callback from the Naver app.

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>YOUR_URL_SCHEME</string>
    </array>
  </dict>
</array>
```

### Info.plist — Naver App Allowlist

Allow the system to query whether the Naver app is installed.

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>naversearchapp</string>
  <string>naversearchthirdlogin</string>
</array>
```

### No AppDelegate Changes Needed

This library subscribes to `RCTOpenURLNotification` internally to handle the OAuth callback URL. **You do not need to add an `openURL:` handler to your `AppDelegate`.**

---

## Android Setup

### AndroidManifest.xml

Register the Naver login activity.

```xml
<application ...>
  <activity
    android:name="com.navercorp.nid.oauth.OAuthLoginActivity"
    android:theme="@android:style/Theme.Translucent.NoTitleBar" />
</application>
```

### ProGuard

If you use ProGuard, add the following rule.

```plaintext
-keep class com.navercorp.nid.** { *; }
```

---

## Usage

### Initialize

Call this once at app startup, typically inside `useEffect` in your root component.

```typescript
import NaverLogin from '@dongminyu/react-native-naver-login';

NaverLogin.initialize({
  consumerKey: 'YOUR_CLIENT_ID',
  consumerSecret: 'YOUR_CLIENT_SECRET',
  appName: 'MyApp',
  serviceUrlSchemeIOS: 'YOUR_URL_SCHEME', // iOS only
  disableNaverAppAuthIOS: false, // iOS only, default false
});
```

### Login

```typescript
const result = await NaverLogin.login();

if (result.isSuccess && result.successResponse) {
  const { accessToken, refreshToken, tokenType, expiresAtUnixSecondString } =
    result.successResponse;
  console.log('Login succeeded:', accessToken);
} else if (result.failureResponse?.isCancel) {
  console.log('User cancelled login.');
} else {
  console.log('Login failed:', result.failureResponse?.message);
}
```

> **Important:** `login()` never rejects. Both errors and cancellations resolve as `{ isSuccess: false, failureResponse: { ... } }`. Check `result.isSuccess` — do not use `try/catch` to detect failure.

### Get Profile

```typescript
const profile = await NaverLogin.getProfile(accessToken);

const {
  id,
  name,
  email,
  nickname,
  profile_image,
  birthday,
  birthyear,
  mobile,
  gender,
} = profile.response;
```

### Logout (local token removal only)

Removes the locally stored token without revoking it on the server.

```typescript
await NaverLogin.logout();
```

### Unlink (server revocation + local removal)

Sends a revocation request to the Naver server and then removes the local token. This fully severs the connection between your app and the user's Naver account.

```typescript
try {
  await NaverLogin.deleteToken();
} catch (e) {
  console.error('Unlink failed:', e);
}
```

### Full Example

```typescript
import { useEffect, useState } from 'react';
import { Button, Text, View } from 'react-native';
import NaverLogin, {
  type NaverLoginSuccessResponse,
} from '@dongminyu/react-native-naver-login';

export default function LoginScreen() {
  const [token, setToken] = useState<NaverLoginSuccessResponse | null>(null);

  useEffect(() => {
    NaverLogin.initialize({
      consumerKey: 'YOUR_CLIENT_ID',
      consumerSecret: 'YOUR_CLIENT_SECRET',
      appName: 'MyApp',
      serviceUrlSchemeIOS: 'YOUR_URL_SCHEME',
    });
  }, []);

  const handleLogin = async () => {
    const result = await NaverLogin.login();
    if (result.isSuccess && result.successResponse) {
      setToken(result.successResponse);
    }
  };

  const handleLogout = async () => {
    await NaverLogin.logout();
    setToken(null);
  };

  return (
    <View>
      {token ? (
        <>
          <Text>{token.accessToken}</Text>
          <Button title="Logout" onPress={handleLogout} />
        </>
      ) : (
        <Button title="Login with Naver" onPress={handleLogin} />
      )}
    </View>
  );
}
```

---

## API Reference

### `NaverLogin.initialize(params)`

| Parameter                | Type      | Required     | Description                                       |
| ------------------------ | --------- | ------------ | ------------------------------------------------- |
| `consumerKey`            | `string`  | ✓            | Client ID from Naver Developer Console            |
| `consumerSecret`         | `string`  | ✓            | Client Secret from Naver Developer Console        |
| `appName`                | `string`  | ✓            | App name displayed on the login screen            |
| `serviceUrlSchemeIOS`    | `string`  | iOS required | URL Scheme for the iOS OAuth callback             |
| `disableNaverAppAuthIOS` | `boolean` | —            | Disable native Naver app login (default: `false`) |

Returns: `void` (synchronous)

---

### `NaverLogin.login()`

Returns: `Promise<NaverLoginResponse>` — **never rejects.**

```typescript
type NaverLoginResponse = {
  isSuccess: boolean;
  successResponse?: NaverLoginSuccessResponse;
  failureResponse?: NaverLoginFailureResponse;
};

type NaverLoginSuccessResponse = {
  accessToken: string;
  refreshToken: string;
  expiresAtUnixSecondString: string; // Unix timestamp in seconds, as a string
  tokenType: string; // typically "Bearer"
};

type NaverLoginFailureResponse = {
  message: string;
  isCancel: boolean;
  lastErrorCodeFromNaverSDK?: string; // Android only
  lastErrorDescriptionFromNaverSDK?: string; // Android only
};
```

---

### `NaverLogin.logout()`

Returns: `Promise<void>` — can reject if the native layer throws.

Removes the locally cached token. The token remains valid on the server.

---

### `NaverLogin.deleteToken()`

Returns: `Promise<void>` — rejects if the server request fails.

Sends a revocation request to Naver's server, then removes the local token. Unlike `logout()`, this can reject on network failure.

---

### `NaverLogin.getProfile(accessToken)`

| Parameter     | Type     | Description                       |
| ------------- | -------- | --------------------------------- |
| `accessToken` | `string` | Access token obtained after login |

Returns: `Promise<GetProfileResponse>` — rejects on HTTP or network errors.

```typescript
type GetProfileResponse = {
  resultcode: string; // "00" = success
  message: string; // "success"
  response: NaverProfileData;
};

type NaverProfileData = {
  id: string;
  email: string;
  name: string;
  profile_image: string | null;
  nickname: string | null;
  birthday: string | null; // "MM-DD" format
  birthyear: number | null;
  age: string | null; // e.g. "20-29"
  gender: string | null; // "M" | "F" | "U"
  mobile: string | null;
  mobile_e164: string | null;
  ci?: string | null; // CI (Connecting Information); only present if the Naver app has business-info + CI scope
};
```

---

## Behavior Notes

### `login()` never rejects

All failure cases — errors, cancellations, network issues — resolve as `{ isSuccess: false, failureResponse: {...} }`. A `try/catch` block will never catch a login failure.

```typescript
// ✅ Correct
const result = await NaverLogin.login();
if (!result.isSuccess) {
  const { isCancel, message } = result.failureResponse!;
}

// ❌ Wrong — catch is never called
try {
  const result = await NaverLogin.login();
} catch (e) {
  // unreachable
}
```

### Concurrent login protection

On both iOS and Android, if a second `login()` call arrives while one is already in progress, it immediately resolves as `{ isSuccess: false }`. Wait for the current login to finish before issuing a new one.

### `logout` vs `deleteToken`

|                      | `logout()`      | `deleteToken()`     |
| -------------------- | --------------- | ------------------- |
| Removes local token  | ✓               | ✓                   |
| Revokes server token | ✗               | ✓                   |
| Requires network     | ✗               | ✓                   |
| Can reject           | ✓               | ✓                   |
| Use case             | Simple sign-out | Full account unlink |

### No AppDelegate changes needed (iOS)

When `initialize()` is called, the library subscribes to `RCTOpenURLNotification` to automatically process the return URL from the Naver app. **If you previously added an `openURL:` handler in your AppDelegate for Naver, remove it** to avoid conflicts.

### Naver app not installed (iOS)

When `disableNaverAppAuthIOS` is `false` (default), the library attempts native app login if the Naver app is installed. If it is not installed, it automatically falls back to an in-app WebView login.

### Parsing `expiresAtUnixSecondString`

```typescript
const expiresAt = new Date(parseInt(expiresAtUnixSecondString, 10) * 1000);
```

---

## Running the Example App

The `example/` directory contains a working sample app. Complete the checklist below before running it.

### Checklist

#### Step 1: Register your app at the Naver Developer Console

Register an application at [developers.naver.com](https://developers.naver.com/apps/#/register).

| Field                             | Value                                                                       |
| --------------------------------- | --------------------------------------------------------------------------- |
| API                               | Naver Login                                                                 |
| iOS Bundle ID                     | Bundle ID from Xcode (e.g., `org.reactjs.native.example.NaverLoginExample`) |
| Android package name              | `com.naverloginexample`                                                     |
| Android app signature (`keyhash`) | Debug keystore hash extracted via `adb shell` or `keytool`                  |

After registration you will receive a **Client ID** and **Client Secret**.

#### Step 2: Set credentials in `example/src/App.tsx`

Replace the three constants at the top of the file with your actual values.

```typescript
// example/src/App.tsx
const CLIENT_ID = 'YOUR_CLIENT_ID'; // ← your Client ID
const CLIENT_SECRET = 'YOUR_CLIENT_SECRET'; // ← your Client Secret
const URL_SCHEME = 'naverloginexample'; // ← already configured, no change needed
```

#### Step 3: iOS `Info.plist` (already configured)

`example/ios/NaverLoginExample/Info.plist` already includes the following.

```xml
<!-- URL Scheme: receives the OAuth callback from the Naver app -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>naverloginexample</string>
    </array>
  </dict>
</array>

<!-- Allows querying whether the Naver app is installed -->
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>naversearchapp</string>
  <string>naversearchthirdlogin</string>
</array>
```

> **A missing `CFBundleURLSchemes` entry is the most common mistake.** Without it, the app never receives the OAuth callback, resulting in `Failed to open URL naverloginexample://thirdPartyLoginResult`.

#### Step 4: Android `AndroidManifest.xml` (already configured)

`example/android/app/src/main/AndroidManifest.xml` already includes the following activity.

```xml
<activity
  android:name="com.navercorp.nid.oauth.OAuthLoginActivity"
  android:theme="@android:style/Theme.Translucent.NoTitleBar" />
```

#### Step 5: Run the example app

```sh
# Install dependencies (first time only)
yarn
cd example/ios && pod install && cd ../..

# Start Metro bundler (separate terminal)
yarn example start

# Run on a platform
yarn example ios     # iOS Simulator
yarn example android # Android Emulator or physical device
```

### Physical device testing — iOS

The iOS Simulator does not have the Naver app, so login falls back to WebView. To test native Naver app login on a real device, ensure you have a valid **Team** and **Provisioning Profile** set in Xcode.

### Physical device testing — Android

Extract the **app signature hash** to register with the Naver Developer Console.

```sh
# Extract debug keystore hash (for development)
keytool -exportcert -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android | \
  openssl sha1 -binary | openssl base64
```

Paste the output into the Android app registration field labeled "SHA-1 fingerprint of the app signing certificate" in the Naver Developer Console.

---

## Migrating from @react-native-seoul/naver-login

### What changed

| Item                  | Before (`@react-native-seoul`) | This library                       |
| --------------------- | ------------------------------ | ---------------------------------- |
| Architecture          | Old Bridge                     | New Architecture (TurboModule)     |
| `getAgreement`        | Supported                      | **Removed** (Naver API deprecated) |
| AppDelegate setup     | Required                       | **Not required**                   |
| iOS `openURL` handler | Added in AppDelegate           | Handled internally by the library  |

### What stayed the same

- `initialize()`, `login()`, `logout()`, `deleteToken()`, `getProfile()` signatures are identical
- `NaverLoginResponse`, `NaverLoginSuccessResponse`, `NaverLoginFailureResponse`, `GetProfileResponse`, `NaverProfileData` types are identical
- The `login()` never-rejects contract is preserved

---

## Troubleshooting

### iOS build error: `naveridlogin-sdk-ios` not found

```sh
cd ios && pod install --repo-update
```

### iOS: app does not return after login

1. Verify that the URL Scheme in `Info.plist` matches the `serviceUrlSchemeIOS` value passed to `initialize()`.
2. Verify that the iOS Bundle ID registered in the Naver Developer Console matches your actual Bundle ID.
3. Verify that `LSApplicationQueriesSchemes` contains both `naversearchapp` and `naversearchthirdlogin`.

### Android build error: Manifest merger conflict

Check whether `OAuthLoginActivity` is declared twice in `AndroidManifest.xml`. The library declares it internally, so you should not add it manually.

### Android: `login()` immediately returns `isSuccess: false`

This happens when `login()` is called while the app is in the background (no current Activity). Only call `login()` in response to a user interaction.

### `deleteToken()` rejects

The request failed due to a network error or the token was already expired. If you want to sign the user out locally regardless of server-side revocation, use `logout()` instead.

---

## License

MIT © [Dongmin Yu](https://github.com/AndrewDongminYuu)
