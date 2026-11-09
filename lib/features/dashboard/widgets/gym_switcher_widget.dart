import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/auth_utils.dart';
import '../../../data/models/models.dart';
import '../../auth/providers/auth_provider.dart';
import '../screens/dashboard_screen.dart';

class GymSwitcherWidget extends ConsumerWidget {
  const GymSwitcherWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGymId = ref.watch(authProvider).valueOrNull?.activeGymId;
    final gymsAsync = ref.watch(myGymsProvider);

    return gymsAsync.when(
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (List<GymSimple> gyms) {
        if (gyms.isEmpty) return const SizedBox.shrink();

        return PopupMenuButton<int>(
          icon: const Icon(Icons.store),
          tooltip: 'Pindah Cabang Gym',
          onSelected: (int selectedGymId) async {
            ref.read(authProvider.notifier).setActiveGym(selectedGymId);
            await AuthUtils.setGymId(selectedGymId.toString());
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Beralih ke cabang gym terpilih...')),
              );
            }
          },
          itemBuilder: (BuildContext context) {
            return gyms.map((gym) {
              final isCurrent = gym.id == activeGymId;
              return PopupMenuItem<int>(
                value: gym.id,
                child: Row(
                  children: [
                    Icon(
                      isCurrent ? Icons.check_circle : Icons.storefront,
                      color: isCurrent ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(gym.name),
                  ],
                ),
              );
            }).toList();
          },
        );
      },
    );
  }
}
