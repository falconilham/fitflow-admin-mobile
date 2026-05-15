import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/utils/error_handler.dart';

class _LbParams {
  final int gymId;
  final String category;
  final String period;
  const _LbParams(this.gymId, this.category, this.period);

  @override
  bool operator ==(Object other) =>
      other is _LbParams &&
      other.gymId == gymId &&
      other.category == category &&
      other.period == period;

  @override
  int get hashCode => Object.hash(gymId, category, period);
}

final _leaderboardProvider = FutureProvider.autoDispose
    .family<List<LeaderboardEntry>, _LbParams>((ref, params) async {
  try {
    return await ref.read(apiRepositoryProvider).getLeaderboard(
          params.gymId,
          category: params.category,
          period: params.period,
        );
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
      return [];
    }
    rethrow;
  }
});

const _categories = [
  _Category('check_ins', 'Top Check-ins', Icons.event_available_rounded, 'Member', 'visits'),
  _Category('spending', 'Top Spenders', Icons.payments_rounded, 'Member', null),
  _Category('sessions', 'Top Trainers', Icons.sports_rounded, 'Trainer', 'sessions'),
  _Category('revenue', 'Trainer Revenue', Icons.attach_money_rounded, 'Trainer', null),
];

const _periods = [
  _PeriodOpt('month', 'Bulan Ini'),
  _PeriodOpt('quarter', 'Kuartal'),
  _PeriodOpt('half_year', '6 Bulan'),
  _PeriodOpt('year', 'Tahun Ini'),
];

class _Category {
  final String key;
  final String label;
  final IconData icon;
  final String group; // 'Member' or 'Trainer'
  final String? unit;
  const _Category(this.key, this.label, this.icon, this.group, this.unit);
}

class _PeriodOpt {
  final String key;
  final String label;
  const _PeriodOpt(this.key, this.label);
}

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _category = 'check_ins';
  String _period = 'month';

  _Category get _currentCategory =>
      _categories.firstWhere((c) => c.key == _category, orElse: () => _categories.first);

  @override
  Widget build(BuildContext context) {
    final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Leaderboard',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (gymId != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
              onPressed: () => ref.invalidate(
                  _leaderboardProvider(_LbParams(gymId, _category, _period))),
            ),
        ],
      ),
      body: gymId == null
          ? const Center(
              child: Text('Pilih gym terlebih dahulu',
                  style: TextStyle(color: AppColors.textMuted)))
          : Column(
              children: [
                _buildFilters(),
                Expanded(child: _buildList(gymId)),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _categories[i];
                final selected = c.key == _category;
                return ChoiceChip(
                  selected: selected,
                  showCheckmark: false,
                  avatar: Icon(c.icon,
                      size: 16, color: selected ? Colors.black : AppColors.textSecondary),
                  label: Text(c.label),
                  labelStyle: TextStyle(
                    color: selected ? Colors.black : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  backgroundColor: AppColors.card,
                  selectedColor: AppColors.accent,
                  side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
                  onSelected: (_) => setState(() => _category = c.key),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Period chips
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _periods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final p = _periods[i];
                final selected = p.key == _period;
                return ChoiceChip(
                  selected: selected,
                  showCheckmark: false,
                  label: Text(p.label),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.accent : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  backgroundColor: AppColors.card,
                  selectedColor: AppColors.accent.withAlpha(30),
                  side: BorderSide(
                      color: selected ? AppColors.accent : AppColors.border),
                  onSelected: (_) => setState(() => _period = p.key),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(int gymId) {
    final params = _LbParams(gymId, _category, _period);
    final dataAsync = ref.watch(_leaderboardProvider(params));
    final cat = _currentCategory;

    return dataAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            ErrorHandler.parse(e),
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (entries) {
        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.card,
          onRefresh: () async => ref.invalidate(_leaderboardProvider(params)),
          child: entries.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.emoji_events_outlined,
                              size: 56, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text('Belum ada data untuk periode ini',
                              style:
                                  TextStyle(color: AppColors.textMuted, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length + 1,
                  itemBuilder: (_, idx) {
                    if (idx == 0) return _buildHeader(cat);
                    final entry = entries[idx - 1];
                    return _LeaderRow(entry: entry, category: cat);
                  },
                ),
        );
      },
    );
  }

  Widget _buildHeader(_Category cat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(cat.icon, size: 22, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    )),
                const SizedBox(height: 2),
                Text('${cat.group} • Top 10',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final _Category category;
  const _LeaderRow({required this.entry, required this.category});

  @override
  Widget build(BuildContext context) {
    final rankColor = entry.rank == 1
        ? const Color(0xFFFFD700)
        : entry.rank == 2
            ? const Color(0xFFC0C0C0)
            : entry.rank == 3
                ? const Color(0xFFCD7F32)
                : AppColors.textMuted;

    final isMoney = category.key == 'spending' || category.key == 'revenue';
    final scoreText =
        isMoney ? formatCurrency(entry.score.toDouble()) : '${entry.score} ${category.unit ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.rank <= 3 ? rankColor.withAlpha(100) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 34,
            child: Center(
              child: entry.rank <= 3
                  ? Icon(Icons.emoji_events_rounded, color: rankColor, size: 24)
                  : Text(
                      '#${entry.rank}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surface,
            backgroundImage: (entry.photo != null && entry.photo!.isNotEmpty)
                ? NetworkImage(entry.photo!)
                : null,
            child: (entry.photo == null || entry.photo!.isEmpty)
                ? Text(
                    entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              entry.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Score
          Text(
            scoreText,
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
