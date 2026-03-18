import 'package:flutter/material.dart';

import 'main_shell.dart';

class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show the hamburger button on smaller screens where the drawer is hidden
    return LayoutBuilder(builder: (context, constraints) {
      // In AppBar, constraints usually won't give us the full screen width.
      // So we use MediaQuery to check the total window size.
      final isLargeScreen = MediaQuery.of(context).size.width > 900;
      
      if (isLargeScreen) {
        return const SizedBox.shrink(); // Hide button on large screens where sidebar is permanent
      }

      return IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () {
          MainShell.scaffoldKey.currentState?.openDrawer();
        },
      );
    });
  }
}
