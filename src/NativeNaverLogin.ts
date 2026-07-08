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
  // Present only when the Naver app has business-info + CI scope; key may be absent.
  ci?: string | null;
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
  refreshToken(): Promise<Object>;
  logout(): Promise<void>;
  deleteToken(): Promise<void>;
  getProfile(accessToken: string): Promise<Object>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('NaverLogin');
