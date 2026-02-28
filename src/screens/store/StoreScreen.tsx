import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  TextInput,
  FlatList,
  ScrollView,
  Modal,
  ActivityIndicator,
  Alert,
  Image,
} from 'react-native';
import { useFocusEffect, useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useAppSelector } from '../../store/hooks';
import {
  getPosProductsApi,
  createTransactionApi,
  deleteProductApi,
} from '../../api/endpoints';
import { formatCurrency } from '../../utils/format';
import { StoreStackParamList } from '../../navigation/types';

type NavProp = NativeStackNavigationProp<StoreStackParamList>;

const CATEGORIES = [
  'All',
  'Drink',
  'Food',
  'Supplement',
  'Gear',
  'Merchandise',
  'Other',
];
const PAYMENT_METHODS = ['Cash', 'Transfer', 'QR'] as const;
type PaymentMethod = 'Cash' | 'Transfer' | 'QR';

interface Product {
  id: number;
  name: string;
  price: number;
  stock: number;
  category: string;
  image?: string;
  description?: string;
}

interface CartItem extends Product {
  quantity: number;
}

export default function StoreScreen() {
  const navigation = useNavigation<NavProp>();
  const { activeGymId } = useAppSelector(state => state.auth);
  const [activeTab, setActiveTab] = useState<'pos' | 'products'>('pos');

  // Shared state
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);

  // POS state
  const [cart, setCart] = useState<CartItem[]>([]);
  const [posSearch, setPosSearch] = useState('');
  const [posCategory, setPosCategory] = useState('All');
  const [cartOpen, setCartOpen] = useState(false);
  const [checkoutOpen, setCheckoutOpen] = useState(false);
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>('Cash');
  const [processing, setProcessing] = useState(false);

  // Products state
  const [prodSearch, setProdSearch] = useState('');

  const fetchProducts = useCallback(async () => {
    if (!activeGymId) return;
    setLoading(true);
    try {
      const res = await getPosProductsApi(activeGymId);
      setProducts(res.data?.data ?? res.data ?? []);
    } catch {
      Alert.alert('Error', 'Gagal memuat produk');
    } finally {
      setLoading(false);
    }
  }, [activeGymId]);

  useFocusEffect(
    useCallback(() => {
      fetchProducts();
    }, [fetchProducts]),
  );

  // Cart logic
  const addToCart = (product: Product) => {
    if (product.stock === 0) {
      Alert.alert('Stok habis', `${product.name} kehabisan stok`);
      return;
    }
    setCart(prev => {
      const existing = prev.find(i => i.id === product.id);
      if (existing) {
        if (existing.quantity >= product.stock) {
          Alert.alert('Stok terbatas', `Maksimal ${product.stock} item`);
          return prev;
        }
        return prev.map(i =>
          i.id === product.id ? { ...i, quantity: i.quantity + 1 } : i,
        );
      }
      return [...prev, { ...product, quantity: 1 }];
    });
  };

  const updateQty = (id: number, delta: number) => {
    setCart(prev => {
      return prev.map(i => {
        if (i.id !== id) return i;
        const newQty = i.quantity + delta;
        if (newQty <= 0) return i;
        const product = products.find(p => p.id === id);
        if (product && newQty > product.stock) return i;
        return { ...i, quantity: newQty };
      });
    });
  };

  const removeFromCart = (id: number) =>
    setCart(prev => prev.filter(i => i.id !== id));

  const cartTotal = cart.reduce((s, i) => s + i.price * i.quantity, 0);
  const cartCount = cart.reduce((s, i) => s + i.quantity, 0);

  const handleCheckout = async () => {
    if (!activeGymId || cart.length === 0) return;
    setProcessing(true);
    try {
      await createTransactionApi({
        gymId: activeGymId,
        totalAmount: cartTotal,
        paymentMethod,
        items: cart.map(i => ({
          productId: i.id,
          productName: i.name,
          quantity: i.quantity,
          priceAtSale: i.price,
          subtotal: i.price * i.quantity,
        })),
      });
      setCart([]);
      setCheckoutOpen(false);
      setCartOpen(false);
      Alert.alert(
        'Berhasil',
        `Transaksi selesai!\nTotal: ${formatCurrency(cartTotal)}`,
      );
      fetchProducts();
    } catch (e: any) {
      Alert.alert('Error', e?.response?.data?.error ?? 'Transaksi gagal');
    } finally {
      setProcessing(false);
    }
  };

  const handleDeleteProduct = (product: Product) => {
    Alert.alert('Hapus Produk', `Hapus "${product.name}" dari inventori?`, [
      { text: 'Batal', style: 'cancel' },
      {
        text: 'Hapus',
        style: 'destructive',
        onPress: async () => {
          try {
            await deleteProductApi(product.id);
            fetchProducts();
          } catch {
            Alert.alert('Error', 'Gagal menghapus produk');
          }
        },
      },
    ]);
  };

  // Filtered lists
  const filteredPos = products.filter(p => {
    const matchSearch = p.name.toLowerCase().includes(posSearch.toLowerCase());
    const matchCat = posCategory === 'All' || p.category === posCategory;
    return matchSearch && matchCat;
  });

  const filteredProd = products.filter(
    p =>
      p.name.toLowerCase().includes(prodSearch.toLowerCase()) ||
      p.category.toLowerCase().includes(prodSearch.toLowerCase()),
  );

  return (
    <View style={styles.container}>
      {/* Segmented Control */}
      <View style={styles.segmentRow}>
        <TouchableOpacity
          style={[
            styles.segmentBtn,
            activeTab === 'pos' && styles.segmentBtnActive,
          ]}
          onPress={() => setActiveTab('pos')}
        >
          <Text
            style={[
              styles.segmentText,
              activeTab === 'pos' && styles.segmentTextActive,
            ]}
          >
            🛒 POS
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[
            styles.segmentBtn,
            activeTab === 'products' && styles.segmentBtnActive,
          ]}
          onPress={() => setActiveTab('products')}
        >
          <Text
            style={[
              styles.segmentText,
              activeTab === 'products' && styles.segmentTextActive,
            ]}
          >
            📦 Produk
          </Text>
        </TouchableOpacity>
      </View>

      {/* ── POS VIEW ── */}
      {activeTab === 'pos' && (
        <View style={styles.flexOne}>
          {/* Search */}
          <View style={styles.searchRow}>
            <TextInput
              style={styles.searchInput}
              placeholder="Cari produk..."
              placeholderTextColor="#666"
              value={posSearch}
              onChangeText={setPosSearch}
            />
          </View>

          {/* Category chips */}
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            style={styles.chipScroll}
            contentContainerStyle={styles.chipContent}
          >
            {CATEGORIES.map(cat => (
              <TouchableOpacity
                key={cat}
                style={[styles.chip, posCategory === cat && styles.chipActive]}
                onPress={() => setPosCategory(cat)}
              >
                <Text
                  style={[
                    styles.chipText,
                    posCategory === cat && styles.chipTextActive,
                  ]}
                >
                  {cat}
                </Text>
              </TouchableOpacity>
            ))}
          </ScrollView>

          {/* Product grid */}
          {loading ? (
            <View style={styles.centered}>
              <ActivityIndicator color="#C8F000" size="large" />
            </View>
          ) : (
            <FlatList
              data={filteredPos}
              keyExtractor={item => String(item.id)}
              numColumns={2}
              columnWrapperStyle={styles.gridColumnWrapper}
              contentContainerStyle={[
                styles.gridContent,
                cartCount > 0
                  ? styles.gridContentWithCart
                  : styles.gridContentNoCart,
              ]}
              renderItem={({ item }) => {
                const inCart = cart.find(c => c.id === item.id);
                return (
                  <TouchableOpacity
                    style={[
                      styles.productCard,
                      inCart && styles.productCardInCart,
                    ]}
                    onPress={() => addToCart(item)}
                    activeOpacity={0.8}
                  >
                    {item.image ? (
                      <Image
                        source={{ uri: item.image }}
                        style={styles.productImg}
                      />
                    ) : (
                      <View style={styles.productImgPlaceholder}>
                        <Text style={styles.productImgEmoji}>📦</Text>
                      </View>
                    )}
                    <Text style={styles.productName} numberOfLines={2}>
                      {item.name}
                    </Text>
                    <Text style={styles.productPrice}>
                      {formatCurrency(item.price)}
                    </Text>
                    <View style={styles.productFooter}>
                      <Text
                        style={[
                          styles.productStock,
                          item.stock <= 5 && styles.stockLow,
                        ]}
                      >
                        Stok: {item.stock}
                      </Text>
                      {inCart && (
                        <View style={styles.inCartBadge}>
                          <Text style={styles.inCartBadgeText}>
                            {inCart.quantity}
                          </Text>
                        </View>
                      )}
                    </View>
                  </TouchableOpacity>
                );
              }}
              ListEmptyComponent={
                <Text style={styles.emptyText}>
                  {products.length === 0
                    ? 'Belum ada produk. Tambah di tab Produk.'
                    : 'Tidak ada produk yang cocok.'}
                </Text>
              }
            />
          )}

          {/* Cart FAB */}
          {cartCount > 0 && (
            <TouchableOpacity
              style={styles.cartFab}
              onPress={() => setCartOpen(true)}
            >
              <Text style={styles.cartFabText}>
                🛒 {cartCount} item · {formatCurrency(cartTotal)}
              </Text>
              <Text style={styles.cartFabArrow}>›</Text>
            </TouchableOpacity>
          )}

          {/* Cart Sheet */}
          <Modal
            visible={cartOpen}
            animationType="slide"
            transparent
            onRequestClose={() => setCartOpen(false)}
          >
            <TouchableOpacity
              style={styles.modalOverlay}
              activeOpacity={1}
              onPress={() => setCartOpen(false)}
            />
            <View style={styles.cartSheet}>
              <View style={styles.cartSheetHandle} />
              <Text style={styles.cartTitle}>Keranjang</Text>
              <ScrollView style={styles.cartScrollView}>
                {cart.map(item => (
                  <View key={item.id} style={styles.cartItem}>
                    <View style={styles.flexOne}>
                      <Text style={styles.cartItemName} numberOfLines={1}>
                        {item.name}
                      </Text>
                      <Text style={styles.cartItemPrice}>
                        {formatCurrency(item.price)}
                      </Text>
                    </View>
                    <View style={styles.cartQtyRow}>
                      <TouchableOpacity
                        style={styles.qtyBtn}
                        onPress={() => updateQty(item.id, -1)}
                      >
                        <Text style={styles.qtyBtnText}>−</Text>
                      </TouchableOpacity>
                      <Text style={styles.qtyText}>{item.quantity}</Text>
                      <TouchableOpacity
                        style={styles.qtyBtn}
                        onPress={() => updateQty(item.id, 1)}
                      >
                        <Text style={styles.qtyBtnText}>+</Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        style={styles.removeBtn}
                        onPress={() => removeFromCart(item.id)}
                      >
                        <Text style={styles.removeBtnText}>🗑</Text>
                      </TouchableOpacity>
                    </View>
                  </View>
                ))}
              </ScrollView>
              <View style={styles.cartTotalRow}>
                <Text style={styles.cartTotalLabel}>Total</Text>
                <Text style={styles.cartTotalValue}>
                  {formatCurrency(cartTotal)}
                </Text>
              </View>
              <TouchableOpacity
                style={styles.checkoutBtn}
                onPress={() => {
                  setCartOpen(false);
                  setCheckoutOpen(true);
                }}
              >
                <Text style={styles.checkoutBtnText}>Bayar Sekarang</Text>
              </TouchableOpacity>
            </View>
          </Modal>

          {/* Checkout Modal */}
          <Modal
            visible={checkoutOpen}
            animationType="slide"
            transparent
            onRequestClose={() => !processing && setCheckoutOpen(false)}
          >
            <View style={styles.modalOverlayCenter}>
              <View style={styles.checkoutModal}>
                <Text style={styles.checkoutTitle}>Konfirmasi Pembayaran</Text>
                <View style={styles.checkoutTotalRow}>
                  <Text style={styles.checkoutTotalLabel}>Total</Text>
                  <Text style={styles.checkoutTotalValue}>
                    {formatCurrency(cartTotal)}
                  </Text>
                </View>
                <Text style={styles.payMethodLabel}>Metode Pembayaran</Text>
                <View style={styles.payMethodRow}>
                  {PAYMENT_METHODS.map(m => (
                    <TouchableOpacity
                      key={m}
                      style={[
                        styles.payMethodBtn,
                        paymentMethod === m && styles.payMethodBtnActive,
                      ]}
                      onPress={() => setPaymentMethod(m)}
                    >
                      <Text
                        style={[
                          styles.payMethodText,
                          paymentMethod === m && styles.payMethodTextActive,
                        ]}
                      >
                        {m}
                      </Text>
                    </TouchableOpacity>
                  ))}
                </View>
                <View style={styles.checkoutActions}>
                  <TouchableOpacity
                    style={styles.cancelBtn}
                    onPress={() => setCheckoutOpen(false)}
                    disabled={processing}
                  >
                    <Text style={styles.cancelBtnText}>Batal</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[
                      styles.confirmBtn,
                      processing && styles.confirmBtnDisabled,
                    ]}
                    onPress={handleCheckout}
                    disabled={processing}
                  >
                    {processing ? (
                      <ActivityIndicator color="#000" />
                    ) : (
                      <Text style={styles.confirmBtnText}>Konfirmasi</Text>
                    )}
                  </TouchableOpacity>
                </View>
              </View>
            </View>
          </Modal>
        </View>
      )}

      {/* ── PRODUCTS VIEW ── */}
      {activeTab === 'products' && (
        <View style={styles.flexOne}>
          <View style={styles.productsHeader}>
            <TextInput
              style={[styles.searchInput, styles.searchInputFlex]}
              placeholder="Cari produk..."
              placeholderTextColor="#666"
              value={prodSearch}
              onChangeText={setProdSearch}
            />
            <TouchableOpacity
              style={styles.addProductBtn}
              onPress={() => navigation.navigate('AddProduct')}
            >
              <Text style={styles.addProductBtnText}>+ Tambah</Text>
            </TouchableOpacity>
          </View>

          {loading ? (
            <View style={styles.centered}>
              <ActivityIndicator color="#C8F000" size="large" />
            </View>
          ) : (
            <FlatList
              data={filteredProd}
              keyExtractor={item => String(item.id)}
              contentContainerStyle={styles.prodListContent}
              ItemSeparatorComponent={() => (
                <View style={styles.prodSeparator} />
              )}
              renderItem={({ item }) => (
                <View style={styles.prodRow}>
                  {item.image ? (
                    <Image
                      source={{ uri: item.image }}
                      style={styles.prodThumb}
                    />
                  ) : (
                    <View
                      style={[styles.prodThumb, styles.prodThumbPlaceholder]}
                    >
                      <Text>📦</Text>
                    </View>
                  )}
                  <View style={styles.flexOne}>
                    <Text style={styles.prodName} numberOfLines={1}>
                      {item.name}
                    </Text>
                    <Text style={styles.prodCat}>{item.category}</Text>
                    <Text style={styles.prodPrice}>
                      {formatCurrency(item.price)}
                    </Text>
                  </View>
                  <View style={styles.prodRight}>
                    <Text
                      style={[
                        styles.prodStock,
                        item.stock <= 5 && styles.stockLow,
                      ]}
                    >
                      Stok: {item.stock}
                      {item.stock <= 5 ? ' ⚠️' : ''}
                    </Text>
                    <View style={styles.prodActions}>
                      <TouchableOpacity
                        style={styles.editBtn}
                        onPress={() =>
                          navigation.navigate('EditProduct', {
                            productId: item.id,
                          })
                        }
                      >
                        <Text style={styles.editBtnText}>Edit</Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        style={styles.deleteBtn}
                        onPress={() => handleDeleteProduct(item)}
                      >
                        <Text style={styles.deleteBtnText}>Hapus</Text>
                      </TouchableOpacity>
                    </View>
                  </View>
                </View>
              )}
              ListEmptyComponent={
                <Text style={styles.emptyText}>
                  {products.length === 0
                    ? 'Belum ada produk. Tambah produk pertama!'
                    : 'Tidak ada produk yang cocok.'}
                </Text>
              }
            />
          )}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#111' },
  flexOne: { flex: 1 },
  stockLow: { color: '#ef4444' },
  confirmBtnDisabled: { opacity: 0.6 },
  searchInputFlex: { flex: 1 },

  // Grid layout
  chipContent: { paddingHorizontal: 16 },
  gridColumnWrapper: { gap: 10, paddingHorizontal: 16 },
  gridContent: { paddingTop: 10 },
  gridContentWithCart: { paddingBottom: 100 },
  gridContentNoCart: { paddingBottom: 20 },

  // Cart scroll
  cartScrollView: { maxHeight: 340 },

  // Products list
  prodListContent: { padding: 16, paddingBottom: 40 },
  prodSeparator: { height: 10 },

  // Segmented control
  segmentRow: {
    flexDirection: 'row',
    margin: 16,
    backgroundColor: '#1E1E1E',
    borderRadius: 12,
    padding: 4,
    borderWidth: 1,
    borderColor: '#333',
  },
  segmentBtn: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 9,
    alignItems: 'center',
  },
  segmentBtnActive: { backgroundColor: '#C8F000' },
  segmentText: { color: '#9CA3AF', fontWeight: '600', fontSize: 14 },
  segmentTextActive: { color: '#000', fontWeight: '700' },

  // Search
  searchRow: { paddingHorizontal: 16, paddingBottom: 8 },
  productsHeader: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingBottom: 12,
    gap: 10,
  },
  searchInput: {
    backgroundColor: '#1E1E1E',
    color: '#fff',
    borderRadius: 10,
    paddingHorizontal: 14,
    paddingVertical: 10,
    fontSize: 14,
    borderWidth: 1,
    borderColor: '#333',
  },

  // Category chips
  chipScroll: { marginBottom: 8, paddingVertical: 4 },
  chip: {
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 20,
    backgroundColor: '#1E1E1E',
    borderWidth: 1,
    borderColor: '#333',
    marginRight: 8,
  },
  chipActive: { backgroundColor: '#C8F000', borderColor: '#C8F000' },
  chipText: { color: '#9CA3AF', fontSize: 13, fontWeight: '600' },
  chipTextActive: { color: '#000' },

  // Product card (POS grid)
  productCard: {
    flex: 1,
    backgroundColor: '#1E1E1E',
    borderRadius: 12,
    padding: 12,
    borderWidth: 1,
    borderColor: '#333',
    marginBottom: 10,
  },
  productCardInCart: {
    borderColor: '#C8F000',
    backgroundColor: 'rgba(200,240,0,0.06)',
  },
  productImg: {
    width: '100%',
    height: 90,
    borderRadius: 8,
    marginBottom: 8,
    resizeMode: 'cover',
  },
  productImgPlaceholder: {
    width: '100%',
    height: 90,
    borderRadius: 8,
    marginBottom: 8,
    backgroundColor: '#2C2C2C',
    justifyContent: 'center',
    alignItems: 'center',
  },
  productImgEmoji: { fontSize: 32 },
  productName: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '600',
    marginBottom: 4,
  },
  productPrice: {
    color: '#C8F000',
    fontSize: 13,
    fontWeight: '700',
    marginBottom: 4,
  },
  productFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  productStock: { color: '#9CA3AF', fontSize: 11 },
  inCartBadge: {
    backgroundColor: '#C8F000',
    borderRadius: 10,
    width: 20,
    height: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  inCartBadgeText: { color: '#000', fontSize: 11, fontWeight: 'bold' },

  // Cart FAB
  cartFab: {
    position: 'absolute',
    bottom: 16,
    left: 16,
    right: 16,
    backgroundColor: '#C8F000',
    borderRadius: 14,
    paddingVertical: 16,
    paddingHorizontal: 20,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    elevation: 6,
  },
  cartFabText: { color: '#000', fontWeight: 'bold', fontSize: 15 },
  cartFabArrow: { color: '#000', fontSize: 22, fontWeight: 'bold' },

  // Cart sheet
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)' },
  modalOverlayCenter: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'center',
    padding: 20,
  },
  cartSheet: {
    backgroundColor: '#1E1E1E',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: 20,
    paddingBottom: 36,
    borderTopWidth: 1,
    borderColor: '#333',
  },
  cartSheetHandle: {
    width: 40,
    height: 4,
    backgroundColor: '#444',
    borderRadius: 2,
    alignSelf: 'center',
    marginBottom: 16,
  },
  cartTitle: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '700',
    marginBottom: 16,
  },
  cartItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 14,
    gap: 10,
  },
  cartItemName: { color: '#fff', fontSize: 14, fontWeight: '600' },
  cartItemPrice: { color: '#9CA3AF', fontSize: 12, marginTop: 2 },
  cartQtyRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  qtyBtn: {
    backgroundColor: '#2C2C2C',
    borderRadius: 8,
    width: 30,
    height: 30,
    justifyContent: 'center',
    alignItems: 'center',
  },
  qtyBtnText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  qtyText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '700',
    minWidth: 24,
    textAlign: 'center',
  },
  removeBtn: { marginLeft: 4 },
  removeBtnText: { fontSize: 16 },
  cartTotalRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingTop: 16,
    borderTopWidth: 1,
    borderColor: '#333',
    marginTop: 8,
    marginBottom: 16,
  },
  cartTotalLabel: { color: '#9CA3AF', fontSize: 15, fontWeight: '600' },
  cartTotalValue: { color: '#C8F000', fontSize: 18, fontWeight: '700' },
  checkoutBtn: {
    backgroundColor: '#C8F000',
    borderRadius: 12,
    paddingVertical: 15,
    alignItems: 'center',
  },
  checkoutBtnText: { color: '#000', fontWeight: 'bold', fontSize: 16 },

  // Checkout modal
  checkoutModal: {
    backgroundColor: '#1E1E1E',
    borderRadius: 16,
    padding: 24,
    borderWidth: 1,
    borderColor: '#333',
  },
  checkoutTitle: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '700',
    marginBottom: 20,
  },
  checkoutTotalRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 20,
  },
  checkoutTotalLabel: { color: '#9CA3AF', fontSize: 15 },
  checkoutTotalValue: { color: '#C8F000', fontSize: 22, fontWeight: '700' },
  payMethodLabel: { color: '#9CA3AF', fontSize: 13, marginBottom: 10 },
  payMethodRow: { flexDirection: 'row', gap: 10, marginBottom: 24 },
  payMethodBtn: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 10,
    alignItems: 'center',
    backgroundColor: '#2C2C2C',
    borderWidth: 1,
    borderColor: '#444',
  },
  payMethodBtnActive: {
    borderColor: '#C8F000',
    backgroundColor: 'rgba(200,240,0,0.1)',
  },
  payMethodText: { color: '#9CA3AF', fontWeight: '600', fontSize: 13 },
  payMethodTextActive: { color: '#C8F000' },
  checkoutActions: { flexDirection: 'row', gap: 12 },
  cancelBtn: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#444',
  },
  cancelBtnText: { color: '#9CA3AF', fontWeight: '600' },
  confirmBtn: {
    flex: 2,
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
    backgroundColor: '#C8F000',
  },
  confirmBtnText: { color: '#000', fontWeight: 'bold', fontSize: 15 },

  // Products list
  addProductBtn: {
    backgroundColor: '#C8F000',
    borderRadius: 10,
    paddingHorizontal: 14,
    justifyContent: 'center',
    alignItems: 'center',
  },
  addProductBtnText: { color: '#000', fontWeight: 'bold', fontSize: 13 },
  prodRow: {
    backgroundColor: '#1E1E1E',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#333',
    padding: 12,
    flexDirection: 'row',
    gap: 12,
    alignItems: 'center',
  },
  prodThumb: { width: 56, height: 56, borderRadius: 10, resizeMode: 'cover' },
  prodThumbPlaceholder: {
    backgroundColor: '#2C2C2C',
    justifyContent: 'center',
    alignItems: 'center',
  },
  prodName: { color: '#fff', fontWeight: '600', fontSize: 14 },
  prodCat: { color: '#9CA3AF', fontSize: 12, marginTop: 2 },
  prodPrice: {
    color: '#C8F000',
    fontWeight: '700',
    fontSize: 13,
    marginTop: 2,
  },
  prodRight: { alignItems: 'flex-end', gap: 6 },
  prodStock: { color: '#9CA3AF', fontSize: 12, fontWeight: '600' },
  prodActions: { flexDirection: 'row', gap: 8 },
  editBtn: {
    backgroundColor: 'rgba(200,240,0,0.15)',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderWidth: 1,
    borderColor: '#C8F000',
  },
  editBtnText: { color: '#C8F000', fontWeight: '700', fontSize: 12 },
  deleteBtn: {
    backgroundColor: 'rgba(239,68,68,0.12)',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderWidth: 1,
    borderColor: '#ef4444',
  },
  deleteBtnText: { color: '#ef4444', fontWeight: '700', fontSize: 12 },

  centered: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  emptyText: {
    color: '#6B7280',
    textAlign: 'center',
    paddingVertical: 32,
    paddingHorizontal: 24,
    fontSize: 14,
  },
});
