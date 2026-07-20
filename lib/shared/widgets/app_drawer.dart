import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';

import '../../shared/widgets/fitflow_logo.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Drawer(
      backgroundColor: AppColors.background,
      child: AppDrawerContent(),
    );
  }
}

class AppDrawerContent extends ConsumerWidget {
  final bool isSidebar;
  const AppDrawerContent({super.key, this.isSidebar = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider).valueOrNull;
    final admin = authState?.admin;
    final gymName = admin?.gym?.name ?? admin?.gymName ?? 'FitFlow Gym';
    final location = GoRouterState.of(context).matchedLocation;

    return Column(
      children: [
        // Header
        SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.only(top: 24, bottom: 20, left: 20, right: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FitFlowLogo(fontSize: 22),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: Text(
                          admin?.name.isNotEmpty == true ? admin!.name[0].toUpperCase() : 'A',
                          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            admin?.name ?? 'Admin',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            gymName,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Menu Items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              const _DrawerSectionHeader('MAIN MENU'),
              _DrawerItem(
                icon: Icons.dashboard_rounded,
                title: 'Dashboard',
                route: AppRoutes.dashboard,
                isSidebar: isSidebar,
              ),
              
              // OPERATIONS
              _DrawerSection(
                title: 'Operations',
                icon: Icons.auto_graph_rounded,
                initiallyExpanded: location.contains(AppRoutes.checkin) || 
                                   location.contains(AppRoutes.members) || 
                                   location.contains(AppRoutes.sessions) ||
                                   location.contains(AppRoutes.classes) ||
                                   location.contains(AppRoutes.leaderboard),
                children: [
                  _DrawerItem(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Check-In',
                    route: AppRoutes.checkin,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                  _DrawerItem(
                    icon: Icons.people_rounded,
                    title: 'Members',
                    route: AppRoutes.members,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                  _DrawerItem(
                    icon: Icons.calendar_today_rounded,
                    title: 'Sessions',
                    route: AppRoutes.sessions,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                  _DrawerItem(
                    icon: Icons.groups_rounded,
                    title: 'Group Classes',
                    route: AppRoutes.classes,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                  _DrawerItem(
                    icon: Icons.emoji_events_rounded,
                    title: 'Leaderboard',
                    route: AppRoutes.leaderboard,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                ],
              ),

              // FINANCE
              _DrawerSection(
                title: 'Finance',
                icon: Icons.attach_money_rounded,
                initiallyExpanded: location.contains(AppRoutes.transactions) || 
                                   location.contains(AppRoutes.revenue) || 
                                   location.contains(AppRoutes.expenses),
                children: [
                  _DrawerItem(
                    icon: Icons.receipt_long_rounded,
                    title: 'Transactions',
                    route: AppRoutes.transactions,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                  _DrawerItem(
                    icon: Icons.bar_chart_rounded,
                    title: 'Revenue Analytics',
                    route: AppRoutes.revenue,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                  _DrawerItem(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Expenses',
                    route: AppRoutes.expenses,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                ],
              ),

              // RETAIL
              _DrawerSection(
                title: 'Retail',
                icon: Icons.shopping_bag_rounded,
                initiallyExpanded: location.contains(AppRoutes.pos) || 
                                   location.contains(AppRoutes.products),
                children: [
                  _DrawerItem(
                    icon: Icons.point_of_sale_rounded,
                    title: 'POS',
                    route: AppRoutes.pos,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                  _DrawerItem(
                    icon: Icons.inventory_2_rounded,
                    title: 'Products',
                    route: AppRoutes.products,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                ],
              ),

              // MANAGEMENT
              _DrawerSection(
                title: 'Management',
                icon: Icons.settings_rounded,
                initiallyExpanded: location.contains(AppRoutes.managers) ||
                                   location.contains(AppRoutes.trainers) ||
                                   location.contains(AppRoutes.equipment) ||
                                   location.contains(AppRoutes.reports) ||
                                   location.contains(AppRoutes.activity) ||
                                   location.contains(AppRoutes.announcements),
                children: [
                  _DrawerItem(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Managers',
                    route: AppRoutes.managers,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                  _DrawerItem(
                    icon: Icons.sports_rounded,
                    title: 'Trainers',
                    route: AppRoutes.trainers,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                  _DrawerItem(
                    icon: Icons.fitness_center_rounded,
                    title: 'Equipment',
                    route: AppRoutes.equipment,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                  _DrawerItem(
                    icon: Icons.assignment_rounded,
                    title: 'Reports',
                    route: AppRoutes.reports,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                  _DrawerItem(
                    icon: Icons.history_rounded,
                    title: 'Activity',
                    route: AppRoutes.activity,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                  _DrawerItem(
                    icon: Icons.campaign_rounded,
                    title: 'Announcements',
                    route: AppRoutes.announcements,
                    isSubItem: true,
                    isSidebar: isSidebar,
                  ),
                ],
              ),

              const _DrawerDivider(),

              // ACCOUNT
              const _DrawerSectionHeader('ACCOUNT'),
              _DrawerItem(
                icon: Icons.settings_applications_rounded,
                title: 'Gym Settings',
                route: AppRoutes.gymSettings,
                isSidebar: isSidebar,
              ),
              _DrawerItem(
                icon: Icons.person_rounded,
                title: 'Profile Settings',
                route: AppRoutes.profile,
                isSidebar: isSidebar,
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded,
                    color: AppColors.error),
                title: const Text('Logout',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  ref.read(authProvider.notifier).logout();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class _DrawerSectionHeader extends StatelessWidget {
  final String title;
  const _DrawerSectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 10, bottom: 5),
      child: Text(
        title,
        style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1),
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(color: AppColors.border, height: 1),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? route;
  final bool placeholder;
  final bool isSubItem;
  final bool isSidebar;

  const _DrawerItem({
    required this.icon,
    required this.title,
    this.route,
    this.placeholder = false,
    this.isSubItem = false,
    this.isSidebar = false,
  });

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isSelected = route != null && location.startsWith(route!);

    return ListTile(
      contentPadding: EdgeInsets.only(left: isSubItem ? 42 : 20, right: 20),
      dense: isSubItem,
      leading: Icon(
        icon,
        size: isSubItem ? 20 : 22,
        color: isSelected ? AppColors.accent : AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.accent : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontSize: isSubItem ? 13 : 14,
        ),
      ),
      tileColor: isSelected ? AppColors.accent.withAlpha(20) : null,
      onTap: () {
        if (placeholder) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title (Coming Soon)'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (route != null) {
          // Close drawer if we are in drawer mode
          if (!isSidebar) {
            Navigator.of(context).pop();
          }
          context.go(route!);
        }
      },
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _DrawerSection({
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon, color: AppColors.textSecondary, size: 22),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        iconColor: AppColors.textMuted,
        collapsedIconColor: AppColors.textMuted,
        children: children,
      ),
    );
  }
}
