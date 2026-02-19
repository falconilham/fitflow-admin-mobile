import React, { useEffect, useState } from 'react';
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
import { useNavigation } from '@react-navigation/native';
import { useAppSelector } from '../../store/hooks';
import { createMemberApi, getPackagesApi } from '../../api/endpoints';

interface Package {
  id: number;
  name: string;
  price: number;
  durationMonths: number;
}

export default function AddMemberScreen() {
  const navigation = useNavigation();
  const { activeGymId } = useAppSelector(state => state.auth);
  const [packages, setPackages] = useState<Package[]>([]);
  const [selectedPackage, setSelectedPackage] = useState<number | null>(null);
  const [form, setForm] = useState({ name: '', email: '', phone: '' });
  const [loading, setLoading] = useState(false);
  const [pkgLoading, setPkgLoading] = useState(true);

  useEffect(() => {
    const fetchPackages = async () => {
      if (!activeGymId) return;
      try {
        const res = await getPackagesApi(activeGymId);
        setPackages(res.data);
      } catch {
        Alert.alert('Error', 'Gagal memuat paket membership');
      } finally {
        setPkgLoading(false);
      }
    };
    fetchPackages();
  }, [activeGymId]);

  const handleSubmit = async () => {
    if (!form.name || !form.email) {
      Alert.alert('Error', 'Nama dan email wajib diisi');
      return;
    }
    if (!selectedPackage) {
      Alert.alert('Error', 'Pilih paket membership');
      return;
    }
    setLoading(true);
    try {
      await createMemberApi(activeGymId!, {
        name: form.name,
        email: form.email,
        phone: form.phone,
        packageId: selectedPackage,
      });
      Alert.alert('Berhasil', 'Member baru berhasil ditambahkan', [
        { text: 'OK', onPress: () => navigation.goBack() },
      ]);
    } catch (e: any) {
      Alert.alert('Error', e?.response?.data?.error ?? 'Gagal menambah member');
    } finally {
      setLoading(false);
    }
  };

  return (
    <ScrollView style={styles.container} keyboardShouldPersistTaps="handled">
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Informasi Member</Text>
        {(['name', 'email', 'phone'] as const).map(field => (
          <View key={field} style={styles.fieldGroup}>
            <Text style={styles.label}>
              {field === 'name'
                ? 'Nama Lengkap *'
                : field === 'email'
                ? 'Email *'
                : 'No. HP'}
            </Text>
            <TextInput
              style={styles.input}
              placeholderTextColor="#666"
              placeholder={
                field === 'name'
                  ? 'John Doe'
                  : field === 'email'
                  ? 'john@email.com'
                  : '08xxxxxxxxxx'
              }
              keyboardType={
                field === 'email'
                  ? 'email-address'
                  : field === 'phone'
                  ? 'phone-pad'
                  : 'default'
              }
              autoCapitalize={field === 'email' ? 'none' : 'words'}
              value={form[field]}
              onChangeText={t => setForm(prev => ({ ...prev, [field]: t }))}
            />
          </View>
        ))}
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Pilih Paket Membership *</Text>
        {pkgLoading ? (
          <ActivityIndicator color="#C8F000" />
        ) : packages.length === 0 ? (
          <Text style={styles.emptyText}>Belum ada paket di gym ini</Text>
        ) : (
          packages.map(pkg => (
            <TouchableOpacity
              key={pkg.id}
              style={[
                styles.packageCard,
                selectedPackage === pkg.id && styles.packageCardActive,
              ]}
              onPress={() => setSelectedPackage(pkg.id)}
            >
              <Text
                style={[
                  styles.packageName,
                  selectedPackage === pkg.id && styles.packageNameActive,
                ]}
              >
                {pkg.name}
              </Text>
              <Text style={styles.packageMeta}>
                {pkg.durationMonths} bulan · Rp{' '}
                {pkg.price.toLocaleString('id-ID')}
              </Text>
            </TouchableOpacity>
          ))
        )}
      </View>

      <TouchableOpacity
        style={[styles.submitBtn, loading && styles.submitBtnDisabled]}
        onPress={handleSubmit}
        disabled={loading}
      >
        {loading ? (
          <ActivityIndicator color="#000" />
        ) : (
          <Text style={styles.submitBtnText}>Simpan Member</Text>
        )}
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#111' },
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
    marginBottom: 16,
  },
  fieldGroup: { marginBottom: 14 },
  label: { color: '#9CA3AF', fontSize: 13, marginBottom: 6 },
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
  packageCard: {
    padding: 14,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#333',
    marginBottom: 10,
    backgroundColor: '#2C2C2C',
  },
  packageCardActive: {
    borderColor: '#C8F000',
    backgroundColor: 'rgba(200,240,0,0.08)',
  },
  packageName: { color: '#fff', fontWeight: '600', fontSize: 15 },
  packageNameActive: { color: '#C8F000' },
  packageMeta: { color: '#9CA3AF', fontSize: 12, marginTop: 4 },
  emptyText: { color: '#6B7280', textAlign: 'center', paddingVertical: 12 },
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
