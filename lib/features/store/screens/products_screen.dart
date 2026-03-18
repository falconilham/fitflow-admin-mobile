import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/drawer_menu_button.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String _prodSearch = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final products = await ref.read(apiRepositoryProvider).getProducts(gymId);
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteProduct(Product p) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: AppColors.card,
              title: const Text('Hapus Produk', style: TextStyle(color: AppColors.textPrimary)),
              content: Text('Hapus "${p.name}" dari inventori?',
                  style: const TextStyle(color: AppColors.textSecondary)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Hapus', style: TextStyle(color: AppColors.error))),
              ],
            ));
    if (confirm != true) return;
    try {
      await ref.read(apiRepositoryProvider).deleteProduct(p.id);
      _fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _products
        .where((p) =>
            p.name.toLowerCase().contains(_prodSearch.toLowerCase()) ||
            p.category.toLowerCase().contains(_prodSearch.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(leading: const DrawerMenuButton(), title: const Text('Products')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              Expanded(
                  child: TextField(
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    hintText: 'Cari produk...',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted)),
                onChanged: (v) => setState(() => _prodSearch = v),
              )),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Tambah'),
                  onPressed: () =>
                      context.push(AppRoutes.addProduct).then((_) => _fetch())),
            ])),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
              : filtered.isEmpty
                  ? Center(
                      child: Text(
                          _products.isEmpty
                              ? 'Belum ada produk. Tambah produk pertama!'
                              : 'Tidak ada produk yang cocok.',
                          style: const TextStyle(color: AppColors.textMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final p = filtered[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border)),
                          child: Row(children: [
                            Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    image: p.imageUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(p.imageUrl!), fit: BoxFit.cover)
                                        : null),
                                child: p.imageUrl == null ? const Center(child: Text('📦')) : null),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p.name,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(p.category,
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              Text(
                                  'Rp ${p.price.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]}.")}',
                                  style: const TextStyle(
                                      color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('Stok: ${p.stock}',
                                  style: TextStyle(
                                      color: p.stock <= 5 ? AppColors.error : AppColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Row(children: [
                                _SmallBtn(
                                    label: 'Edit',
                                    color: AppColors.accent,
                                    onTap: () => context.push('/store/${p.id}/edit').then((_) => _fetch())),
                                const SizedBox(width: 6),
                                _SmallBtn(
                                    label: 'Hapus',
                                    color: AppColors.error,
                                    onTap: () => _deleteProduct(p)),
                              ]),
                            ]),
                          ]),
                        );
                      }),
        ),
      ]),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  const _SmallBtn({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color)),
          child: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12))));
}
