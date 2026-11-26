import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/router/app_router.dart';

const _bottomNavRoots = <String>{
  AppRoutes.dashboard,
  AppRoutes.members,
  AppRoutes.checkin,
  AppRoutes.reports,
  AppRoutes.profile,
};

class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (_bottomNavRoots.contains(location)) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(LucideIcons.arrowLeft, size: 22),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.dashboard);
        }
      },
    );
  }
}
