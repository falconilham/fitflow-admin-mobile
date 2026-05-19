import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/checkin/screens/checkin_screen.dart';
import '../../features/members/screens/members_screen.dart';
import '../../features/members/screens/member_detail_screen.dart';
import '../../features/members/screens/add_member_screen.dart';
import '../../features/members/screens/edit_member_screen.dart';
import '../../features/members/screens/renew_member_screen.dart';
import '../../features/members/screens/import_member_screen.dart';
import '../../features/members/screens/member_history_screen.dart';
import '../../features/leaderboard/screens/leaderboard_screen.dart';
import '../../features/store/screens/pos_screen.dart';
import '../../features/store/screens/products_screen.dart';
import '../../features/store/screens/add_edit_product_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/finance/screens/transactions_screen.dart';
import '../../features/finance/screens/revenue_screen.dart';
import '../../features/finance/screens/expenses_screen.dart';
import '../../features/management/screens/managers_screen.dart';
import '../../features/management/screens/trainers_screen.dart';
import '../../features/management/screens/sessions_screen.dart';
import '../../features/management/screens/activity_screen.dart';
import '../../features/management/screens/reports_screen.dart';
import '../../features/settings/screens/gym_settings_screen.dart';
import '../../shared/widgets/main_shell.dart';
import '../../features/classes/screens/classes_screen.dart';
import '../../features/classes/screens/class_categories_screen.dart';
import '../../features/classes/screens/add_edit_class_screen.dart';
import '../../features/classes/screens/class_roster_screen.dart';


abstract class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const checkin = '/checkin';
  static const members = '/members';
  static const addMember = '/members/add';
  static const importMember = '/members/import';
  static const pos = '/pos';
  static const products = '/products';
  static const addProduct = '/products/add';
  static const profile = '/profile';
  // Finance
  static const transactions = '/transactions';
  static const revenue = '/revenue';
  static const expenses = '/expenses';
  // Management
  static const managers = '/managers';
  static const trainers = '/trainers';
  static const sessions = '/sessions';
  static const activity = '/activity';
  static const reports = '/reports';
  static const leaderboard = '/leaderboard';
  static const gymSettings = '/settings/gym';
  // Group Classes
  static const classes = '/classes';
  static const classCategories = '/classes/categories';
  static const addClass = '/classes/add';
}

// ---------------------------------------------------------------------------
// RouterNotifier — bridges Riverpod auth state → GoRouter refreshListenable
// ---------------------------------------------------------------------------
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    // Listen to every auth state change and notify GoRouter to re-evaluate
    _ref.listen<AsyncValue<AuthState>>(authProvider, (prev, next) {
      if (prev?.valueOrNull?.isAuthenticated != next.valueOrNull?.isAuthenticated ||
          prev?.isLoading != next.isLoading) {
        notifyListeners();
      }
    });
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync = _ref.read(authProvider);
    final loc = state.matchedLocation;

    // ── 1. Still loading → stay on splash (or go to splash if not there) ─
    if (authAsync.isLoading) {
      if (loc == AppRoutes.login) return null;
      return loc == AppRoutes.splash ? null : AppRoutes.splash;
    }

    final isAuthenticated = authAsync.valueOrNull?.isAuthenticated ?? false;

    // ── 2. Not authenticated → always go to login ────────────────────────
    if (!isAuthenticated) {
      // If we are on login, stay there. Otherwise (including splash), go to login.
      return loc == AppRoutes.login ? null : AppRoutes.login;
    }

    // ── 3. Authenticated but on an auth/splash page → go to dashboard ────
    if (loc == AppRoutes.login || loc == AppRoutes.splash) {
      return AppRoutes.dashboard;
    }

    // ── 4. All good, stay where we are ───────────────────────────────────
    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login,  builder: (_, __) => const LoginScreen()),

      // Main shell with bottom tab bar
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.dashboard, builder: (_, __) => const DashboardScreen()),
          GoRoute(path: AppRoutes.checkin,   builder: (_, __) => const CheckInScreen()),
          GoRoute(path: AppRoutes.members,   builder: (_, __) => const MembersScreen()),
          GoRoute(path: AppRoutes.pos,      builder: (_, __) => const PosScreen()),
          GoRoute(path: AppRoutes.products, builder: (_, __) => const ProductsScreen()),
          GoRoute(path: AppRoutes.profile,   builder: (_, __) => const ProfileScreen()),
          // Finance
          GoRoute(path: AppRoutes.transactions, builder: (_, __) => const TransactionsScreen()),
          GoRoute(path: AppRoutes.revenue,      builder: (_, __) => const RevenueScreen()),
          GoRoute(path: AppRoutes.expenses,     builder: (_, __) => const ExpensesScreen()),
          // Management
          GoRoute(path: AppRoutes.managers,  builder: (_, __) => const ManagersScreen()),
          GoRoute(path: AppRoutes.trainers,  builder: (_, __) => const TrainersScreen()),
          GoRoute(path: AppRoutes.sessions,  builder: (_, __) => const SessionsScreen()),
          GoRoute(path: AppRoutes.activity,  builder: (_, __) => const ActivityScreen()),
          GoRoute(path: AppRoutes.reports,   builder: (_, __) => const ReportsScreen()),
          GoRoute(path: AppRoutes.leaderboard, builder: (_, __) => const LeaderboardScreen()),
          GoRoute(path: AppRoutes.gymSettings, builder: (_, __) => const GymSettingsScreen()),
          GoRoute(path: AppRoutes.classes, builder: (_, __) => const ClassesScreen()),
        ],
      ),

      // Redirect old /store to /pos
      GoRoute(path: '/store', redirect: (_, __) => AppRoutes.pos),

      // Members — full screen (outside shell)
      GoRoute(path: AppRoutes.addMember,    builder: (_, __) => const AddMemberScreen()),
      GoRoute(path: AppRoutes.importMember, builder: (_, __) => const ImportMemberScreen()),
      GoRoute(
        path: '/members/:id',
        builder: (_, state) => MemberDetailScreen(
          memberId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/members/:id/edit',
        builder: (_, state) => EditMemberScreen(
          memberId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/members/:id/renew',
        builder: (_, state) => RenewMemberScreen(
          memberId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/members/:id/history',
        builder: (_, state) => MemberHistoryScreen(
          memberId: int.parse(state.pathParameters['id']!),
        ),
      ),

      // Products — full screen (outside shell)
      GoRoute(path: AppRoutes.addProduct, builder: (_, __) => const AddEditProductScreen()),
      GoRoute(
        path: '/products/:id/edit',
        builder: (_, state) => AddEditProductScreen(
          productId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),

      // Group Classes — full screen (outside shell)
      GoRoute(path: AppRoutes.classCategories, builder: (_, __) => const ClassCategoriesScreen()),
      GoRoute(path: AppRoutes.addClass, builder: (_, __) => const AddEditClassScreen()),
      GoRoute(
        path: '/classes/:id/edit',
        builder: (_, state) => AddEditClassScreen(
          classId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/classes/:id/roster',
        builder: (_, state) => ClassRosterScreen(
          classId: int.parse(state.pathParameters['id']!),
        ),
      ),
    ],
  );
});
