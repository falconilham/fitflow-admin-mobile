import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_drawer.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 900;

        if (isLargeScreen) {
          return Scaffold(
            body: Row(
              children: [
                const SizedBox(
                  width: 280,
                  child: AppDrawerContent(isSidebar: true),
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(child: child),
              ],
            ),
          );
        }

        return Scaffold(
          key: scaffoldKey,
          drawer: const AppDrawer(),
          body: child,
        );
      },
    );
  }
}
