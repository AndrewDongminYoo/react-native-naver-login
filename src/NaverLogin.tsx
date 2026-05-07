import type {
  GetProfileResponse,
  NaverLoginInitParams,
  NaverLoginResponse,
} from './NativeNaverLogin';

const NOT_SUPPORTED = new Error(
  'NaverLogin is not supported on this platform.'
);

const NaverLogin = {
  // void return type cannot reject a Promise — throws synchronously instead.
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
