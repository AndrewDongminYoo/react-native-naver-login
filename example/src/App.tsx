import { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import NaverLogin, {
  type GetProfileResponse,
  type NaverLoginSuccessResponse,
} from 'react-native-naver-login';

const CLIENT_ID = 'YOUR_CLIENT_ID';
const CLIENT_SECRET = 'YOUR_CLIENT_SECRET';
const URL_SCHEME = 'YOUR_URL_SCHEME';

type AppState =
  | { kind: 'idle' }
  | { kind: 'loading' }
  | { kind: 'loggedIn'; token: NaverLoginSuccessResponse }
  | { kind: 'error'; message: string };

export default function App() {
  const [state, setState] = useState<AppState>({ kind: 'idle' });
  const [profile, setProfile] = useState<GetProfileResponse['response'] | null>(
    null
  );

  useEffect(() => {
    NaverLogin.initialize({
      consumerKey: CLIENT_ID,
      consumerSecret: CLIENT_SECRET,
      appName: 'NaverLoginExample',
      serviceUrlSchemeIOS: URL_SCHEME,
    });
  }, []);

  const handleLogin = async () => {
    setState({ kind: 'loading' });
    const result = await NaverLogin.login();

    if (!result.isSuccess || !result.successResponse) {
      const msg = result.failureResponse?.isCancel
        ? '로그인이 취소되었습니다.'
        : (result.failureResponse?.message ?? '알 수 없는 오류');
      setState({ kind: 'error', message: msg });
      return;
    }

    setState({ kind: 'loggedIn', token: result.successResponse });

    try {
      const profileResult = await NaverLogin.getProfile(
        result.successResponse.accessToken
      );
      setProfile(profileResult.response);
    } catch (e) {
      Alert.alert('프로필 조회 실패', String(e));
    }
  };

  const handleLogout = async () => {
    try {
      await NaverLogin.logout();
      setState({ kind: 'idle' });
      setProfile(null);
    } catch (e) {
      Alert.alert('로그아웃 실패', String(e));
    }
  };

  const handleDeleteToken = async () => {
    try {
      await NaverLogin.deleteToken();
      setState({ kind: 'idle' });
      setProfile(null);
    } catch (e) {
      Alert.alert('토큰 삭제 실패', String(e));
    }
  };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>Naver Login Demo</Text>

      {state.kind === 'idle' && (
        <TouchableOpacity style={styles.button} onPress={handleLogin}>
          <Text style={styles.buttonText}>네이버 로그인</Text>
        </TouchableOpacity>
      )}

      {state.kind === 'loading' && (
        <ActivityIndicator size="large" color="#03C75A" />
      )}

      {state.kind === 'error' && (
        <>
          <Text style={styles.error}>{state.message}</Text>
          <TouchableOpacity style={styles.button} onPress={handleLogin}>
            <Text style={styles.buttonText}>다시 시도</Text>
          </TouchableOpacity>
        </>
      )}

      {state.kind === 'loggedIn' && (
        <>
          <View style={styles.card}>
            <Text style={styles.label}>Access Token</Text>
            <Text style={styles.value} numberOfLines={2}>
              {state.token.accessToken}
            </Text>
            <Text style={styles.label}>Token Type</Text>
            <Text style={styles.value}>{state.token.tokenType}</Text>
            <Text style={styles.label}>Expires At</Text>
            <Text style={styles.value}>
              {state.token.expiresAtUnixSecondString}
            </Text>
          </View>

          {profile && (
            <View style={styles.card}>
              <Text style={styles.label}>이름</Text>
              <Text style={styles.value}>{profile.name ?? '-'}</Text>
              <Text style={styles.label}>이메일</Text>
              <Text style={styles.value}>{profile.email ?? '-'}</Text>
              <Text style={styles.label}>닉네임</Text>
              <Text style={styles.value}>{profile.nickname ?? '-'}</Text>
            </View>
          )}

          <TouchableOpacity
            style={[styles.button, styles.logoutButton]}
            onPress={handleLogout}
          >
            <Text style={styles.buttonText}>로그아웃</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.button, styles.deleteButton]}
            onPress={handleDeleteToken}
          >
            <Text style={styles.buttonText}>연동 해제</Text>
          </TouchableOpacity>
        </>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
    backgroundColor: '#f5f5f5',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 32,
  },
  card: {
    width: '100%',
    backgroundColor: '#fff',
    borderRadius: 8,
    padding: 16,
    marginBottom: 16,
  },
  label: {
    fontSize: 12,
    color: '#888',
    marginTop: 8,
  },
  value: {
    fontSize: 14,
    color: '#222',
  },
  button: {
    backgroundColor: '#03C75A',
    paddingVertical: 14,
    paddingHorizontal: 40,
    borderRadius: 8,
    marginBottom: 12,
  },
  logoutButton: {
    backgroundColor: '#555',
  },
  deleteButton: {
    backgroundColor: '#cc3333',
  },
  buttonText: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 16,
  },
  error: {
    color: '#cc3333',
    marginBottom: 16,
    textAlign: 'center',
  },
});
