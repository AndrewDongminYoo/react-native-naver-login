# react-native-naver-login

React Native **New Architecture(TurboModule)** 기반의 네이버 OAuth 2.0 로그인 라이브러리입니다.
[`@react-native-seoul/naver-login`](https://github.com/crossplatformkorea/react-native-naver-login)의 공개 API와 호환되도록 설계되어 기존 프로젝트에서 drop-in 교체가 가능합니다.

> **React Native New Architecture 전용입니다.** Old Architecture(Bridge) 환경에서는 동작하지 않습니다.

## 목차

- [요구사항](#요구사항)
- [네이버 개발자 센터 설정](#네이버-개발자-센터-설정)
- [설치](#설치)
- [iOS 설정](#ios-설정)
- [Android 설정](#android-설정)
- [사용법](#사용법)
- [API 레퍼런스](#api-레퍼런스)
- [동작 방식 및 주의사항](#동작-방식-및-주의사항)
- [@react-native-seoul/naver-login 마이그레이션](#react-native-seoulnaver-login-마이그레이션)
- [문제 해결](#문제-해결)
- [라이선스](#라이선스)

---

## 요구사항

| 항목                  | 최소 버전                         |
| --------------------- | --------------------------------- |
| React Native          | 0.76 이상 (New Architecture 필수) |
| iOS                   | 15.1 이상                         |
| Android               | API 24 (Android 7.0) 이상         |
| Xcode                 | 15 이상                           |
| Android Gradle Plugin | 8.x 이상                          |

---

## 네이버 개발자 센터 설정

라이브러리를 사용하기 전에 [네이버 개발자 센터](https://developers.naver.com/apps/#/register)에서 앱을 등록해야 합니다.

1. **애플리케이션 등록** → 사용 API: **네이버 로그인** 선택
2. 로그인 오픈 API 서비스 환경:
   - **iOS**: iOS Bundle ID 입력 (예: `com.example.myapp`)
   - **Android**: Android 앱 패키지명 입력 (예: `com.example.myapp`)
3. 등록 후 **Client ID**(`consumerKey`)와 **Client Secret**(`consumerSecret`)을 메모합니다.
4. iOS의 경우 사용할 **URL Scheme**을 별도로 결정합니다 (예: `naverlogin.myapp`).

---

## 설치

```sh
npm install react-native-naver-login
# 또는
yarn add react-native-naver-login
```

### iOS

```sh
cd ios && pod install
```

podspec이 `naveridlogin-sdk-ios` CocoaPod을 자동으로 가져옵니다. 별도로 SDK를 다운로드하거나 프레임워크를 추가할 필요가 없습니다.

### Android

`android/build.gradle`에 의해 Maven Central에서 `com.navercorp.nid:oauth:5.10.0`이 자동으로 추가됩니다. 추가 작업은 필요하지 않습니다.

---

## iOS 설정

### Info.plist — URL Scheme 등록

네이버 앱에서 콜백을 받기 위해 URL Scheme을 등록합니다.

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

### Info.plist — 네이버 앱 화이트리스트

네이버 앱으로 로그인을 시도할 수 있도록 LSApplicationQueriesSchemes에 등록합니다.

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>naversearchapp</string>
  <string>naversearchthirdlogin</string>
</array>
```

### AppDelegate 수정 불필요

이 라이브러리는 내부적으로 `RCTOpenURLNotification`을 구독하여 URL 콜백을 처리합니다. **`AppDelegate`에 `openURL:` 핸들러를 추가하지 않아도 됩니다.**

---

## Android 설정

### AndroidManifest.xml

네이버 로그인 액티비티를 등록합니다.

```xml
<application ...>
  <!-- 네이버 앱 로그인 콜백 액티비티 -->
  <activity
    android:name="com.navercorp.nid.oauth.OAuthLoginActivity"
    android:theme="@android:style/Theme.Translucent.NoTitleBar" />
</application>
```

### Proguard

Proguard를 사용하는 경우 다음 규칙을 추가합니다.

```plaintext
-keep class com.navercorp.nid.** { *; }
```

---

## 사용법

### 초기화

앱 시작 시 한 번만 호출합니다. 일반적으로 루트 컴포넌트의 `useEffect` 내에서 호출합니다.

```typescript
import NaverLogin from 'react-native-naver-login';

NaverLogin.initialize({
  consumerKey: 'YOUR_CLIENT_ID',
  consumerSecret: 'YOUR_CLIENT_SECRET',
  appName: 'MyApp',
  serviceUrlSchemeIOS: 'YOUR_URL_SCHEME', // iOS 전용
  disableNaverAppAuthIOS: false, // iOS 전용, 기본값 false
});
```

### 로그인

```typescript
const result = await NaverLogin.login();

if (result.isSuccess && result.successResponse) {
  const { accessToken, refreshToken, tokenType, expiresAtUnixSecondString } =
    result.successResponse;
  console.log('로그인 성공:', accessToken);
} else if (result.failureResponse?.isCancel) {
  console.log('사용자가 로그인을 취소했습니다.');
} else {
  console.log('로그인 실패:', result.failureResponse?.message);
}
```

> **중요:** `login()`은 절대 `reject`하지 않습니다. 오류와 취소 모두 `{ isSuccess: false, failureResponse: { ... } }` 형태로 resolve됩니다. `try/catch`가 아닌 `result.isSuccess`로 결과를 판별하세요.

### 프로필 조회

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

### 로그아웃 (로컬 토큰 삭제만)

서버에서 토큰을 무효화하지 않고 기기에 저장된 토큰만 삭제합니다.

```typescript
await NaverLogin.logout();
```

### 연동 해제 (서버 토큰 무효화 + 로컬 삭제)

서버에서 토큰을 무효화한 뒤 로컬 토큰도 삭제합니다. 앱과 네이버 계정 간의 연결을 완전히 해제합니다.

```typescript
try {
  await NaverLogin.deleteToken();
} catch (e) {
  console.error('연동 해제 실패:', e);
}
```

### 전체 예시

```typescript
import { useEffect, useState } from 'react';
import { Button, Text, View } from 'react-native';
import NaverLogin, {
  type NaverLoginSuccessResponse,
} from 'react-native-naver-login';

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
          <Button title="로그아웃" onPress={handleLogout} />
        </>
      ) : (
        <Button title="네이버 로그인" onPress={handleLogin} />
      )}
    </View>
  );
}
```

---

## API 레퍼런스

### `NaverLogin.initialize(params)`

| 파라미터                 | 타입      | 필수     | 설명                                        |
| ------------------------ | --------- | -------- | ------------------------------------------- |
| `consumerKey`            | `string`  | ✓        | 네이버 개발자 센터 Client ID                |
| `consumerSecret`         | `string`  | ✓        | 네이버 개발자 센터 Client Secret            |
| `appName`                | `string`  | ✓        | 앱 이름 (로그인 화면에 표시)                |
| `serviceUrlSchemeIOS`    | `string`  | iOS 필수 | iOS 콜백 URL Scheme                         |
| `disableNaverAppAuthIOS` | `boolean` | —        | 네이버 앱 로그인 비활성화 (기본값: `false`) |

반환값: `void` (동기)

---

### `NaverLogin.login()`

반환값: `Promise<NaverLoginResponse>` — **절대 reject하지 않습니다.**

```typescript
type NaverLoginResponse = {
  isSuccess: boolean;
  successResponse?: NaverLoginSuccessResponse;
  failureResponse?: NaverLoginFailureResponse;
};

type NaverLoginSuccessResponse = {
  accessToken: string;
  refreshToken: string;
  expiresAtUnixSecondString: string; // Unix 타임스탬프 (초 단위 문자열)
  tokenType: string; // 일반적으로 "Bearer"
};

type NaverLoginFailureResponse = {
  message: string;
  isCancel: boolean;
  lastErrorCodeFromNaverSDK?: string; // Android 전용
  lastErrorDescriptionFromNaverSDK?: string; // Android 전용
};
```

---

### `NaverLogin.logout()`

반환값: `Promise<void>`

로컬에 저장된 토큰만 삭제합니다. 서버의 토큰은 여전히 유효합니다.

---

### `NaverLogin.deleteToken()`

반환값: `Promise<void>` — 서버 통신 실패 시 reject합니다.

서버에 토큰 무효화 요청을 보낸 뒤 로컬 토큰을 삭제합니다. `logout()`과 달리 네트워크 오류 시 reject될 수 있습니다.

---

### `NaverLogin.getProfile(accessToken)`

| 파라미터      | 타입     | 설명                       |
| ------------- | -------- | -------------------------- |
| `accessToken` | `string` | 로그인 후 받은 액세스 토큰 |

반환값: `Promise<GetProfileResponse>` — HTTP 오류 또는 네트워크 실패 시 reject합니다.

```typescript
type GetProfileResponse = {
  resultcode: string; // "00" = 성공
  message: string; // "success"
  response: NaverProfileData;
};

type NaverProfileData = {
  id: string;
  email: string;
  name: string;
  profile_image: string | null;
  nickname: string | null;
  birthday: string | null; // "MM-DD" 형식
  birthyear: number | null;
  age: string | null; // "20-29" 형식
  gender: string | null; // "M" | "F" | "U"
  mobile: string | null;
  mobile_e164: string | null;
};
```

---

## 동작 방식 및 주의사항

### `login()`은 절대 reject하지 않는다

오류, 취소, 네트워크 장애 등 모든 실패 상황은 `{ isSuccess: false, failureResponse: {...} }` 형태로 resolve됩니다. `try/catch`로는 실패를 감지할 수 없습니다.

```typescript
// ✅ 올바른 방법
const result = await NaverLogin.login();
if (!result.isSuccess) {
  const { isCancel, message } = result.failureResponse!;
}

// ❌ 잘못된 방법 — catch는 호출되지 않음
try {
  const result = await NaverLogin.login();
} catch (e) {
  // 절대 여기에 도달하지 않음
}
```

### 동시 로그인 요청 보호

iOS와 Android 모두 동시에 두 번째 `login()` 요청이 들어오면 즉시 `{ isSuccess: false }` 로 resolve됩니다. 이전 로그인이 완료된 후 새 요청을 보내세요.

### `logout` vs `deleteToken`

|                  | `logout()`    | `deleteToken()` |
| ---------------- | ------------- | --------------- |
| 로컬 토큰 삭제   | ✓             | ✓               |
| 서버 토큰 무효화 | ✗             | ✓               |
| 네트워크 필요    | ✗             | ✓               |
| reject 가능      | ✗             | ✓               |
| 사용 시나리오    | 단순 로그아웃 | 계정 연동 해제  |

### iOS AppDelegate 수정 불필요

`initialize()` 호출 시 `RCTOpenURLNotification`을 구독하여 네이버 앱에서 돌아오는 URL을 자동으로 처리합니다. **기존에 AppDelegate에 openURL 핸들러를 추가했다면 제거**해야 충돌을 피할 수 있습니다.

### iOS 네이버 앱 미설치 시

`disableNaverAppAuthIOS: false`(기본값)이면 네이버 앱이 설치되어 있을 때 앱 로그인을 시도합니다. 미설치 시 자동으로 인앱 WebView 로그인으로 폴백됩니다.

### expiresAtUnixSecondString 파싱

```typescript
const expiresAt = new Date(parseInt(expiresAtUnixSecondString, 10) * 1000);
```

---

## @react-native-seoul/naver-login 마이그레이션

### 변경된 사항

| 항목               | 이전 (`@react-native-seoul`) | 이 라이브러리                      |
| ------------------ | ---------------------------- | ---------------------------------- |
| 아키텍처           | Old Bridge                   | New Architecture (TurboModule)     |
| `getAgreement`     | 지원                         | **제거됨** (네이버 API deprecated) |
| AppDelegate 설정   | 필요                         | **불필요**                         |
| iOS openURL 핸들러 | AppDelegate에 추가           | 라이브러리 내부 처리               |

### 변경되지 않은 사항

- `initialize()`, `login()`, `logout()`, `deleteToken()`, `getProfile()` 시그니처 동일
- `NaverLoginResponse`, `NaverLoginSuccessResponse`, `NaverLoginFailureResponse` 타입 동일
- `login()`이 절대 reject하지 않는 계약 동일
- import 경로: `react-native-naver-login`

---

## 문제 해결

### iOS 빌드 오류: `naveridlogin-sdk-ios` 없음

```sh
cd ios && pod install --repo-update
```

### iOS: 로그인 후 앱으로 돌아오지 않음

1. `Info.plist`의 URL Scheme이 `initialize()`의 `serviceUrlSchemeIOS`와 동일한지 확인합니다.
2. 네이버 개발자 센터에 등록한 iOS Bundle ID와 실제 Bundle ID가 일치하는지 확인합니다.
3. `LSApplicationQueriesSchemes`에 `naversearchapp`, `naversearchthirdlogin`이 등록되어 있는지 확인합니다.

### Android 빌드 오류: Manifest merger 충돌

`AndroidManifest.xml`에 `OAuthLoginActivity`가 중복 선언되어 있는지 확인합니다. 라이브러리가 내부적으로 선언하므로 직접 추가할 필요가 없습니다.

### Android: `login()`이 즉시 `isSuccess: false` 반환

현재 Activity가 없는 상태(백그라운드)에서 호출된 경우입니다. 사용자 인터랙션에서만 `login()`을 호출하세요.

### `deleteToken()` 실패

네트워크 오류이거나 이미 만료된 토큰입니다. 서버 무효화 실패와 무관하게 로컬에서 로그아웃 처리하려면 `logout()`을 사용하세요.

---

## 라이선스

MIT © [Dongmin Yu](https://github.com/AndrewDongminYoo)
