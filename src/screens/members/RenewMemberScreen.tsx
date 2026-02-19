import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  ScrollView,
} from 'react-native';
import { RouteProp, useRoute, useNavigation } from '@react-navigation/native';
import {
  getPackagesApi,
  updateMemberApi,
  getMemberDetailApi,
} from '../../api/endpoints';
import { useAppSelector } from '../../store/hooks';
import { formatDate } from '../../utils/format';
import { MembersStackParamList } from '../../navigation/types';

type RouteProps = RouteProp<MembersStackParamList, 'RenewMember'>;

export default function RenewMemberScreen() {
  const route = useRoute<RouteProps>();
  const navigation = useNavigation();
  const { memberId } = route.params;
  const { activeGymId } = useAppSelector(state => state.auth);
  const [packages, setPackages] = useState<any[]>([]);
  const [member, setMember] = useState<any>(null);
  const [selectedPackage, setSelectedPackage] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const fetchData = async () => {
      if (!activeGymId) return;
      try {
        const [pkgRes, memberRes] = await Promise.all([
          getPackagesApi(activeGymId),
          getMemberDetailApi(memberId),
        ]);
        setPackages(pkgRes.data);
        setMember(memberRes.data);
        // Pre-select current package
        if (memberRes.data?.packageId)
          setSelectedPackage(memberRes.data.packageId);
      } catch {
        Alert.alert('Error', 'Gagal memuat data');
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, [activeGymId, memberId]);

  const handleRenew = async () => {
    if (!selectedPackage) {
      Alert.alert('Error', 'Pilih paket membership');
      return;
    }
    setSubmitting(true);
    try {
      await updateMemberApi(memberId, {
        packageId: selectedPackage,
        renew: true,
      });
      Alert.alert('Berhasil', 'Membership berhasil diperpanjang', [
        { text: 'OK', onPress: () => navigation.goBack() },
      ]);
    } catch (e: any) {
      Alert.alert(
        'Error',
        e?.response?.data?.error ?? 'Gagal memperpanjang membership',
      );
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color="#C8F000" size="large" />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      {/* Current Info */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Status Saat Ini</Text>
        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Member</Text>
          <Text style={styles.infoValue}>{member?.User?.name ?? '-'}</Text>
        </View>
        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Paket Aktif</Text>
          <Text style={styles.infoValue}>
            {member?.MembershipPackage?.name ?? '-'}
          </Text>
        </View>
        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Expired</Text>
          <Text style={[styles.infoValue, styles.expiredText]}>
            {formatDate(member?.endDate)}
          </Text>
        </View>
      </View>

      {/* Package Selection */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Pilih Paket Baru</Text>
        {packages.map(pkg => (
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
        ))}
      </View>

      <TouchableOpacity
        style={[styles.submitBtn, submitting && styles.submitBtnDisabled]}
        onPress={handleRenew}
        disabled={submitting}
      >
        {submitting ? (
          <ActivityIndicator color="#000" />
        ) : (
          <Text style={styles.submitBtnText}>🔄 Perpanjang Sekarang</Text>
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
    marginBottom: 12,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#2C2C2C',
  },
  infoLabel: { color: '#9CA3AF', fontSize: 14 },
  infoValue: { color: '#fff', fontSize: 14, fontWeight: '500' },
  expiredText: { color: '#f87171' },
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
