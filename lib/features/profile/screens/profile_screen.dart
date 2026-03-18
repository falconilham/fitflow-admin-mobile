import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(authProvider).valueOrNull?.admin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(leading: const DrawerMenuButton(), title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: Column(children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.accent.withAlpha(38),
              child: Text(
                (admin?.name != null && admin!.name.isNotEmpty)
                    ? admin.name[0].toUpperCase()
                    : 'A',
                style: const TextStyle(color: AppColors.accent,
                    fontWeight: FontWeight.w800, fontSize: 28),
              ),
            ),
            const SizedBox(height: 12),
            Text(admin?.name ?? '-',
                style: const TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                admin?.isOwner == true ? 'Owner' : 'Admin',
                style: const TextStyle(color: AppColors.accent,
                    fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 28),
        Container(
          decoration: BoxDecoration(color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border)),
          child: Column(children: [
            _InfoTile(icon: Icons.email_outlined, label: 'Email',
                value: admin?.email ?? '-'),
            const Divider(height: 1, color: AppColors.border),
            _InfoTile(icon: Icons.fitness_center_rounded, label: 'Gym',
                value: admin?.gym?.name ?? admin?.gymName ?? '-'),
            const Divider(height: 1, color: AppColors.border),
            _InfoTile(icon: Icons.badge_outlined, label: 'Role',
                value: admin?.isOwner == true ? 'Owner' : 'Admin'),
          ]),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            label: const Text('Logout', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error)),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppColors.card,
                  title: const Text('Logout',
                      style: TextStyle(color: AppColors.textPrimary)),
                  content: const Text('Yakin ingin keluar?',
                      style: TextStyle(color: AppColors.textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal')),
                    TextButton(onPressed: () => Navigator.pop(context, true),
                        child: const Text('Logout',
                            style: TextStyle(color: AppColors.error))),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(authProvider.notifier).logout();
              }
            },
          ),
        ),
      ]),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: AppColors.textPrimary,
              fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }
}
