import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  TextInput,
  FlatList,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { useAppSelector } from '../../store/hooks';
import { getMembersApi, checkInApi } from '../../api/endpoints';

interface Member {
  id: number;
  name: string;
  memberId?: string;
  status: string;
  endDate?: string;
}

export default function CheckInScreen() {
  const { activeGymId } = useAppSelector(state => state.auth);
  const [tab, setTab] = useState<'scan' | 'manual'>('manual');
  const [search, setSearch] = useState('');
  const [members, setMembers] = useState<Member[]>([]);
  const [loading, setLoading] = useState(false);
  const [checkinLoading, setCheckinLoading] = useState<number | null>(null);

  const handleSearch = async () => {
    if (!search.trim() || !activeGymId) return;
    setLoading(true);
    try {
      const res = await getMembersApi(activeGymId, { search: search.trim() });
      setMembers(res.data.members ?? res.data);
    } catch {
      Alert.alert('Error', 'Gagal mencari member');
    } finally {
      setLoading(false);
    }
  };

  const handleCheckIn = async (member: Member) => {
    if (!activeGymId) return;
    setCheckinLoading(member.id);
    try {
      const res = await checkInApi(activeGymId, member.id);
      const status = res.data.status;
      Alert.alert(
        status === 'granted' ? '✅ Check-in Berhasil' : '❌ Check-in Ditolak',
        `${member.name}: ${res.data.message ?? status}`,
      );
    } catch (e: any) {
      Alert.alert('❌ Ditolak', e?.response?.data?.error ?? 'Check-in gagal');
    } finally {
      setCheckinLoading(null);
    }
  };

  const renderMember = ({ item }: { item: Member }) => {
    const isExpired = item.status !== 'Active';
    return (
      <View style={[styles.memberRow, isExpired && styles.memberRowExpired]}>
        <View style={styles.memberInfo}>
          <Text style={styles.memberName}>{item.name}</Text>
          {item.memberId ? (
            <Text style={styles.memberId}>ID: {item.memberId}</Text>
          ) : null}
          <View style={[styles.statusBadge, isExpired && styles.statusExpired]}>
            <Text
              style={[styles.statusText, isExpired && styles.statusTextExpired]}
            >
              {item.status}
            </Text>
          </View>
        </View>
        <TouchableOpacity
          style={[styles.checkInBtn, isExpired && styles.checkInBtnDisabled]}
          onPress={() => handleCheckIn(item)}
          disabled={checkinLoading === item.id}
        >
          {checkinLoading === item.id ? (
            <ActivityIndicator color="#000" size="small" />
          ) : (
            <Text style={styles.checkInBtnText}>Check-in</Text>
          )}
        </TouchableOpacity>
      </View>
    );
  };

  return (
    <View style={styles.container}>
      {/* Tab Bar */}
      <View style={styles.tabBar}>
        <TouchableOpacity
          style={[styles.tab, tab === 'manual' && styles.tabActive]}
          onPress={() => setTab('manual')}
        >
          <Text
            style={[styles.tabText, tab === 'manual' && styles.tabTextActive]}
          >
            🔍 Manual
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tab, tab === 'scan' && styles.tabActive]}
          onPress={() => setTab('scan')}
        >
          <Text
            style={[styles.tabText, tab === 'scan' && styles.tabTextActive]}
          >
            📷 Scan QR
          </Text>
        </TouchableOpacity>
      </View>

      {tab === 'manual' ? (
        <View style={styles.content}>
          <View style={styles.searchRow}>
            <TextInput
              style={styles.searchInput}
              placeholder="Cari nama atau Member ID..."
              placeholderTextColor="#666"
              value={search}
              onChangeText={setSearch}
              onSubmitEditing={handleSearch}
              returnKeyType="search"
            />
            <TouchableOpacity style={styles.searchBtn} onPress={handleSearch}>
              <Text style={styles.searchBtnText}>Cari</Text>
            </TouchableOpacity>
          </View>

          {loading ? (
            <ActivityIndicator color="#C8F000" style={styles.loadingSpinner} />
          ) : (
            <FlatList
              data={members}
              keyExtractor={item => String(item.id)}
              renderItem={renderMember}
              ListEmptyComponent={
                <Text style={styles.emptyText}>
                  {search
                    ? 'Member tidak ditemukan'
                    : 'Cari member untuk check-in'}
                </Text>
              }
            />
          )}
        </View>
      ) : (
        <View style={styles.centered}>
          <Text style={styles.scanPlaceholder}>📷</Text>
          <Text style={styles.scanText}>QR Scanner</Text>
          <Text style={styles.scanSub}>
            Butuh izin kamera.{'\n'}Akan diaktifkan setelah pod install (iOS)
            atau gradle sync (Android).
          </Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#111' },
  tabBar: {
    flexDirection: 'row',
    backgroundColor: '#1E1E1E',
    borderBottomWidth: 1,
    borderBottomColor: '#333',
  },
  tab: { flex: 1, paddingVertical: 14, alignItems: 'center' },
  tabActive: { borderBottomWidth: 2, borderBottomColor: '#C8F000' },
  tabText: { color: '#9CA3AF', fontSize: 14, fontWeight: '600' },
  tabTextActive: { color: '#C8F000' },
  content: { flex: 1, padding: 16 },
  searchRow: { flexDirection: 'row', gap: 10, marginBottom: 16 },
  searchInput: {
    flex: 1,
    backgroundColor: '#1E1E1E',
    color: '#fff',
    borderRadius: 10,
    paddingHorizontal: 14,
    paddingVertical: 11,
    borderWidth: 1,
    borderColor: '#333',
  },
  searchBtn: {
    backgroundColor: '#C8F000',
    paddingHorizontal: 18,
    borderRadius: 10,
    justifyContent: 'center',
  },
  searchBtnText: { fontWeight: 'bold', color: '#000' },
  memberRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#1E1E1E',
    borderRadius: 12,
    padding: 14,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: '#333',
  },
  memberRowExpired: { borderColor: '#7f1d1d', backgroundColor: '#1a0a0a' },
  memberInfo: { flex: 1 },
  memberName: { color: '#fff', fontWeight: 'bold', fontSize: 15 },
  memberId: { color: '#9CA3AF', fontSize: 12, marginTop: 2 },
  statusBadge: {
    alignSelf: 'flex-start',
    marginTop: 6,
    backgroundColor: 'rgba(74,222,128,0.15)',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 10,
  },
  statusExpired: { backgroundColor: 'rgba(248,113,113,0.15)' },
  statusText: { color: '#4ade80', fontSize: 11, fontWeight: '600' },
  statusTextExpired: { color: '#f87171' },
  checkInBtn: {
    backgroundColor: '#C8F000',
    paddingHorizontal: 16,
    paddingVertical: 9,
    borderRadius: 8,
    minWidth: 80,
    alignItems: 'center',
  },
  checkInBtnDisabled: { backgroundColor: '#333' },
  checkInBtnText: { color: '#000', fontWeight: 'bold', fontSize: 13 },
  centered: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  scanPlaceholder: { fontSize: 64 },
  scanText: { color: '#fff', fontSize: 20, fontWeight: 'bold', marginTop: 12 },
  scanSub: {
    color: '#9CA3AF',
    fontSize: 13,
    textAlign: 'center',
    marginTop: 8,
    paddingHorizontal: 32,
  },
  emptyText: {
    color: '#6B7280',
    textAlign: 'center',
    marginTop: 40,
    fontSize: 14,
  },
  loadingSpinner: { marginTop: 32 },
});
