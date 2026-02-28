import React, { useEffect, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { RouteProp, useRoute, useNavigation } from '@react-navigation/native';
import { useAppSelector } from '../../store/hooks';
import {
  getPosProductsApi,
  createProductApi,
  updateProductApi,
} from '../../api/endpoints';
import { StoreStackParamList } from '../../navigation/types';

type RouteProps = RouteProp<StoreStackParamList, 'EditProduct'>;

const CATEGORIES = [
  'Drink',
  'Food',
  'Supplement',
  'Gear',
  'Merchandise',
  'Other',
];

interface ProductForm {
  name: string;
  category: string;
  price: string;
  stock: string;
  description: string;
}

export default function AddEditProductScreen() {
  const route = useRoute<RouteProps>();
  const navigation = useNavigation();
  const { activeGymId } = useAppSelector(state => state.auth);

  // If productId is present → edit mode
  const productId = (route.params as any)?.productId as number | undefined;
  const isEdit = !!productId;

  const [form, setForm] = useState<ProductForm>({
    name: '',
    category: 'Other',
    price: '',
    stock: '',
    description: '',
  });
  const [loading, setLoading] = useState(false);
  const [fetching, setFetching] = useState(isEdit);

  const fetchProduct = useCallback(async () => {
    if (!productId || !activeGymId) {
      setFetching(false);
      return;
    }
    try {
      const res = await getPosProductsApi(activeGymId);
      const products: any[] = res.data?.data ?? res.data ?? [];
      const product = products.find((p: any) => p.id === productId);
      if (product) {
        setForm({
          name: product.name ?? '',
          category: product.category ?? 'Other',
          price: String(product.price ?? ''),
          stock: String(product.stock ?? ''),
          description: product.description ?? '',
        });
      }
    } catch {
      Alert.alert('Error', 'Gagal memuat data produk');
    } finally {
      setFetching(false);
    }
  }, [productId, activeGymId]);

  useEffect(() => {
    if (isEdit) fetchProduct();
  }, [fetchProduct, isEdit]);

  const handleSubmit = async () => {
    if (!form.name.trim()) {
      Alert.alert('Error', 'Nama produk wajib diisi');
      return;
    }
    if (!form.price || isNaN(Number(form.price))) {
      Alert.alert('Error', 'Harga tidak valid');
      return;
    }
    if (!form.stock || isNaN(Number(form.stock))) {
      Alert.alert('Error', 'Stok tidak valid');
      return;
    }
    if (!activeGymId) return;

    setLoading(true);
    try {
      const payload = {
        gymId: activeGymId,
        name: form.name.trim(),
        category: form.category,
        price: Number(form.price),
        stock: Number(form.stock),
        description: form.description.trim() || undefined,
      };

      if (isEdit && productId) {
        await updateProductApi(productId, payload);
        Alert.alert('Berhasil', 'Produk berhasil diperbarui', [
          { text: 'OK', onPress: () => navigation.goBack() },
        ]);
      } else {
        await createProductApi(payload);
        Alert.alert('Berhasil', 'Produk baru berhasil ditambahkan', [
          { text: 'OK', onPress: () => navigation.goBack() },
        ]);
      }
    } catch (e: any) {
      Alert.alert(
        'Error',
        e?.response?.data?.error ??
          e?.response?.data?.message ??
          'Gagal menyimpan produk',
      );
    } finally {
      setLoading(false);
    }
  };

  if (fetching) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color="#C8F000" size="large" />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} keyboardShouldPersistTaps="handled">
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Informasi Produk</Text>

        {/* Name */}
        <View style={styles.fieldGroup}>
          <Text style={styles.label}>Nama Produk *</Text>
          <TextInput
            style={styles.input}
            placeholder="contoh: Protein Bar"
            placeholderTextColor="#666"
            value={form.name}
            onChangeText={t => setForm(p => ({ ...p, name: t }))}
          />
        </View>

        {/* Category */}
        <View style={styles.fieldGroup}>
          <Text style={styles.label}>Kategori</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false}>
            {CATEGORIES.map(cat => (
              <TouchableOpacity
                key={cat}
                style={[
                  styles.catChip,
                  form.category === cat && styles.catChipActive,
                ]}
                onPress={() => setForm(p => ({ ...p, category: cat }))}
              >
                <Text
                  style={[
                    styles.catChipText,
                    form.category === cat && styles.catChipTextActive,
                  ]}
                >
                  {cat}
                </Text>
              </TouchableOpacity>
            ))}
          </ScrollView>
        </View>

        {/* Price + Stock */}
        <View style={styles.row}>
          <View style={[styles.fieldGroup, styles.fieldGroupLeft]}>
            <Text style={styles.label}>Harga (Rp) *</Text>
            <TextInput
              style={styles.input}
              placeholder="15000"
              placeholderTextColor="#666"
              keyboardType="numeric"
              value={form.price}
              onChangeText={t => setForm(p => ({ ...p, price: t }))}
            />
          </View>
          <View style={[styles.fieldGroup, styles.fieldGroupFlex]}>
            <Text style={styles.label}>Stok *</Text>
            <TextInput
              style={styles.input}
              placeholder="50"
              placeholderTextColor="#666"
              keyboardType="numeric"
              value={form.stock}
              onChangeText={t => setForm(p => ({ ...p, stock: t }))}
            />
          </View>
        </View>

        {/* Description */}
        <View style={styles.fieldGroup}>
          <Text style={styles.label}>Deskripsi (Opsional)</Text>
          <TextInput
            style={[styles.input, styles.textarea]}
            placeholder="Deskripsi singkat produk..."
            placeholderTextColor="#666"
            multiline
            numberOfLines={3}
            value={form.description}
            onChangeText={t => setForm(p => ({ ...p, description: t }))}
          />
        </View>
      </View>

      <TouchableOpacity
        style={[styles.submitBtn, loading && styles.submitBtnDisabled]}
        onPress={handleSubmit}
        disabled={loading}
      >
        {loading ? (
          <ActivityIndicator color="#000" />
        ) : (
          <Text style={styles.submitBtnText}>
            {isEdit ? 'Simpan Perubahan' : 'Tambah Produk'}
          </Text>
        )}
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#111' },
  centered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#111',
  },
  section: {
    margin: 16,
    backgroundColor: '#1E1E1E',
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: '#333',
    marginBottom: 12,
  },
  sectionTitle: {
    color: '#9CA3AF',
    fontSize: 11,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 18,
  },
  fieldGroup: { marginBottom: 14 },
  fieldGroupFlex: { flex: 1 },
  fieldGroupLeft: { flex: 1, marginRight: 8 },
  label: { color: '#9CA3AF', fontSize: 13, marginBottom: 6 },
  row: { flexDirection: 'row' },
  input: {
    backgroundColor: '#2C2C2C',
    color: '#fff',
    borderRadius: 10,
    paddingHorizontal: 14,
    paddingVertical: 11,
    fontSize: 15,
    borderWidth: 1,
    borderColor: '#444',
  },
  textarea: { height: 80, textAlignVertical: 'top', paddingTop: 11 },
  catChip: {
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 20,
    backgroundColor: '#2C2C2C',
    borderWidth: 1,
    borderColor: '#444',
    marginRight: 8,
  },
  catChipActive: {
    backgroundColor: 'rgba(200,240,0,0.12)',
    borderColor: '#C8F000',
  },
  catChipText: { color: '#9CA3AF', fontSize: 13, fontWeight: '600' },
  catChipTextActive: { color: '#C8F000' },
  submitBtn: {
    backgroundColor: '#C8F000',
    margin: 16,
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
    marginBottom: 40,
  },
  submitBtnDisabled: { opacity: 0.6 },
  submitBtnText: { fontWeight: 'bold', color: '#000', fontSize: 16 },
});
