import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  Image,
} from 'react-native';
import { RouteProp, useRoute, useNavigation } from '@react-navigation/native';
import { getMemberDetailApi, updateMemberApi } from '../../api/endpoints';
import { formatDate, formatCurrency } from '../../utils/format';
import { MembersStackParamList } from '../../navigation/types';
import { API_URL } from '../../api/client';

type RouteProps = RouteProp<MembersStackParamList, 'MemberDetail'>;

const InfoRow = ({ label, value }: { label: string; value: string }) => (
  <View style={styles.infoRow}>
    <Text style={styles.infoLabel}>{label}</Text>
    <Text style={styles.infoValue}>{value}</Text>
  </View>
);

export default function MemberDetailScreen() {
  const route = useRoute<RouteProps>();
  const navigation = useNavigation();
  const { memberId } = route.params;
  const [member, setMember] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [suspending, setSuspending] = useState(false);

  const fetchMember = useCallback(async () => {
    try {
      const res = await getMemberDetailApi(memberId);
      setMember(res.data);
    } catch {
      Alert.alert('Error', 'Gagal memuat data member');
    } finally {
      setLoading(false);
    }
  }, [memberId]);

  useEffect(() => {
    fetchMember();
  }, [fetchMember]);

  const handleSuspend = async () => {
    const isSuspended = member?.suspended;
    Alert.alert(
      isSuspended ? 'Aktifkan Member?' : 'Suspend Member?',
      isSuspended
        ? 'Aktifkan kembali member ini?'
        : 'Member tidak bisa check-in selama disuspend.',
      [
        { text: 'Batal', style: 'cancel' },
        {
          text: 'Ya',
          style: isSuspended ? 'default' : 'destructive',
          onPress: async () => {
            setSuspending(true);
            try {
              await updateMemberApi(memberId, { suspended: !isSuspended });
              fetchMember();
            } catch {
              Alert.alert('Error', 'Gagal mengubah status');
            } finally {
              setSuspending(false);
            }
          },
        },
      ],
    );
  };

  if (loading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color="#C8F000" size="large" />
      </View>
    );
  }

  if (!member) {
    return (
      <View style={styles.centered}>
        <Text style={styles.errorText}>Member tidak ditemukan</Text>
      </View>
    );
  }

  const statusColor =
    member.status === 'Active' && !member.suspended ? '#4ade80' : '#f87171';
  const statusLabel = member.suspended ? 'Suspended' : member.status;
  const photoUrl = member.User?.memberPhoto
    ? `${API_URL}${member.User.memberPhoto}`
    : null;

  return (
    <ScrollView style={styles.container}>
      {/* Profile Header */}
      <View style={styles.profileHeader}>
        {photoUrl ? (
          <Image source={{ uri: photoUrl }} style={styles.photo} />
        ) : (
          <View style={styles.photoPlaceholder}>
            <Text style={styles.photoInitial}>
              {member.User?.name?.charAt(0) ?? '?'}
            </Text>
          </View>
        )}
        <Text style={styles.memberName}>{member.User?.name}</Text>
        {member.memberId ? (
          <Text style={styles.memberId}>ID: {member.memberId}</Text>
        ) : null}
        <View
          style={[styles.statusBadge, { backgroundColor: `${statusColor}22` }]}
        >
          <Text style={[styles.statusText, { color: statusColor }]}>
            {statusLabel}
          </Text>
        </View>
      </View>

      {/* Info */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Informasi</Text>
        <InfoRow label="Email" value={member.User?.email ?? '-'} />
        <InfoRow label="Phone" value={member.User?.phone ?? '-'} />
        <InfoRow label="Bergabung" value={formatDate(member.joinDate)} />
        <InfoRow label="Expired" value={formatDate(member.endDate)} />
        <InfoRow label="Paket" value={member.MembershipPackage?.name ?? '-'} />
        <InfoRow
          label="Harga"
          value={
            member.MembershipPackage?.price
              ? formatCurrency(member.MembershipPackage.price)
              : '-'
          }
        />
      </View>

      {/* Actions */}
      <View style={styles.actions}>
        <TouchableOpacity
          style={styles.renewBtn}
          onPress={() =>
            (navigation as any).navigate('RenewMember', { memberId })
          }
        >
          <Text style={styles.renewBtnText}>🔄 Perpanjang</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.suspendBtn, member.suspended && styles.activateBtn]}
          onPress={handleSuspend}
          disabled={suspending}
        >
          {suspending ? (
            <ActivityIndicator color="#fff" size="small" />
          ) : (
            <Text style={styles.suspendBtnText}>
              {member.suspended ? '✅ Aktifkan' : '🚫 Suspend'}
            </Text>
          )}
        </TouchableOpacity>
      </View>
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
  errorText: { color: '#f87171' },
  profileHeader: {
    alignItems: 'center',
    paddingVertical: 28,
    backgroundColor: '#1E1E1E',
    borderBottomWidth: 1,
    borderBottomColor: '#333',
  },
  photo: { width: 80, height: 80, borderRadius: 40, marginBottom: 12 },
  photoPlaceholder: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#2C2C2C',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 12,
  },
  photoInitial: { color: '#C8F000', fontSize: 32, fontWeight: 'bold' },
  memberName: { color: '#fff', fontSize: 20, fontWeight: 'bold' },
  memberId: { color: '#9CA3AF', fontSize: 13, marginTop: 4 },
  statusBadge: {
    marginTop: 8,
    paddingHorizontal: 14,
    paddingVertical: 4,
    borderRadius: 20,
  },
  statusText: { fontWeight: '600', fontSize: 13 },
  section: {
    margin: 16,
    backgroundColor: '#1E1E1E',
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: '#333',
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
  infoValue: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '500',
    maxWidth: '60%',
    textAlign: 'right',
  },
  actions: { flexDirection: 'row', gap: 12, padding: 16, paddingBottom: 40 },
  renewBtn: {
    flex: 1,
    backgroundColor: '#C8F000',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  renewBtnText: { fontWeight: 'bold', color: '#000', fontSize: 14 },
  suspendBtn: {
    flex: 1,
    backgroundColor: '#7f1d1d',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#991b1b',
  },
  activateBtn: { backgroundColor: '#14532d', borderColor: '#166534' },
  suspendBtnText: { fontWeight: 'bold', color: '#fff', fontSize: 14 },
});
