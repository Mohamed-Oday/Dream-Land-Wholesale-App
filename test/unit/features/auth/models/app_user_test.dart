import 'package:flutter_test/flutter_test.dart';
import 'package:gotrue/src/types/user.dart';
import 'package:tawzii/features/auth/models/app_user.dart';

void main() {
  group('AppUser constructor', () {
    test('stores all fields correctly', () {
      const user = AppUser(
        id: 'u1',
        businessId: 'b1',
        username: 'driver1',
        role: 'driver',
        name: 'أحمد',
      );
      expect(user.id, equals('u1'));
      expect(user.businessId, equals('b1'));
      expect(user.username, equals('driver1'));
      expect(user.role, equals('driver'));
      expect(user.name, equals('أحمد'));
      expect(user.active, isTrue);
    });
  });

  group('role checks', () {
    test('isOwner returns true for owner role', () {
      const user = AppUser(
          id: '1', businessId: 'b', username: 'u', role: 'owner', name: 'n');
      expect(user.isOwner, isTrue);
      expect(user.isAdmin, isFalse);
      expect(user.isDriver, isFalse);
    });

    test('isAdmin returns true for admin role', () {
      const user = AppUser(
          id: '1', businessId: 'b', username: 'u', role: 'admin', name: 'n');
      expect(user.isAdmin, isTrue);
      expect(user.isOwner, isFalse);
      expect(user.isDriver, isFalse);
    });

    test('isDriver returns true for driver role', () {
      const user = AppUser(
          id: '1', businessId: 'b', username: 'u', role: 'driver', name: 'n');
      expect(user.isDriver, isTrue);
      expect(user.isOwner, isFalse);
      expect(user.isAdmin, isFalse);
    });
  });

  group('rolePath', () {
    test('owner path is /owner', () {
      const user = AppUser(
          id: '1', businessId: 'b', username: 'u', role: 'owner', name: 'n');
      expect(user.rolePath, equals('/owner'));
    });

    test('admin path is /admin', () {
      const user = AppUser(
          id: '1', businessId: 'b', username: 'u', role: 'admin', name: 'n');
      expect(user.rolePath, equals('/admin'));
    });

    test('driver path is /driver', () {
      const user = AppUser(
          id: '1', businessId: 'b', username: 'u', role: 'driver', name: 'n');
      expect(user.rolePath, equals('/driver'));
    });
  });

  group('fromSupabaseUser', () {
    test('extracts all metadata fields', () {
      final supaUser = User(
        id: 'auth-123',
        appMetadata: {},
        userMetadata: {
          'role': 'owner',
          'business_id': 'biz-456',
          'name': 'محمد',
          'username': 'owner1',
        },
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        isAnonymous: false,
      );

      final appUser = AppUser.fromSupabaseUser(supaUser);
      expect(appUser.id, equals('auth-123'));
      expect(appUser.role, equals('owner'));
      expect(appUser.businessId, equals('biz-456'));
      expect(appUser.name, equals('محمد'));
      expect(appUser.username, equals('owner1'));
    });

    test('defaults to driver role when metadata missing', () {
      final supaUser = User(
        id: 'auth-789',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        isAnonymous: false,
      );

      final appUser = AppUser.fromSupabaseUser(supaUser);
      expect(appUser.role, equals('driver'));
      expect(appUser.active, isTrue);
      expect(appUser.businessId, equals(''));
      expect(appUser.username, equals(''));
      expect(appUser.name, equals(''));
    });
  });
}
