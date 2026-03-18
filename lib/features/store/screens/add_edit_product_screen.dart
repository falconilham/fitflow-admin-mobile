import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';

const _categories = ['Drink', 'Food', 'Supplement', 'Gear', 'Merchandise', 'Other'];

class AddEditProductScreen extends ConsumerStatefulWidget {
  const AddEditProductScreen({super.key, this.productId});
  final int? productId;
  bool get isEditing => productId != null;
  @override
  ConsumerState<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'Other';
  bool _loading = false;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _fetchProduct();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _priceCtrl.dispose(); _stockCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProduct() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() => _fetching = true);
    try {
      final products = await ref.read(apiRepositoryProvider).getProducts(gymId);
      final p = products.firstWhere((p) => p.id == widget.productId!, orElse: () => throw Exception('Produk tidak ditemukan'));
      _nameCtrl.text = p.name;
      _priceCtrl.text = p.price.toString();
      _stockCtrl.text = p.stock.toString();
      _descCtrl.text = p.description ?? '';
      setState(() { _category = p.category; _fetching = false; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat produk: $e'), backgroundColor: AppColors.error));
      setState(() => _fetching = false);
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama produk wajib diisi'))); return; }
    if (_priceCtrl.text.isEmpty || int.tryParse(_priceCtrl.text) == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harga tidak valid'))); return; }
    if (_stockCtrl.text.isEmpty || int.tryParse(_stockCtrl.text) == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok tidak valid'))); return; }
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() => _loading = true);
    try {
      final payload = {
        'gymId': gymId,
        'name': _nameCtrl.text.trim(),
        'category': _category,
        'price': int.parse(_priceCtrl.text),
        'stock': int.parse(_stockCtrl.text),
        if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
      };
      if (widget.isEditing) {
        await ref.read(apiRepositoryProvider).updateProduct(widget.productId!, payload);
      } else {
        await ref.read(apiRepositoryProvider).createProduct(payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isEditing ? 'Produk berhasil diperbarui' : 'Produk berhasil ditambahkan'),
          backgroundColor: AppColors.success,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fetching) return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Produk' : 'Tambah Produk'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('INFORMASI PRODUK', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 14),

            _label('Nama Produk *'),
            TextField(controller: _nameCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'contoh: Protein Bar')),
            const SizedBox(height: 14),

            _label('Kategori'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _categories.map((cat) {
                final active = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent.withAlpha(25) : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? AppColors.accent.withAlpha(127) : AppColors.border),
                    ),
                    child: Text(cat, style: TextStyle(color: active ? AppColors.accent : AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                );
              }).toList()),
            ),
            const SizedBox(height: 14),

            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Harga (Rp) *'),
                TextField(controller: _priceCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: '15000')),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Stok *'),
                TextField(controller: _stockCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: '50')),
              ])),
            ]),
            const SizedBox(height: 14),

            _label('Deskripsi (Opsional)'),
            TextField(controller: _descCtrl, maxLines: 3, style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Deskripsi singkat produk...')),
          ]),
        ),
        const SizedBox(height: 20),
        SizedBox(height: 52, child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : Text(widget.isEditing ? 'Simpan Perubahan' : 'Tambah Produk'),
        )),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)));
}
