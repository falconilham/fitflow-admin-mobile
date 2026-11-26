import 'package:flutter_test/flutter_test.dart';
import 'package:fitflow_admin/data/models/models.dart';

void main() {
  group('AccessControl & Feature Parsing', () {
    test('Parses Sequelize Gym & object-wrapped features cleanly', () {
      final admin = AdminInfo.fromJson({
        'id': 1,
        'name': 'Staff',
        'email': 'staff@fitflow.id',
        'role': 'admin',
        'gymId': 8,
        'permissions': ['members', 'check_in'],
        'Gym': {
          'id': 8,
          'name': 'demogym',
          'features': [
            'members',
            {'feature': 'check_in', 'isNew': true},
          ],
        },
      });

      expect(admin.gym, isNotNull);
      expect(admin.gym?.name, 'demogym');
      expect(admin.gym?.features, ['members', 'check_in']);
      expect(admin.permissions, ['members', 'check_in']);
    });

    test('Hides features missing from gym.features or admin.permissions', () {
      final staff = AdminInfo.fromJson({
        'id': 2,
        'name': 'Front Desk',
        'email': 'fd@fitflow.id',
        'role': 'admin',
        'gymId': 8,
        'permissions': ['members', 'check_in'],
        'Gym': {
          'id': 8,
          'name': 'demogym',
          'features': ['members', 'check_in', 'pos'],
        },
      });

      // Has both feature and permission
      expect(
        AccessControl.canAccess(
          admin: staff,
          gymFeatures: staff.gym?.features,
          feature: 'members',
        ),
        isTrue,
      );

      // Gym has 'pos' feature, but staff lacks 'pos' permission -> hidden
      expect(
        AccessControl.canAccess(
          admin: staff,
          gymFeatures: staff.gym?.features,
          feature: 'pos',
        ),
        isFalse,
      );

      // Gym lacks 'pt_packages' feature -> hidden even for owner
      final owner = AdminInfo(
        id: 1,
        name: 'Owner',
        email: 'owner@fitflow.id',
        role: 'owner',
        gymId: 8,
        gym: GymInfo(id: 8, name: 'demogym', features: ['members', 'check_in']),
      );

      expect(
        AccessControl.canAccess(
          admin: owner,
          gymFeatures: owner.gym?.features,
          feature: 'pt_packages',
        ),
        isFalse,
      );
      expect(
        AccessControl.canAccess(
          admin: owner,
          gymFeatures: owner.gym?.features,
          feature: 'members',
        ),
        isTrue,
      );
    });

    test('Formats roleBadgeLabel accurately for logged-in role', () {
      expect(
        AdminInfo(id: 1, name: 'A', email: 'a@b.c', role: 'owner').roleBadgeLabel,
        'OWNER',
      );
      expect(
        AdminInfo(id: 2, name: 'B', email: 'b@b.c', role: 'super_admin')
            .roleBadgeLabel,
        'SUPER ADMIN',
      );
      expect(
        AdminInfo(id: 3, name: 'C', email: 'c@b.c', role: 'sales').roleBadgeLabel,
        'SALES',
      );
      expect(
        AdminInfo(id: 4, name: 'D', email: 'd@b.c', role: 'front_desk')
            .roleBadgeLabel,
        'FRONT DESK',
      );
    });
  });
}
