import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adwa_short/core/constants/api_constants.dart';
import 'package:adwa_short/core/network/api_exception.dart';
import 'package:adwa_short/core/network/token_manager.dart';
import 'package:adwa_short/features/auth/providers/auth_provider.dart';
import 'package:adwa_short/features/auth/repositories/auth_repository.dart';
import 'package:adwa_short/models/user.dart';

class _MockAuthRepository implements AuthRepository {
  _MockAuthRepository(this.tokenManager);

  @override
  final TokenManager tokenManager;

  bool fetchMeThrowsNetworkError = false;
  bool fetchMeThrows401Expired = false;
  User? mockUser;

  @override
  Future<User> fetchMe() async {
    if (fetchMeThrowsNetworkError) {
      throw ApiException.network('Connection refused');
    }
    if (fetchMeThrows401Expired) {
      throw ApiException(
        statusCode: 401,
        code: ApiConstants.errorCodeTokenExpired,
        message: 'Token expired',
      );
    }
    return mockUser ??
        User(
          id: 'user-101',
          phone: '+251911223344',
          displayName: 'Selam Adwa',
        );
  }

  @override
  Future<void> setGuest(bool value) async {
    await tokenManager.setGuest(value);
  }

  @override
  Future<void> logout() async {
    await tokenManager.clearAll();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session & Token Persistence Tests', () {
    late SharedPreferences prefs;
    late TokenManager tokenManager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      tokenManager = TokenManager(prefs);
    });

    test('TokenManager saves and restores authentication tokens and user profile', () async {
      expect(tokenManager.isLoggedIn, isFalse);
      expect(tokenManager.isGuest, isFalse);
      expect(tokenManager.accessToken, isNull);

      final user = User(
        id: 'usr-42',
        phone: '+251988776655',
        displayName: 'Abebe Bikila',
      );

      await tokenManager.saveTokens(
        accessToken: 'access-jwt-token-123',
        refreshToken: 'refresh-jwt-token-456',
      );
      await tokenManager.saveUserProfile(user);

      expect(tokenManager.isLoggedIn, isTrue);
      expect(tokenManager.isAuthenticated, isTrue);
      expect(tokenManager.accessToken, equals('access-jwt-token-123'));
      expect(tokenManager.refreshToken, equals('refresh-jwt-token-456'));

      final restoredUser = tokenManager.getSavedUser();
      expect(restoredUser, isNotNull);
      expect(restoredUser!.id, equals('usr-42'));
      expect(restoredUser.phone, equals('+251988776655'));
      expect(restoredUser.displayName, equals('Abebe Bikila'));
    });

    test('Setting guest mode clears isLoggedIn and persists isGuest', () async {
      await tokenManager.saveTokens(
        accessToken: 'token-abc',
        refreshToken: 'refresh-abc',
      );
      expect(tokenManager.isLoggedIn, isTrue);

      await tokenManager.setGuest(true);
      expect(tokenManager.isGuest, isTrue);
      expect(tokenManager.isLoggedIn, isFalse);

      // Re-logging in clears isGuest
      await tokenManager.saveTokens(
        accessToken: 'token-new',
        refreshToken: 'refresh-new',
      );
      expect(tokenManager.isLoggedIn, isTrue);
      expect(tokenManager.isGuest, isFalse);
    });

    test('clearAll wipes all credentials, profile, and session states', () async {
      await tokenManager.saveTokens(
        accessToken: 'token-to-clear',
        refreshToken: 'refresh-to-clear',
      );
      await tokenManager.saveUserProfile(
        User(id: '99', phone: '0900000000', displayName: 'Ghost'),
      );
      await tokenManager.setGuest(true);

      await tokenManager.clearAll();

      expect(tokenManager.accessToken, isNull);
      expect(tokenManager.refreshToken, isNull);
      expect(tokenManager.userId, isNull);
      expect(tokenManager.getSavedUser(), isNull);
      expect(tokenManager.isLoggedIn, isFalse);
      expect(tokenManager.isGuest, isFalse);
    });

    test('AuthProvider.bootstrap restores cached authenticated session immediately', () async {
      final user = User(
        id: 'user-cached',
        phone: '+251912345678',
        displayName: 'Cached Selam',
      );
      await tokenManager.saveTokens(
        accessToken: 'cached-token',
        refreshToken: 'cached-refresh',
      );
      await tokenManager.saveUserProfile(user);

      final repo = _MockAuthRepository(tokenManager);
      repo.mockUser = user;
      final auth = AuthProvider(repo);

      await auth.bootstrap();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.user?.id, equals('user-cached'));
      expect(auth.user?.displayName, equals('Cached Selam'));
    });

    test('AuthProvider.bootstrap does NOT wipe session on network errors or timeouts', () async {
      final user = User(
        id: 'user-persisted',
        phone: '+251912345678',
        displayName: 'Persistent User',
      );
      await tokenManager.saveTokens(
        accessToken: 'persisted-token',
        refreshToken: 'persisted-refresh',
      );
      await tokenManager.saveUserProfile(user);

      final repo = _MockAuthRepository(tokenManager);
      repo.fetchMeThrowsNetworkError = true; // Simulating offline / server timeout

      final auth = AuthProvider(repo);

      await auth.bootstrap();

      // Session MUST remain authenticated with local cached profile!
      expect(auth.isAuthenticated, isTrue);
      expect(auth.user?.id, equals('user-persisted'));
      expect(tokenManager.accessToken, equals('persisted-token'));
    });

    test('AuthProvider.continueAsGuest persists guest session across restarts', () async {
      final repo = _MockAuthRepository(tokenManager);
      final auth = AuthProvider(repo);

      await auth.continueAsGuest();

      expect(auth.isGuest, isTrue);
      expect(auth.isAuthenticated, isFalse);

      // Simulate app restart by creating a new AuthProvider with the same storage
      final newAuth = AuthProvider(repo);
      await newAuth.bootstrap();

      expect(newAuth.isGuest, isTrue);
      expect(newAuth.isAuthenticated, isFalse);
    });

    test('AuthProvider.logout purges persisted session returning to initial entry state', () async {
      await tokenManager.saveTokens(
        accessToken: 'token-to-logout',
        refreshToken: 'refresh-to-logout',
      );
      await tokenManager.saveUserProfile(
        User(id: 'usr-1', phone: '0911', displayName: 'Logout Tester'),
      );

      final repo = _MockAuthRepository(tokenManager);
      final auth = AuthProvider(repo);
      await auth.bootstrap();
      expect(auth.isAuthenticated, isTrue);

      await auth.logout();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.isGuest, isFalse);
      expect(auth.user, isNull);

      // On next bootstrap, remains unauthenticated
      final rebootAuth = AuthProvider(repo);
      await rebootAuth.bootstrap();
      expect(rebootAuth.isAuthenticated, isFalse);
      expect(rebootAuth.isGuest, isFalse);
    });
  });
}
