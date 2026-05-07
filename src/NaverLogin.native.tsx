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
