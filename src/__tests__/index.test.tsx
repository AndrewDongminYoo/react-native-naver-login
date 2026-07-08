import { describe, expect, it, jest, beforeEach } from '@jest/globals';

// jest.mock is hoisted by Babel before any import statements, so
// NaverLogin.native.tsx will resolve NativeNaverLogin to these fakes.
jest.mock('../NativeNaverLogin', () => ({
  __esModule: true,
  default: {
    initialize: jest.fn(),
    login: jest.fn(),
    refreshToken: jest.fn(),
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
  refreshToken: ReturnType<typeof jest.fn>;
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

  it('login resolves with isSuccess false on user cancellation', async () => {
    native.login.mockResolvedValue({
      isSuccess: false,
      failureResponse: { message: 'cancelled', isCancel: true },
    });

    const result = await NaverLogin.login();
    expect(result.isSuccess).toBe(false);
    expect(result.failureResponse?.isCancel).toBe(true);
  });

  it('login resolves with isSuccess false on SDK error (non-cancel)', async () => {
    native.login.mockResolvedValue({
      isSuccess: false,
      failureResponse: {
        message: 'Network error',
        isCancel: false,
        lastErrorCodeFromNaverSDK: 'NETWORK_ERROR',
        lastErrorDescriptionFromNaverSDK: 'Connection timed out',
      },
    });

    const result = await NaverLogin.login();
    expect(result.isSuccess).toBe(false);
    expect(result.failureResponse?.isCancel).toBe(false);
    expect(result.failureResponse?.lastErrorCodeFromNaverSDK).toBe(
      'NETWORK_ERROR'
    );
  });

  it('refreshToken calls native refreshToken and resolves with new tokens', async () => {
    const refreshed = {
      isSuccess: true,
      successResponse: {
        accessToken: 'new-access',
        refreshToken: 'refresh',
        expiresAtUnixSecondString: '9999999999',
        tokenType: 'Bearer',
      },
    };
    native.refreshToken.mockResolvedValue(refreshed);

    const result = await NaverLogin.refreshToken();
    expect(native.refreshToken).toHaveBeenCalledTimes(1);
    expect(result).toEqual(refreshed);
  });

  it('refreshToken resolves with isSuccess false when the refresh token is invalid', async () => {
    native.refreshToken.mockResolvedValue({
      isSuccess: false,
      failureResponse: {
        message: 'invalid refresh token',
        isCancel: false,
        lastErrorCodeFromNaverSDK: 'INVALID_REFRESH_TOKEN',
        lastErrorDescriptionFromNaverSDK: 'Refresh token expired',
      },
    });

    const result = await NaverLogin.refreshToken();
    expect(result.isSuccess).toBe(false);
    expect(result.failureResponse?.isCancel).toBe(false);
  });

  it('logout calls native logout', async () => {
    native.logout.mockResolvedValue(undefined);
    await NaverLogin.logout();
    expect(native.logout).toHaveBeenCalledTimes(1);
  });

  it('logout propagates native rejection', async () => {
    native.logout.mockRejectedValue(new Error('Network error'));
    await expect(NaverLogin.logout()).rejects.toThrow('Network error');
  });

  it('deleteToken calls native deleteToken', async () => {
    native.deleteToken.mockResolvedValue(undefined);
    await NaverLogin.deleteToken();
    expect(native.deleteToken).toHaveBeenCalledTimes(1);
  });

  it('deleteToken propagates native rejection', async () => {
    native.deleteToken.mockRejectedValue(new Error('DELETE_TOKEN_FAILED'));
    await expect(NaverLogin.deleteToken()).rejects.toThrow(
      'DELETE_TOKEN_FAILED'
    );
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

  it('getProfile propagates native rejection', async () => {
    native.getProfile.mockRejectedValue(new Error('PROFILE_ERROR'));
    await expect(NaverLogin.getProfile('bad-token')).rejects.toThrow(
      'PROFILE_ERROR'
    );
  });
});
