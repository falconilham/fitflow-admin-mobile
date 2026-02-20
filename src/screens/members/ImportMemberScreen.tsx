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
import {
  importMemberApi,
  getPackagesApi,
  generateMemberIdApi,
} from '../../api/endpoints';

interface Package {
  id: number;
  name: string;
  price: number;
  durationMonths: number;
}

export default function ImportMemberScreen() {
  const navigation = useNavigation();
  const { activeGymId } = useAppSelector(state => state.auth);
  const [packages, setPackages] = useState<Package[]>([]);
  const [selectedPackage, setSelectedPackage] = useState<number | null>(null);
  const [pkgPrice, setPkgPrice] = useState(0);

  const [form, setForm] = useState({
    memberId: '',
    name: '',
    email: '',
    phone: '',
    address: '',
    joinDate: '',
    endDate: '',
  });

  const [loading, setLoading] = useState(false);
  const [pkgLoading, setPkgLoading] = useState(true);
  const [generatingId, setGeneratingId] = useState(false);

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

  const handleGenerateId = async () => {
    if (!activeGymId) return;
    setGeneratingId(true);
    try {
      const res = await generateMemberIdApi(activeGymId);
      setForm(prev => ({ ...prev, memberId: res.data.generatedId }));
    } catch {
      Alert.alert('Error', 'Gagal generate Member ID');
    } finally {
      setGeneratingId(false);
    }
  };

  const handlePackageSelect = (pkg: Package) => {
    setSelectedPackage(pkg.id);
    setPkgPrice(pkg.price);
  };

  const validateDates = () => {
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRegex.test(form.joinDate) || !dateRegex.test(form.endDate)) {
      Alert.alert('Error', 'Format tanggal harus YYYY-MM-DD');
      return false;
    }
    if (new Date(form.endDate) <= new Date(form.joinDate)) {
      Alert.alert('Error', 'End Date harus setelah Join Date');
      return false;
    }
    return true;
  };

  const handleSubmit = async () => {
    if (!form.name) {
      Alert.alert('Error', 'Nama wajib diisi');
      return;
    }
    if (!form.joinDate || !form.endDate) {
      Alert.alert('Error', 'Join Date dan End Date wajib diisi');
      return;
    }
    if (!selectedPackage) {
      Alert.alert('Error', 'Pilih paket membership');
      return;
    }
    if (!validateDates()) return;

    setLoading(true);
    try {
      await importMemberApi(activeGymId!, {
        memberId: form.memberId,
        name: form.name,
        email: form.email,
        phone: form.phone,
        address: form.address,
        packageId: selectedPackage,
        price: pkgPrice,
        priceOverride: false,
        paymentMethod: 'Cash',
        joinDate: form.joinDate,
        endDate: form.endDate,
        skipEmailVerification: true,
        recordTransaction: false,
      });
      Alert.alert('Berhasil', 'Member lama berhasil diimport', [
        { text: 'OK', onPress: () => navigation.goBack() },
      ]);
    } catch (e: any) {
      Alert.alert(
        'Error',
        e?.response?.data?.error ??
          e?.response?.data?.message ??
          'Gagal import member',
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <ScrollView style={styles.container} keyboardShouldPersistTaps="handled">
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Informasi Member</Text>

        {/* Member ID Form */}
        <View style={styles.fieldGroup}>
          <Text style={styles.label}>Member ID (Opsional)</Text>
          <View style={styles.row}>
            <TextInput
              style={[styles.input, styles.memberIdInput]}
              placeholderTextColor="#666"
              placeholder="e.g. M-001"
              value={form.memberId}
              onChangeText={t => setForm(prev => ({ ...prev, memberId: t }))}
            />
            <TouchableOpacity
              style={[styles.autoBtn, generatingId && styles.disabledBtn]}
              onPress={handleGenerateId}
              disabled={generatingId}
            >
              {generatingId ? (
                <ActivityIndicator size="small" color="#000" />
              ) : (
                <Text style={styles.autoBtnText}>Auto</Text>
              )}
            </TouchableOpacity>
          </View>
        </View>

        {(['name', 'email', 'phone', 'address'] as const).map(field => (
          <View key={field} style={styles.fieldGroup}>
            <Text style={styles.label}>
              {field === 'name'
                ? 'Nama Lengkap *'
                : field === 'email'
                ? 'Email'
                : field === 'phone'
                ? 'No. HP'
                : 'Alamat (Opsional)'}
            </Text>
            <TextInput
              style={styles.input}
              placeholderTextColor="#666"
              placeholder={
                field === 'name'
                  ? 'John Doe'
                  : field === 'email'
                  ? 'john@email.com'
                  : field === 'phone'
                  ? '08xxxxxxxxxx'
                  : 'Alamat lengkap...'
              }
              keyboardType={
                field === 'email'
                  ? 'email-address'
                  : field === 'phone'
                  ? 'phone-pad'
                  : 'default'
              }
              autoCapitalize={field === 'email' ? 'none' : 'words'}
              multiline={field === 'address'}
              value={form[field]}
              onChangeText={t => setForm(prev => ({ ...prev, [field]: t }))}
            />
          </View>
        ))}
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Tanggal Membership *</Text>
        <View style={styles.fieldGroup}>
          <Text style={styles.label}>Join Date (YYYY-MM-DD) *</Text>
          <TextInput
            style={styles.input}
            placeholderTextColor="#666"
            placeholder="2024-01-01"
            value={form.joinDate}
            onChangeText={t => setForm(prev => ({ ...prev, joinDate: t }))}
          />
        </View>
        <View style={styles.fieldGroup}>
          <Text style={styles.label}>End Date (YYYY-MM-DD) *</Text>
          <TextInput
            style={styles.input}
            placeholderTextColor="#666"
            placeholder="2025-01-01"
            value={form.endDate}
            onChangeText={t => setForm(prev => ({ ...prev, endDate: t }))}
          />
        </View>
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Pilih Paket (Referensi) *</Text>
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
              onPress={() => handlePackageSelect(pkg)}
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
        style={[styles.submitBtn, loading && styles.disabledBtn]}
        onPress={handleSubmit}
        disabled={loading}
      >
        {loading ? (
          <ActivityIndicator color="#000" />
        ) : (
          <Text style={styles.submitBtnText}>Import Member Lama</Text>
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
  row: { flexDirection: 'row', alignItems: 'center' },
  memberIdInput: { flex: 1, marginRight: 8 },
  autoBtn: {
    backgroundColor: '#C8F000',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 10,
    justifyContent: 'center',
  },
  autoBtnText: { color: '#000', fontWeight: 'bold' },
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
  submitBtnText: { fontWeight: 'bold', color: '#000', fontSize: 16 },
  disabledBtn: { opacity: 0.6 },
});
