import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/utils/error_handler.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  List<Product> _products = [];
  bool _loading = true;

  // POS state
  final Map<int, int> _cart = {}; // productId -> qty
  String _posSearch = '';
  String _posCategory = 'All';
  bool _cartOpen = false;
  bool _checkoutOpen = false;
  String _paymentMethod = 'Cash';
  bool _processing = false;

  final _categories = ['All', 'Drink', 'Food', 'Supplement', 'Gear', 'Merchandise', 'Other'];
  final _paymentMethods = ['Cash', 'Transfer', 'QR'];

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

  // Cart helpers
  int get _cartTotal => _cart.entries.fold(0, (s, e) {
        final p = _products.firstWhere((p) => p.id == e.key,
            orElse: () => const Product(id: 0, name: '', price: 0, stock: 0, category: 'Other'));
        return s + p.price * e.value;
      });
  int get _cartCount => _cart.values.fold(0, (s, v) => s + v);

  void _addToCart(Product p) {
    if (p.stock == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p.name} kehabisan stok')));
      return;
    }
    setState(() {
      final cur = _cart[p.id] ?? 0;
      if (cur < p.stock) _cart[p.id] = cur + 1;
    });
  }

  void _updateQty(int id, int delta) {
    setState(() {
      final cur = (_cart[id] ?? 0) + delta;
      if (cur <= 0) {
        _cart.remove(id);
      } else {
        final p = _products.firstWhere((p) => p.id == id,
            orElse: () => const Product(id: 0, name: '', price: 0, stock: 0, category: 'Other'));
        _cart[id] = cur.clamp(1, p.stock);
      }
    });
  }

  Future<void> _checkout() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null || _cart.isEmpty) return;
    setState(() => _processing = true);
    try {
      await ref.read(apiRepositoryProvider).createTransaction({
        'gymId': gymId,
        'totalAmount': _cartTotal,
        'paymentMethod': _paymentMethod,
        'items': _cart.entries.map((e) {
          final p = _products.firstWhere((p) => p.id == e.key);
          return {
            'productId': p.id,
            'productName': p.name,
            'quantity': e.value,
            'priceAtSale': p.price,
            'subtotal': p.price * e.value
          };
        }).toList(),
      });
      setState(() {
        _cart.clear();
        _cartOpen = false;
        _checkoutOpen = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Transaksi selesai! Total: ${formatCurrency(_cartTotal.toDouble())}'),
            backgroundColor: AppColors.success));
        _fetch();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _products.where((p) {
      final matchSearch = p.name.toLowerCase().contains(_posSearch.toLowerCase());
      final matchCat = _posCategory == 'All' || p.category == _posCategory;
      return matchSearch && matchCat;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(leading: const DrawerMenuButton(), title: const Text('Point of Sale')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
          : Stack(children: [
              Column(children: [
                // Search
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                          hintText: 'Cari produk...',
                          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted)),
                      onChanged: (v) => setState(() => _posSearch = v),
                    )),
                // Category chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                      children: _categories.map((cat) {
                    final active = _posCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _posCategory = cat),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: active ? AppColors.accent : AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: active ? AppColors.accent : AppColors.border),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                                color: active ? Colors.black : AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    );
                  }).toList()),
                ),
                // Grid
                Expanded(
                    child: GridView.builder(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, _cartCount > 0 ? 90 : 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    final qty = _cart[p.id] ?? 0;
                    final inCart = qty > 0;
                    return GestureDetector(
                      onTap: () => _addToCart(p),
                      child: Container(
                        decoration: BoxDecoration(
                          color: inCart ? AppColors.accent.withAlpha(15) : AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: inCart ? AppColors.accent.withAlpha(127) : AppColors.border),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                              child: Container(
                            decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                image: p.imageUrl != null
                                    ? DecorationImage(image: NetworkImage(p.imageUrl!), fit: BoxFit.cover)
                                    : null),
                            child: p.imageUrl == null
                                ? const Center(child: Text('📦', style: TextStyle(fontSize: 32)))
                                : null,
                          )),
                          Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                Text(
                                    'Rp ${p.price.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]}.")}',
                                    style: const TextStyle(
                                        color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text('Stok: ${p.stock}',
                                      style: TextStyle(
                                          color: p.stock <= 5 ? AppColors.error : AppColors.textMuted, fontSize: 11)),
                                  if (inCart)
                                    Container(
                                        width: 22,
                                        height: 22,
                                        decoration:
                                            const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                                        child: Center(
                                            child: Text('$qty',
                                                style: const TextStyle(
                                                    color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)))),
                                ]),
                              ])),
                        ]),
                      ),
                    );
                  },
                )),
              ]),

              // Cart FAB
              if (_cartCount > 0)
                Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () => setState(() => _cartOpen = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(14)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('🛒 $_cartCount item · ${formatCurrency(_cartTotal.toDouble())}',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                          const Icon(Icons.chevron_right_rounded, color: Colors.black, size: 24),
                        ]),
                      ),
                    )),

              // Cart sheet
              if (_cartOpen)
                GestureDetector(
                  onTap: () => setState(() => _cartOpen = false),
                  child: Container(color: Colors.black.withAlpha(127)),
                ),
              if (_cartOpen)
                Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          border: Border(top: BorderSide(color: AppColors.border))),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Keranjang',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        ...(_cart.entries.map((e) {
                          final p = _products.firstWhere((p) => p.id == e.key);
                          return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(children: [
                                Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(p.name,
                                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                                  Text(formatCurrency(p.price.toDouble()),
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                ])),
                                Row(children: [
                                  _QtyBtn(label: '−', onTap: () => _updateQty(p.id, -1)),
                                  Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('${e.value}',
                                          style: const TextStyle(
                                              color: AppColors.textPrimary, fontWeight: FontWeight.w700))),
                                  _QtyBtn(label: '+', onTap: () => _updateQty(p.id, 1)),
                                ]),
                              ]));
                        })),
                        const Divider(color: AppColors.border),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Total',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(formatCurrency(_cartTotal.toDouble()),
                              style: const TextStyle(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () => setState(() {
                                _cartOpen = false;
                                _checkoutOpen = true;
                              }),
                              child: const Text('Bayar Sekarang'),
                            )),
                      ]),
                    )),

              // Checkout modal
              if (_checkoutOpen)
                GestureDetector(
                    onTap: () {
                      if (!_processing) setState(() => _checkoutOpen = false);
                    },
                    child: Container(color: Colors.black.withAlpha(153))),
              if (_checkoutOpen)
                Center(
                    child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Konfirmasi Pembayaran',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                      Text(formatCurrency(_cartTotal.toDouble()),
                          style: const TextStyle(color: AppColors.accent, fontSize: 22, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 16),
                    const Text('Metode Pembayaran', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(
                        children: _paymentMethods.map((m) {
                      final active = _paymentMethod == m;
                      return Expanded(
                          child: GestureDetector(
                        onTap: () => setState(() => _paymentMethod = m),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: active ? AppColors.accent.withAlpha(25) : AppColors.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: active ? AppColors.accent.withAlpha(127) : AppColors.border),
                          ),
                          child: Center(
                              child: Text(m,
                                  style: TextStyle(
                                      color: active ? AppColors.accent : AppColors.textMuted,
                                      fontWeight: FontWeight.w600))),
                        ),
                      ));
                    }).toList()),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textMuted, side: const BorderSide(color: AppColors.border)),
                        onPressed: _processing ? null : () => setState(() => _checkoutOpen = false),
                        child: const Text('Batal'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _processing ? null : _checkout,
                            child: _processing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : const Text('Konfirmasi'),
                          )),
                    ]),
                  ]),
                )),
            ]),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8)),
          child: Center(
              child: Text(label,
                  style:
                      const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)))));
}
