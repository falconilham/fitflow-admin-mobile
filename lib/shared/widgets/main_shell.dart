import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/providers/dashboard_providers.dart';
import '../../l10n/generated/app_localizations.dart';

import 'admin_brand_app_bar.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  int _resolveTabIndex(String location, List<_NavItemData> items) {
    String matchKey;
    if (location.startsWith(AppRoutes.dashboard)) {
      matchKey = AppRoutes.dashboard;
    } else if (location.startsWith(AppRoutes.members)) {
      matchKey = AppRoutes.members;
    } else if (location.startsWith(AppRoutes.checkin)) {
      matchKey = AppRoutes.checkin;
    } else if (location.startsWith(AppRoutes.reports) ||
        location.startsWith(AppRoutes.revenue) ||
        location.startsWith(AppRoutes.expenses) ||
        location.startsWith(AppRoutes.attendanceStats)) {
      matchKey = AppRoutes.reports;
    } else if (location.startsWith(AppRoutes.profile)) {
      matchKey = AppRoutes.profile;
    } else {
      matchKey = AppRoutes.dashboard;
    }

    final idx = items.indexWhere((i) => i.route == matchKey);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider).valueOrNull;
    final admin = authState?.admin;
    final gyms = ref.watch(myGymsProvider).valueOrNull ?? const <GymSimple>[];
    final activeFeatures = AccessControl.resolveActiveFeatures(
      admin: admin,
      gyms: gyms,
      activeGymId: authState?.activeGymId,
    );

    bool allow(String feature) => AccessControl.canAccess(
          admin: admin,
          gymFeatures: activeFeatures,
          feature: feature,
        );

    final navItems = <_NavItemData>[
      _NavItemData(
        icon: LucideIcons.home,
        label: l10n.navSummary,
        route: AppRoutes.dashboard,
      ),
      if (allow('members'))
        _NavItemData(
          icon: LucideIcons.users,
          label: l10n.navMembers,
          route: AppRoutes.members,
        ),
      if (allow('check_in'))
        _NavItemData(
          icon: LucideIcons.qrCode,
          label: l10n.navCheckIn,
          route: AppRoutes.checkin,
        ),
      if (allow('reports'))
        _NavItemData(
          icon: LucideIcons.barChart2,
          label: l10n.navReports,
          route: AppRoutes.reports,
        ),
      _NavItemData(
        icon: LucideIcons.user,
        label: l10n.navProfile,
        route: AppRoutes.profile,
      ),
    ];

    final currentIndex = _resolveTabIndex(location, navItems);
    final baseTheme = Theme.of(context);
    final shellTheme = baseTheme.copyWith(
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: AppColors.surface,
        toolbarHeight: 46,
        titleSpacing: 4,
        titleTextStyle: GoogleFonts.figtree(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        shape: const Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
    );

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const AdminBrandAppBar(),
          Expanded(
            child: Theme(
              data: shellTheme,
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _FitflowBottomNav(
        currentIndex: currentIndex,
        onTap: (idx) => context.go(navItems[idx].route),
        items: navItems,
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

class _FitflowBottomNav extends StatelessWidget {
  const _FitflowBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_NavItemData> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.tabBar,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SizedBox(
              height: 74,
              child: Row(
                children: List.generate(items.length, (i) {
                  final item = items[i];
                  final isSelected = i == currentIndex;
                  final primary = Theme.of(context).colorScheme.primary;
                  return Expanded(
                    child: InkWell(
                      onTap: () => onTap(i),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 58,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primary.withAlpha(38)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              item.icon,
                              size: 21,
                              color: isSelected
                                  ? primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.figtree(
                              fontSize: 11,
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
