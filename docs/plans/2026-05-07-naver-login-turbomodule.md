# Naver Login TurboModule Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `multiply` scaffold placeholder with a complete Naver OAuth 2.0 TurboModule exposing `initialize`, `login`, `logout`, `deleteToken`, and `getProfile`.

**Architecture:** The JS layer defines types and a thin wrapper over the codegen-generated `NativeNaverLogin` TurboModule. iOS uses `NaverThirdPartyLoginConnection` with an `RCTOpenURLNotification` observer (no AppDelegate change needed). Android uses `NaverIdLoginSDK` with an `OAuthLoginCallback`.

**Tech Stack:** TypeScript (codegen spec), Objective-C++ (iOS), Kotlin (Android), `naveridlogin-sdk-ios` CocoaPod, `com.navercorp.nid:oauth:5.10.0` Maven artifact.

---

## File Map

| Action | Path                                                       | Responsibility                                                |
| ------ | ---------------------------------------------------------- | ------------------------------------------------------------- |
| Modify | `src/NativeNaverLogin.ts`                                  | TurboModule codegen spec — method signatures + exported types |
| Create | `src/NaverLogin.native.tsx`                                | Native platform JS wrapper; type-casts raw native returns     |
| Create | `src/NaverLogin.tsx`                                       | Web stub — throws not-supported error                         |
| Modify | `src/index.tsx`                                            | Re-exports `NaverLogin` default + all public types            |
| Delete | `src/multiply.tsx`                                         | Remove scaffold                                               |
| Delete | `src/multiply.native.tsx`                                  | Remove scaffold                                               |
| Modify | `src/__tests__/index.test.tsx`                             | Unit tests for the JS wrapper                                 |
| Modify | `NaverLogin.podspec`                                       | Add `naveridlogin-sdk-ios` pod dependency                     |
| Modify | `ios/NaverLogin.h`                                         | Add `NaverThirdPartyLoginConnectionDelegate` conformance      |
| Modify | `ios/NaverLogin.mm`                                        | Full iOS implementation                                       |
| Modify | `android/build.gradle`                                     | Add Naver OAuth SDK dependency                                |
| Modify | `android/src/main/java/com/naverlogin/NaverLoginModule.kt` | Full Android implementation                                   |
| Modify | `example/src/App.tsx`                                      | Demo login UI                                                 |

---

## Task 1: TypeScript Codegen Spec

**Files:**

- Modify: `src/NativeNaverLogin.ts`
- Delete: `src/multiply.tsx`, `src/multiply.native.tsx`

- [ ] **Step 1.1: Remove scaffold files**

```bash
rm src/multiply.tsx src/multiply.native.tsx
```

- [ ] **Step 1.2: Write the new codegen spec**

Replace the entire contents of `src/NativeNaverLogin.ts`:

```typescript
import { TurboModuleRegistry, type TurboModule } from 'react-native';

// ---------------------------------------------------------------------------
// Input / output types
// Note: codegen in RN 0.85 supports named type aliases with optional fields.
// Complex return types (login, getProfile) use Object here and are cast to
// proper types in NaverLogin.native.tsx so the spec stays codegen-safe.
// ---------------------------------------------------------------------------

export type NaverLoginInitParams = {
  consumerKey: string;
  consumerSecret: string;
  appName: string;
  disableNaverAppAuthIOS?: boolean;
  serviceUrlSchemeIOS?: string;
};

export type NaverLoginSuccessResponse = {
  accessToken: string;
  refreshToken: string;
  expiresAtUnixSecondString: string;
  tokenType: string;
};

export type NaverLoginFailureResponse = {
  message: string;
  isCancel: boolean;
  lastErrorCodeFromNaverSDK?: string;
  lastErrorDescriptionFromNaverSDK?: string;
};

export type NaverLoginResponse = {
  isSuccess: boolean;
  successResponse?: NaverLoginSuccessResponse;
  failureResponse?: NaverLoginFailureResponse;
};

export type NaverProfileData = {
  id: string;
  profile_image: string | null;
  email: string;
  name: string;
  birthday: string | null;
  age: string | null;
  birthyear: number | null;
  gender: string | null;
  mobile: string | null;
  mobile_e164: string | null;
  nickname: string | null;
  ci?: string | null; // present only with business-info + CI scope
};

export type GetProfileResponse = {
  resultcode: string;
  message: string;
  response: NaverProfileData;
};

// ---------------------------------------------------------------------------
// TurboModule spec
// ---------------------------------------------------------------------------

export interface Spec extends TurboModule {
  initialize(params: NaverLoginInitParams): void;
  login(): Promise<Object>;
  logout(): Promise<void>;
  deleteToken(): Promise<void>;
  getProfile(accessToken: string): Promise<Object>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('NaverLogin');
```

- [ ] **Step 1.3: Verify TypeScript compiles**

```bash
yarn typecheck
```

Expected: no errors. If `multiply` is still referenced anywhere, the error output will tell you which file.

- [ ] **Step 1.4: Commit**

```bash
git add src/NativeNaverLogin.ts
git rm src/multiply.tsx src/multiply.native.tsx
git commit -m "feat(spec): replace multiply with Naver Login TurboModule spec"
```

---

## Task 2: JS Wrapper Layer

**Files:**

- Create: `src/NaverLogin.native.tsx`
- Create: `src/NaverLogin.tsx`
- Modify: `src/index.tsx`

- [ ] **Step 2.1: Create `src/NaverLogin.native.tsx`**

```typescript
import NativeNaverLogin from './NativeNaverLogin';
import type {
  GetProfileResponse,
  NaverLoginInitParams,
  NaverLoginResponse,
} from './NativeNaverLogin';

const NaverLogin = {
  initialize(params: NaverLoginInitParams): void {
    NativeNaverLogin.initialize(params);
  },

  login(): Promise<NaverLoginResponse> {
    return NativeNaverLogin.login() as Promise<NaverLoginResponse>;
  },

  logout(): Promise<void> {
    return NativeNaverLogin.logout();
  },

  deleteToken(): Promise<void> {
    return NativeNaverLogin.deleteToken();
  },

  getProfile(accessToken: string): Promise<GetProfileResponse> {
    return NativeNaverLogin.getProfile(
      accessToken
    ) as Promise<GetProfileResponse>;
  },
};

export default NaverLogin;
```

- [ ] **Step 2.2: Create `src/NaverLogin.tsx` (web stub)**

```typescript
import type {
  GetProfileResponse,
  NaverLoginInitParams,
  NaverLoginResponse,
} from './NativeNaverLogin';

const NOT_SUPPORTED = new Error(
  'NaverLogin is not supported on this platform.'
);

const NaverLogin = {
  initialize(_params: NaverLoginInitParams): void {
    throw NOT_SUPPORTED;
  },

  login(): Promise<NaverLoginResponse> {
    return Promise.reject(NOT_SUPPORTED);
  },

  logout(): Promise<void> {
    return Promise.reject(NOT_SUPPORTED);
  },

  deleteToken(): Promise<void> {
    return Promise.reject(NOT_SUPPORTED);
  },

  getProfile(_accessToken: string): Promise<GetProfileResponse> {
    return Promise.reject(NOT_SUPPORTED);
  },
};

export default NaverLogin;
```

- [ ] **Step 2.3: Update `src/index.tsx`**

Replace the entire file:

```typescript
export { default } from './NaverLogin';
export type {
  GetProfileResponse,
  NaverLoginFailureResponse,
  NaverLoginInitParams,
  NaverLoginResponse,
  NaverLoginSuccessResponse,
  NaverProfileData,
} from './NativeNaverLogin';
```

- [ ] **Step 2.4: Verify TypeScript compiles**

```bash
yarn typecheck
```

Expected: no errors.

- [ ] **Step 2.5: Commit**

```bash
git add src/NaverLogin.native.tsx src/NaverLogin.tsx src/index.tsx
git commit -m "feat(js): add NaverLogin JS wrapper and web stub"
```

---

## Task 3: Unit Tests

**Files:**

- Modify: `src/__tests__/index.test.tsx`

- [ ] **Step 3.1: Write the tests**

Replace the entire contents of `src/__tests__/index.test.tsx`:

```typescript
import { describe, expect, it, jest, beforeEach } from '@jest/globals';

// jest.mock is hoisted by Babel before any import statements, so
// NaverLogin.native.tsx will resolve NativeNaverLogin to these fakes.
jest.mock('../NativeNaverLogin', () => ({
  __esModule: true,
  default: {
    initialize: jest.fn(),
    login: jest.fn(),
    logout: jest.fn(),
    deleteToken: jest.fn(),
    getProfile: jest.fn(),
  },
}));

import NaverLogin from '../NaverLogin.native';
import NativeNaverLogin from '../NativeNaverLogin';

const native = NativeNaverLogin as {
  initialize: ReturnType<typeof jest.fn>;
  login: ReturnType<typeof jest.fn>;
  logout: ReturnType<typeof jest.fn>;
  deleteToken: ReturnType<typeof jest.fn>;
  getProfile: ReturnType<typeof jest.fn>;
};

describe('NaverLogin', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('initialize passes params to native module', () => {
    const params = {
      consumerKey: 'key',
      consumerSecret: 'secret',
      appName: 'TestApp',
    };
    NaverLogin.initialize(params);
    expect(native.initialize).toHaveBeenCalledWith(params);
  });

  it('login calls native login and resolves with NaverLoginResponse', async () => {
    const successResponse = {
      isSuccess: true,
      successResponse: {
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAtUnixSecondString: '9999999999',
        tokenType: 'Bearer',
      },
    };
    native.login.mockResolvedValue(successResponse);

    const result = await NaverLogin.login();
    expect(native.login).toHaveBeenCalledTimes(1);
    expect(result).toEqual(successResponse);
  });

  it('login resolves with isSuccess false on failure', async () => {
    const failureResponse = {
      isSuccess: false,
      failureResponse: { message: 'cancelled', isCancel: true },
    };
    native.login.mockResolvedValue(failureResponse);

    const result = await NaverLogin.login();
    expect(result.isSuccess).toBe(false);
    expect(result.failureResponse?.isCancel).toBe(true);
  });

  it('logout calls native logout', async () => {
    native.logout.mockResolvedValue(undefined);
    await NaverLogin.logout();
    expect(native.logout).toHaveBeenCalledTimes(1);
  });

  it('deleteToken calls native deleteToken', async () => {
    native.deleteToken.mockResolvedValue(undefined);
    await NaverLogin.deleteToken();
    expect(native.deleteToken).toHaveBeenCalledTimes(1);
  });

  it('getProfile calls native getProfile with accessToken', async () => {
    const profileResponse = {
      resultcode: '00',
      message: 'success',
      response: {
        id: '12345',
        profile_image: null,
        email: 'test@naver.com',
        name: '홍길동',
        birthday: null,
        age: null,
        birthyear: null,
        gender: null,
        mobile: null,
        mobile_e164: null,
        nickname: null,
      },
    };
    native.getProfile.mockResolvedValue(profileResponse);

    const result = await NaverLogin.getProfile('my-access-token');
    expect(native.getProfile).toHaveBeenCalledWith('my-access-token');
    expect(result.response.id).toBe('12345');
  });
});
```

- [ ] **Step 3.2: Run the tests**

```bash
yarn test
```

Expected: all 6 tests pass.

- [ ] **Step 3.3: Commit**

```bash
git add src/__tests__/index.test.tsx
git commit -m "test: add NaverLogin JS wrapper unit tests"
```

---

## Task 4: iOS Implementation

**Files:**

- Modify: `NaverLogin.podspec`
- Modify: `ios/NaverLogin.h`
- Modify: `ios/NaverLogin.mm`

- [ ] **Step 4.1: Add Naver SDK to podspec**

Edit `NaverLogin.podspec` — add one line before `install_modules_dependencies(s)`:

```ruby
require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "NaverLogin"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/AndrewDongminYuu/react-native-naver-login.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift,cpp}"
  s.private_header_files = "ios/**/*.h"

  s.dependency 'naveridlogin-sdk-ios'

  install_modules_dependencies(s)
end
```

- [ ] **Step 4.2: Update `ios/NaverLogin.h`**

Keep the header minimal — no NaverThirdPartyLogin import here to avoid compile errors before `pod install`. The delegate conformance is declared in a private category inside the `.mm` file.

Replace the entire file:

```objc
#import <NaverLoginSpec/NaverLoginSpec.h>

@interface NaverLogin : NSObject <NativeNaverLoginSpec>

@end
```

- [ ] **Step 4.3: Write `ios/NaverLogin.mm`**

Replace the entire file:

```objc
#import "NaverLogin.h"
#import <NaverThirdPartyLogin/NaverThirdPartyLogin.h>
#import <React/RCTUtils.h>

// Private category: declares NaverThirdPartyLoginConnectionDelegate conformance
// and internal state. This keeps the public .h file free of SDK headers so it
// compiles before `pod install` runs.
@interface NaverLogin () <NaverThirdPartyLoginConnectionDelegate>
// Stored while a login() Promise is in flight. nil when idle.
@property (nonatomic, copy, nullable) RCTPromiseResolveBlock loginResolve;
@property (nonatomic, copy, nullable) RCTPromiseRejectBlock loginReject;
@end

@implementation NaverLogin

// -------------------------------------------------------------------------
// TurboModule boilerplate
// -------------------------------------------------------------------------

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeNaverLoginSpecJSI>(params);
}

+ (NSString *)moduleName
{
    return @"NaverLogin";
}

// -------------------------------------------------------------------------
// initialize
// -------------------------------------------------------------------------

- (void)initialize:(JS::NativeNaverLogin::NaverLoginInitParams &)params
{
    NaverThirdPartyLoginConnection *conn = [NaverThirdPartyLoginConnection getSharedInstance];

    conn.consumerKey    = [NSString stringWithUTF8String:params.consumerKey().c_str()];
    conn.consumerSecret = [NSString stringWithUTF8String:params.consumerSecret().c_str()];
    conn.appName        = [NSString stringWithUTF8String:params.appName().c_str()];

    auto serviceScheme = params.serviceUrlSchemeIOS();
    if (serviceScheme.has_value()) {
        conn.serviceUrlScheme = [NSString stringWithUTF8String:serviceScheme.value().c_str()];
    }

    auto disableApp = params.disableNaverAppAuthIOS();
    conn.isNaverAppOauthEnable = !(disableApp.has_value() && disableApp.value());

    // Observe RCTLinkingManager URL events so the host app's AppDelegate
    // does NOT need a custom openURL: handler.
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"RCTOpenURLNotification"
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleOpenURL:)
                                                 name:@"RCTOpenURLNotification"
                                               object:nil];
}

- (void)handleOpenURL:(NSNotification *)notification
{
    NSURL *url = notification.userInfo[@"url"];
    if (url) {
        [[NaverThirdPartyLoginConnection getSharedInstance]
         application:[UIApplication sharedApplication]
         openURL:url
         options:@{}];
    }
}

// -------------------------------------------------------------------------
// login
// -------------------------------------------------------------------------

- (void)login:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
    if (self.loginResolve != nil) {
        reject(@"LOGIN_IN_PROGRESS", @"A login request is already in progress.", nil);
        return;
    }

    self.loginResolve = resolve;
    self.loginReject  = reject;

    NaverThirdPartyLoginConnection *conn = [NaverThirdPartyLoginConnection getSharedInstance];
    conn.delegate = self;

    dispatch_async(dispatch_get_main_queue(), ^{
        [conn requestThirdPartyLogin];
    });
}

// -------------------------------------------------------------------------
// logout
// -------------------------------------------------------------------------

- (void)logout:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
    [[NaverThirdPartyLoginConnection getSharedInstance] requestDeleteToken];
    resolve(nil);
}

// -------------------------------------------------------------------------
// deleteToken
// -------------------------------------------------------------------------

- (void)deleteToken:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
    NaverThirdPartyLoginConnection *conn = [NaverThirdPartyLoginConnection getSharedInstance];
    [conn requestDeleteToken];
    [conn requestUnlinkToken];
    resolve(nil);
}

// -------------------------------------------------------------------------
// getProfile
// -------------------------------------------------------------------------

- (void)getProfile:(NSString *)accessToken
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject
{
    NSURL *url = [NSURL URLWithString:@"https://openapi.naver.com/v1/nid/me"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", accessToken]
       forHTTPHeaderField:@"Authorization"];

    [[[NSURLSession sharedSession]
      dataTaskWithRequest:req
      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            reject(@"PROFILE_ERROR", error.localizedDescription, error);
            return;
        }
        NSError *parseError = nil;
        id json = [NSJSONSerialization JSONObjectWithData:data
                                                  options:0
                                                    error:&parseError];
        if (parseError || ![json isKindOfClass:[NSDictionary class]]) {
            reject(@"PARSE_ERROR",
                   parseError ? parseError.localizedDescription : @"Unexpected response format",
                   parseError);
            return;
        }
        resolve(json);
    }] resume];
}

// -------------------------------------------------------------------------
// NaverThirdPartyLoginConnectionDelegate
// -------------------------------------------------------------------------

- (void)oauth20ConnectionDidFinishRequestACTokenWithAuthCode
{
    [self resolveLoginWithConnection:[NaverThirdPartyLoginConnection getSharedInstance]];
}

- (void)oauth20ConnectionDidFinishRequestACTokenWithRefreshToken
{
    [self resolveLoginWithConnection:[NaverThirdPartyLoginConnection getSharedInstance]];
}

- (void)oauth20ConnectionDidFinishDeleteToken
{
    // logout/deleteToken resolve immediately; nothing to do here.
}

- (void)oauth20Connection:(NaverThirdPartyLoginConnection *)connection
     didFailWithRequestType:(NaverThirdPartyLoginConnectionRequestType)requestType
{
    NSString *errorCode = connection.lastErrorCode ?: @"";
    BOOL isCancel = [errorCode isEqualToString:@"user_cancel"];

    NSDictionary *result = @{
        @"isSuccess": @NO,
        @"failureResponse": @{
            @"message": connection.lastErrorDescription ?: @"Unknown error",
            @"isCancel": @(isCancel),
        }
    };

    if (self.loginResolve) {
        self.loginResolve(result);
        self.loginResolve = nil;
        self.loginReject  = nil;
    }
}

// -------------------------------------------------------------------------
// Private helpers
// -------------------------------------------------------------------------

- (void)resolveLoginWithConnection:(NaverThirdPartyLoginConnection *)conn
{
    NSDictionary *result = @{
        @"isSuccess": @YES,
        @"successResponse": @{
            @"accessToken":              conn.accessToken  ?: @"",
            @"refreshToken":             conn.refreshToken ?: @"",
            @"expiresAtUnixSecondString": conn.expiresAt   ?: @"",
            @"tokenType":                conn.tokenType    ?: @"",
        }
    };

    if (self.loginResolve) {
        self.loginResolve(result);
        self.loginResolve = nil;
        self.loginReject  = nil;
    }
}

@end
```

- [ ] **Step 4.4: Install pods and verify**

```bash
cd example/ios && pod install && cd ../..
```

Expected: pods install without errors. The `naveridlogin-sdk-ios` pod should appear in the output.

- [ ] **Step 4.5: Commit**

```bash
git add NaverLogin.podspec ios/NaverLogin.h ios/NaverLogin.mm
git commit -m "feat(ios): implement NaverLogin TurboModule with Naver SDK"
```

---

## Task 5: Android Implementation

**Files:**

- Modify: `android/build.gradle`
- Modify: `android/src/main/java/com/naverlogin/NaverLoginModule.kt`

- [ ] **Step 5.1: Add Naver SDK dependency to `android/build.gradle`**

In the `dependencies { }` block, add the Naver SDK after `react-android`:

```groovy
dependencies {
  implementation "com.facebook.react:react-android"
  implementation "com.navercorp.nid:oauth:5.10.0"
}
```

Also add the Naver Maven repository at the top of `buildscript { repositories { } }` and in a new `allprojects { repositories { } }` block:

```groovy
// After the existing buildscript block, add:
repositories {
  google()
  mavenCentral()
}
```

The complete modified `android/build.gradle`:

```groovy
buildscript {
  ext.NaverLogin = [
    kotlinVersion: "2.0.21",
    minSdkVersion: 24,
    compileSdkVersion: 36,
    targetSdkVersion: 36
  ]

  ext.getExtOrDefault = { prop ->
    if (rootProject.ext.has(prop)) {
      return rootProject.ext.get(prop)
    }

    return NaverLogin[prop]
  }

  repositories {
    google()
    mavenCentral()
  }

  dependencies {
    classpath "com.android.tools.build:gradle:8.7.2"
    // noinspection DifferentKotlinGradleVersion
    classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:${getExtOrDefault('kotlinVersion')}"
  }
}


apply plugin: "com.android.library"
apply plugin: "kotlin-android"

apply plugin: "com.facebook.react"

android {
  namespace "com.naverlogin"

  compileSdkVersion getExtOrDefault("compileSdkVersion")

  defaultConfig {
    minSdkVersion getExtOrDefault("minSdkVersion")
    targetSdkVersion getExtOrDefault("targetSdkVersion")
  }

  buildFeatures {
    buildConfig true
  }

  buildTypes {
    release {
      minifyEnabled false
    }
  }

  lint {
    disable "GradleCompatible"
  }

  compileOptions {
    sourceCompatibility JavaVersion.VERSION_1_8
    targetCompatibility JavaVersion.VERSION_1_8
  }
}

repositories {
  google()
  mavenCentral()
}

dependencies {
  implementation "com.facebook.react:react-android"
  implementation "com.navercorp.nid:oauth:5.10.0"
}
```

- [ ] **Step 5.2: Write `android/src/main/java/com/naverlogin/NaverLoginModule.kt`**

Replace the entire file:

```kotlin
package com.naverlogin

import android.os.Handler
import android.os.Looper
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableNativeMap
import com.navercorp.nid.NaverIdLoginSDK
import com.navercorp.nid.oauth.OAuthLoginCallback
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class NaverLoginModule(
  reactContext: ReactApplicationContext,
) : NativeNaverLoginSpec(reactContext) {

  companion object {
    const val NAME = NativeNaverLoginSpec.NAME
  }

  private val mainHandler = Handler(Looper.getMainLooper())

  // -------------------------------------------------------------------------
  // initialize
  // -------------------------------------------------------------------------

  override fun initialize(params: ReadableMap) {
    val clientId     = params.getString("consumerKey")    ?: ""
    val clientSecret = params.getString("consumerSecret") ?: ""
    val clientName   = params.getString("appName")        ?: ""
    NaverIdLoginSDK.initialize(reactApplicationContext, clientId, clientSecret, clientName)
  }

  // -------------------------------------------------------------------------
  // login
  // -------------------------------------------------------------------------

  override fun login(promise: Promise) {
    val activity = currentActivity ?: run {
      promise.reject("NO_ACTIVITY", "NaverLogin.login() called with no current Activity.")
      return
    }

    val callback = object : OAuthLoginCallback {
      override fun onSuccess() {
        val successResponse = WritableNativeMap().apply {
          putString("accessToken",              NaverIdLoginSDK.getAccessToken()  ?: "")
          putString("refreshToken",             NaverIdLoginSDK.getRefreshToken() ?: "")
          putString("expiresAtUnixSecondString", NaverIdLoginSDK.getExpiresAt().toString())
          putString("tokenType",                NaverIdLoginSDK.getTokenType()   ?: "Bearer")
        }
        val result = WritableNativeMap().apply {
          putBoolean("isSuccess", true)
          putMap("successResponse", successResponse)
        }
        promise.resolve(result)
      }

      override fun onFailure(httpStatus: Int, message: String) {
        val failureResponse = WritableNativeMap().apply {
          putString("message",                        message)
          putBoolean("isCancel",                      false)
          putString("lastErrorCodeFromNaverSDK",        NaverIdLoginSDK.getLastErrorCode().code)
          putString("lastErrorDescriptionFromNaverSDK", NaverIdLoginSDK.getLastErrorDescription() ?: "")
        }
        val result = WritableNativeMap().apply {
          putBoolean("isSuccess", false)
          putMap("failureResponse", failureResponse)
        }
        promise.resolve(result)
      }

      override fun onError(errorCode: Int, message: String) {
        // errorCode -1 is user cancellation in the Naver SDK.
        val isCancel = errorCode == -1
        val failureResponse = WritableNativeMap().apply {
          putString("message",                        message)
          putBoolean("isCancel",                      isCancel)
          putString("lastErrorCodeFromNaverSDK",        NaverIdLoginSDK.getLastErrorCode().code)
          putString("lastErrorDescriptionFromNaverSDK", NaverIdLoginSDK.getLastErrorDescription() ?: "")
        }
        val result = WritableNativeMap().apply {
          putBoolean("isSuccess", false)
          putMap("failureResponse", failureResponse)
        }
        promise.resolve(result)
      }
    }

    mainHandler.post {
      NaverIdLoginSDK.authenticate(activity, callback)
    }
  }

  // -------------------------------------------------------------------------
  // logout
  // -------------------------------------------------------------------------

  override fun logout(promise: Promise) {
    NaverIdLoginSDK.logout()
    promise.resolve(null)
  }

  // -------------------------------------------------------------------------
  // deleteToken
  // -------------------------------------------------------------------------

  override fun deleteToken(promise: Promise) {
    val callback = object : OAuthLoginCallback {
      override fun onSuccess() { promise.resolve(null) }
      override fun onFailure(httpStatus: Int, message: String) {
        promise.reject("DELETE_TOKEN_FAILED", message)
      }
      override fun onError(errorCode: Int, message: String) {
        promise.reject("DELETE_TOKEN_ERROR", message)
      }
    }
    NaverIdLoginSDK.logout()
    NaverIdLoginSDK.callDeleteTokenApi(reactApplicationContext, callback)
  }

  // -------------------------------------------------------------------------
  // getProfile
  // -------------------------------------------------------------------------

  override fun getProfile(accessToken: String, promise: Promise) {
    Thread {
      try {
        val url        = URL("https://openapi.naver.com/v1/nid/me")
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.setRequestProperty("Authorization", "Bearer $accessToken")
        connection.connectTimeout = 10_000
        connection.readTimeout    = 10_000

        val responseCode = connection.responseCode
        if (responseCode != 200) {
          promise.reject("PROFILE_HTTP_ERROR", "HTTP $responseCode")
          return@Thread
        }

        val body = BufferedReader(InputStreamReader(connection.inputStream)).readText()
        val json = JSONObject(body)
        promise.resolve(jsonObjectToWritableMap(json))
      } catch (e: Exception) {
        promise.reject("PROFILE_ERROR", e.message ?: "Unknown error", e)
      }
    }.start()
  }

  // -------------------------------------------------------------------------
  // JSON helper
  // -------------------------------------------------------------------------

  private fun jsonObjectToWritableMap(json: JSONObject): WritableNativeMap {
    val map = WritableNativeMap()
    json.keys().forEach { key ->
      when (val value = json.opt(key)) {
        is JSONObject        -> map.putMap(key, jsonObjectToWritableMap(value))
        is String            -> map.putString(key, value)
        is Int               -> map.putInt(key, value)
        is Long              -> map.putDouble(key, value.toDouble())
        is Double            -> map.putDouble(key, value)
        is Boolean           -> map.putBoolean(key, value)
        JSONObject.NULL, null -> map.putNull(key)
        else                 -> map.putString(key, value.toString())
      }
    }
    return map
  }
}
```

- [ ] **Step 5.3: Verify Android build compiles**

```bash
cd example/android && ./gradlew :react-native-naver-login:compileReleaseKotlin --no-daemon && cd ../..
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 5.4: Commit**

```bash
git add android/build.gradle android/src/main/java/com/naverlogin/NaverLoginModule.kt
git commit -m "feat(android): implement NaverLogin TurboModule with Naver OAuth SDK"
```

---

## Task 6: Example App

**Files:**

- Modify: `example/src/App.tsx`

- [ ] **Step 6.1: Update the example app**

Replace the entire file. Replace `YOUR_CLIENT_ID`, `YOUR_CLIENT_SECRET`, and `YOUR_URL_SCHEME` with real Naver Developer Console values when testing.

```tsx
import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Button,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import NaverLogin, {
  type NaverLoginResponse,
  type GetProfileResponse,
} from 'react-native-naver-login';

const NAVER_APP = {
  consumerKey: 'YOUR_CLIENT_ID',
  consumerSecret: 'YOUR_CLIENT_SECRET',
  appName: 'NaverLoginExample',
  serviceUrlSchemeIOS: 'YOUR_URL_SCHEME',
};

type Status =
  | { tag: 'idle' }
  | { tag: 'loading' }
  | { tag: 'loggedIn'; login: NaverLoginResponse; profile?: GetProfileResponse }
  | { tag: 'error'; message: string };

export default function App() {
  const [status, setStatus] = useState<Status>({ tag: 'idle' });

  useEffect(() => {
    NaverLogin.initialize(NAVER_APP);
  }, []);

  const handleLogin = async () => {
    setStatus({ tag: 'loading' });
    const result = await NaverLogin.login();
    if (!result.isSuccess) {
      setStatus({
        tag: 'error',
        message: result.failureResponse?.message ?? 'Login failed',
      });
      return;
    }
    setStatus({ tag: 'loggedIn', login: result });

    const token = result.successResponse?.accessToken ?? '';
    const profile = await NaverLogin.getProfile(token).catch(() => undefined);
    setStatus({ tag: 'loggedIn', login: result, profile });
  };

  const handleLogout = async () => {
    await NaverLogin.logout();
    setStatus({ tag: 'idle' });
  };

  const handleDeleteToken = async () => {
    await NaverLogin.deleteToken();
    setStatus({ tag: 'idle' });
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.title}>Naver Login Demo</Text>

        {status.tag === 'idle' && (
          <Button title="Login with Naver" onPress={handleLogin} />
        )}

        {status.tag === 'loading' && <ActivityIndicator />}

        {status.tag === 'error' && (
          <>
            <Text style={styles.error}>{status.message}</Text>
            <Button title="Try again" onPress={handleLogin} />
          </>
        )}

        {status.tag === 'loggedIn' && (
          <>
            <Text style={styles.label}>Access token:</Text>
            <Text style={styles.value} numberOfLines={2}>
              {status.login.successResponse?.accessToken}
            </Text>

            {status.profile && (
              <>
                <Text style={styles.label}>Name:</Text>
                <Text style={styles.value}>{status.profile.response.name}</Text>
                <Text style={styles.label}>Email:</Text>
                <Text style={styles.value}>
                  {status.profile.response.email}
                </Text>
              </>
            )}

            <View style={styles.actions}>
              <Button title="Logout" onPress={handleLogout} />
              <Button
                title="Delete Token"
                color="red"
                onPress={handleDeleteToken}
              />
            </View>
          </>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
  content: { padding: 24, gap: 12 },
  title: { fontSize: 22, fontWeight: 'bold', marginBottom: 16 },
  label: { fontSize: 12, color: '#888' },
  value: { fontSize: 14, marginBottom: 8 },
  error: { color: 'red', marginBottom: 8 },
  actions: { gap: 8, marginTop: 16 },
});
```

- [ ] **Step 6.2: Typecheck the example**

```bash
yarn typecheck
```

Expected: no errors.

- [ ] **Step 6.3: Commit**

```bash
git add example/src/App.tsx
git commit -m "feat(example): update example app to demo Naver Login"
```

---

## Verification

After all tasks complete, run the full quality gate:

```bash
yarn typecheck   # TypeScript clean
yarn test        # 6 tests pass
yarn lint        # ESLint + Prettier clean
```

To verify native integration, set real Naver Developer Console credentials in `example/src/App.tsx` and run:

```bash
yarn example ios      # Requires Xcode + CocoaPods
yarn example android  # Requires ANDROID_HOME + API 24+ device/emulator
```

Check that the Naver login screen appears, authentication succeeds, and the profile response renders in the app.
