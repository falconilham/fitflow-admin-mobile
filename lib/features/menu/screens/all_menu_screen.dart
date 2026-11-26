import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/updater/app_updater_service.dart';
import '../../../data/models/models.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/dashboard/providers/dashboard_providers.dart';
import '../../../features/notifications/providers/notifications_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

class AllMenuScreen extends ConsumerStatefulWidget {
  const AllMenuScreen({super.key});

  @override
  ConsumerState<AllMenuScreen> createState() => _AllMenuScreenState();
}

class _AllMenuScreenState extends ConsumerState<AllMenuScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _appVersion = '';
  final Set<String> _expandedParents = {'operations'};

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final v = await AppUpdaterService.getSemVerVersion();
    if (mounted) setState(() => _appVersion = v);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleParent(String key) {
    setState(() {
      if (_expandedParents.contains(key)) {
        _expandedParents.remove(key);
      } else {
        _expandedParents.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider).valueOrNull;
    final admin = authState?.admin;
    final activeGymId = authState?.activeGymId;
    final gyms = ref.watch(myGymsProvider).valueOrNull ?? const <GymSimple>[];
    final gymSettings = ref.watch(activeGymSettingsProvider).valueOrNull;
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    final activeGymName = gyms
        .firstWhere(
          (g) => g.id == activeGymId,
          orElse: () => GymSimple(
            id: activeGymId ?? 0,
            name: admin?.gym?.name ?? l10n.activeBranchDefault,
          ),
        )
        .name;

    final branchSubtitle = (gymSettings?.address ?? '').trim().isNotEmpty
        ? gymSettings!.address!.trim()
        : l10n.branchManagementHint;

    final activeFeatures = AccessControl.resolveActiveFeatures(
      admin: admin,
      gyms: gyms,
      activeGymId: activeGymId,
    );

    bool allow({
      String? feature,
      String? permission,
      List<String>? roles,
    }) =>
        AccessControl.canAccess(
          admin: admin,
          gymFeatures: activeFeatures,
          feature: feature,
          permission: permission,
          roles: roles,
        );

    final mainItems = <_MenuItemSpec>[
      if (allow(feature: 'dashboard'))
        _MenuItemSpec(
          icon: LucideIcons.layoutDashboard,
          label: l10n.menuDashboard,
          onTap: () => context.go(AppRoutes.dashboard),
        ),
      _MenuItemSpec(
        icon: LucideIcons.bell,
        label: l10n.menuNotifications,
        badgeCount: unreadCount,
        onTap: () => context.push(AppRoutes.notifications),
      ),
    ];

    final rawParents = <_ParentMenuSpec>[
      _ParentMenuSpec(
        key: 'operations',
        icon: LucideIcons.activity,
        title: l10n.menuSectionOperational,
        items: [
          if (allow(feature: 'check_in'))
            _MenuItemSpec(
              icon: LucideIcons.qrCode,
              label: l10n.menuCheckIn,
              onTap: () => context.go(AppRoutes.checkin),
            ),
          if (allow(feature: 'members'))
            _MenuItemSpec(
              icon: LucideIcons.users,
              label: l10n.menuMember,
              onTap: () => context.go(AppRoutes.members),
            ),
          if (allow(feature: 'sessions'))
            _MenuItemSpec(
              icon: LucideIcons.calendarDays,
              label: l10n.menuSessions,
              onTap: () => context.push(AppRoutes.sessions),
            ),
          if (allow(feature: 'classes'))
            _MenuItemSpec(
              icon: LucideIcons.users2,
              label: l10n.menuClasses,
              onTap: () => context.push(AppRoutes.classes),
            ),
        ],
      ),
      _ParentMenuSpec(
        key: 'sales_packages',
        icon: LucideIcons.shoppingBag,
        title: l10n.menuSectionSalesPackages,
        items: [
          if (allow(
            feature: 'members',
            roles: const ['owner', 'super_admin', 'admin', 'sales'],
          ))
            _MenuItemSpec(
              icon: LucideIcons.userPlus,
              label: l10n.menuLeads,
              onTap: () => context.push(AppRoutes.leads),
            ),
          if (allow(
            feature: 'memberships',
            roles: const ['owner', 'super_admin', 'admin', 'sales'],
          ))
            _MenuItemSpec(
              icon: LucideIcons.layers,
              label: l10n.menuMembershipPackages,
              onTap: () => context.push(AppRoutes.memberships),
            ),
          if (allow(
            feature: 'pt_packages',
            roles: const ['owner', 'super_admin', 'admin', 'sales'],
          ))
            _MenuItemSpec(
              icon: LucideIcons.userCheck,
              label: l10n.menuPtPackages,
              onTap: () => context.push(AppRoutes.ptPackages),
            ),
          if (allow(
            feature: 'addon_services',
            roles: const ['owner', 'super_admin', 'admin', 'sales'],
          ))
            _MenuItemSpec(
              icon: LucideIcons.packagePlus,
              label: l10n.menuAddonServices,
              onTap: () => context.push(AppRoutes.addonServices),
            ),
          if (allow(
            feature: 'promotions',
            roles: const ['owner', 'super_admin', 'admin'],
          ))
            _MenuItemSpec(
              icon: LucideIcons.ticket,
              label: l10n.menuPromotions,
              onTap: () => context.push(AppRoutes.promotions),
            ),
          if (allow(feature: 'pos'))
            _MenuItemSpec(
              icon: LucideIcons.monitor,
              label: l10n.menuPos,
              onTap: () => context.push(AppRoutes.pos),
            ),
          if (allow(feature: 'pos', permission: 'products'))
            _MenuItemSpec(
              icon: LucideIcons.package,
              label: l10n.menuProduct,
              onTap: () => context.push(AppRoutes.products),
            ),
        ],
      ),
      _ParentMenuSpec(
        key: 'finance',
        icon: LucideIcons.receipt,
        title: l10n.menuSectionFinance,
        items: [
          if (allow(feature: 'finance'))
            _MenuItemSpec(
              icon: LucideIcons.receipt,
              label: l10n.menuTransactions,
              onTap: () => context.push(AppRoutes.transactions),
            ),
          if (allow(feature: 'finance'))
            _MenuItemSpec(
              icon: LucideIcons.banknote,
              label: l10n.menuCashShifts,
              onTap: () => context.push(AppRoutes.cashShifts),
            ),
          if (allow(feature: 'finance'))
            _MenuItemSpec(
              icon: LucideIcons.barChart3,
              label: l10n.menuRevenue,
              onTap: () => context.push(AppRoutes.revenue),
            ),
          if (allow(feature: 'expenses'))
            _MenuItemSpec(
              icon: LucideIcons.dollarSign,
              label: l10n.menuExpenses,
              onTap: () => context.push(AppRoutes.expenses),
            ),
          if (allow(
            feature: 'payroll',
            roles: const ['owner', 'super_admin', 'admin'],
          ))
            _MenuItemSpec(
              icon: LucideIcons.wallet,
              label: l10n.menuPayroll,
              onTap: () => context.push(AppRoutes.payroll),
            ),
          if (allow(
            feature: 'payroll',
            roles: const ['owner', 'super_admin', 'admin'],
          ))
            _MenuItemSpec(
              icon: LucideIcons.fileText,
              label: l10n.menuPayslips,
              onTap: () => context.push(AppRoutes.payslips),
            ),
          if (allow(feature: 'reports'))
            _MenuItemSpec(
              icon: LucideIcons.barChart2,
              label: l10n.menuReports,
              onTap: () => context.go(AppRoutes.reports),
            ),
          if (allow(
            feature: 'payment_gateway',
            roles: const ['owner', 'super_admin'],
          ))
            _MenuItemSpec(
              icon: LucideIcons.creditCard,
              label: l10n.menuPaymentGateway,
              onTap: () => context.push(AppRoutes.paymentGateway),
            ),
        ],
      ),
      if (allow(roles: const ['owner', 'super_admin', 'admin']))
        _ParentMenuSpec(
          key: 'staff_team',
          icon: LucideIcons.users,
          title: l10n.menuSectionStaffTeam,
          items: [
            if (allow(
              feature: 'staff',
              roles: const ['owner', 'super_admin', 'admin'],
            ))
              _MenuItemSpec(
                icon: LucideIcons.shieldCheck,
                label: l10n.menuManagers,
                onTap: () => context.push(AppRoutes.managers),
              ),
            if (allow(feature: 'trainers'))
              _MenuItemSpec(
                icon: LucideIcons.userCheck,
                label: l10n.menuTrainer,
                onTap: () => context.push(AppRoutes.trainers),
              ),
            if (allow(feature: 'staff'))
              _MenuItemSpec(
                icon: LucideIcons.clipboardList,
                label: l10n.menuStaffAttendance,
                onTap: () => context.push(AppRoutes.staffAttendance),
              ),
            if (allow(feature: 'staff'))
              _MenuItemSpec(
                icon: LucideIcons.calendarClock,
                label: l10n.menuStaffSchedules,
                onTap: () => context.push(AppRoutes.staffSchedules),
              ),
            if (allow(feature: 'staff'))
              _MenuItemSpec(
                icon: LucideIcons.pieChart,
                label: l10n.menuAttendanceStats,
                onTap: () => context.push(AppRoutes.attendanceStats),
              ),
          ],
        ),
      if (allow(roles: const ['owner', 'super_admin', 'admin', 'sales']))
        _ParentMenuSpec(
          key: 'marketing_community',
          icon: LucideIcons.megaphone,
          title: l10n.menuSectionMarketing,
          items: [
            if (allow(feature: 'leaderboard'))
              _MenuItemSpec(
                icon: LucideIcons.trophy,
                label: l10n.menuLeaderboard,
                onTap: () => context.push(AppRoutes.leaderboard),
              ),
            if (allow(feature: 'announcements'))
              _MenuItemSpec(
                icon: LucideIcons.megaphone,
                label: l10n.menuAnnouncements,
                onTap: () => context.push(AppRoutes.announcements),
              ),
          ],
        ),
      _ParentMenuSpec(
        key: 'system_assets',
        icon: LucideIcons.dumbbell,
        title: l10n.menuSectionSystemAssets,
        items: [
          if (allow(feature: 'equipment'))
            _MenuItemSpec(
              icon: LucideIcons.dumbbell,
              label: l10n.menuEquipment,
              onTap: () => context.push(AppRoutes.equipment),
            ),
          if (allow(feature: 'activity'))
            _MenuItemSpec(
              icon: LucideIcons.activity,
              label: l10n.menuActivity,
              onTap: () => context.push(AppRoutes.activity),
            ),
        ],
      ),
    ];

    final parentMenus = rawParents.where((p) => p.items.isNotEmpty).toList();

    final accountItems = <_MenuItemSpec>[
      if (allow(permission: 'settings'))
        _MenuItemSpec(
          icon: LucideIcons.slidersHorizontal,
          label: l10n.menuSettings,
          onTap: () => context.push(AppRoutes.gymSettings),
        ),
      _MenuItemSpec(
        icon: LucideIcons.user,
        label: l10n.menuProfile,
        onTap: () => context.go(AppRoutes.profile),
      ),
      _MenuItemSpec(
        icon: LucideIcons.helpCircle,
        label: l10n.menuHelpCenter,
        onTap: () => context.push(AppRoutes.helpCenter),
      ),
      _MenuItemSpec(
        icon: LucideIcons.logOut,
        label: l10n.logoutAction,
        iconColor: AppColors.error,
        labelColor: AppColors.error,
        onTap: () => ref.read(authProvider.notifier).logout(),
      ),
    ];

    final q = _query.trim().toLowerCase();
    final filteredMain = q.isEmpty
        ? mainItems
        : mainItems.where((i) => i.label.toLowerCase().contains(q)).toList();

    final filteredParents = q.isEmpty
        ? parentMenus
        : parentMenus
            .map((p) {
              if (p.title.toLowerCase().contains(q)) return p;
              final matched = p.items
                  .where((i) => i.label.toLowerCase().contains(q))
                  .toList();
              return _ParentMenuSpec(
                key: p.key,
                icon: p.icon,
                title: p.title,
                items: matched,
              );
            })
            .where((p) => p.items.isNotEmpty)
            .toList();

    final filteredAccount = q.isEmpty
        ? accountItems
        : accountItems.where((i) => i.label.toLowerCase().contains(q)).toList();

    final hasAnyResult = filteredMain.isNotEmpty ||
        filteredParents.isNotEmpty ||
        filteredAccount.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(l10n.allMenuTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          Text(
            l10n.allMenuSubtitle,
                  style: GoogleFonts.figtree(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 18),

                // ── Search Box ──────────────────────────────────────────────
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    style: GoogleFonts.figtree(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      hintText: l10n.searchMenuHint,
                      hintStyle: GoogleFonts.figtree(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        LucideIcons.search,
                        size: 19,
                        color: AppColors.textSecondary,
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                LucideIcons.x,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                if (!hasAnyResult)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        l10n.menuSearchEmpty,
                        style: GoogleFonts.figtree(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                // ── MAIN MENU ───────────────────────────────────────────────
                if (filteredMain.isNotEmpty || filteredParents.isNotEmpty) ...[
                  Text(
                    l10n.menuSectionMain,
                    style: GoogleFonts.figtree(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (filteredMain.isNotEmpty) ...[
                    _MenuGrid(items: filteredMain),
                    const SizedBox(height: 16),
                  ],
                  for (final parent in filteredParents) ...[
                    _CollapsibleParentCard(
                      spec: parent,
                      isExpanded: q.isNotEmpty ||
                          _expandedParents.contains(parent.key),
                      onToggle: () => _toggleParent(parent.key),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                ],

                // ── ACCOUNT ─────────────────────────────────────────────────
                if (filteredAccount.isNotEmpty) ...[
                  Text(
                    l10n.menuSectionAccount,
                    style: GoogleFonts.figtree(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MenuGrid(items: filteredAccount),
                  const SizedBox(height: 24),
                ],

                // ── Active Branch Switcher Card ─────────────────────────────
                InkWell(
                  onTap: gyms.isNotEmpty
                      ? () => showGymSwitcherBottomSheet(
                            context,
                            ref,
                            gyms,
                            activeGymId,
                          )
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.home,
                          size: 20,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeGymName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.figtree(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                branchSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.figtree(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          LucideIcons.chevronDown,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_appVersion.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.sparkles,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'FitFlow Admin $_appVersion',
                            style: GoogleFonts.figtree(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => AppUpdaterService.checkForUpdates(
                            context,
                            isManual: true,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.iconSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              l10n.menuCheckUpdate,
                              style: GoogleFonts.figtree(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
        ],
      ),
    );
  }
}

class _ParentMenuSpec {
  const _ParentMenuSpec({
    required this.key,
    required this.icon,
    required this.title,
    required this.items,
  });

  final String key;
  final IconData icon;
  final String title;
  final List<_MenuItemSpec> items;
}

class _CollapsibleParentCard extends StatelessWidget {
  const _CollapsibleParentCard({
    required this.spec,
    required this.isExpanded,
    required this.onToggle,
  });

  final _ParentMenuSpec spec;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? AppColors.accent.withAlpha(70)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? AppColors.accentTint
                          : AppColors.iconSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      spec.icon,
                      size: 18,
                      color: isExpanded
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      spec.title,
                      style: GoogleFonts.figtree(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.iconSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      spec.items.length.toString(),
                      style: GoogleFonts.figtree(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 18,
                    color: isExpanded
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
                  child: _MenuGrid(items: spec.items),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItemSpec {
  const _MenuItemSpec({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;
  final Color? iconColor;
  final Color? labelColor;
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.items});

  final List<_MenuItemSpec> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 720 ? 4 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
            mainAxisExtent: 86,
          ),
      itemBuilder: (_, index) {
        final item = items[index];
        return InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.iconSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      item.icon,
                      size: 22,
                      color: item.iconColor ?? AppColors.accent,
                    ),
                  ),
                  if (item.badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.badgeCount > 99
                              ? '99+'
                              : item.badgeCount.toString(),
                          style: GoogleFonts.figtree(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(
                  color: item.labelColor ?? AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
        );
      },
    );
  }
}
