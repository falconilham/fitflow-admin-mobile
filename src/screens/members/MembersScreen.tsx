import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useAppSelector } from '../../store/hooks';
import { getMembersApi } from '../../api/endpoints';
import { formatDate } from '../../utils/format';
import { MembersStackParamList } from '../../navigation/types';

interface Member {
  id: number;
  name: string;
  email: string;
  memberId?: string;
  status: string;
  endDate?: string;
  packageName?: string;
}

const STATUS_FILTERS = ['all', 'active', 'expired', 'suspended'];

export default function MembersScreen() {
  const navigation =
    useNavigation<NativeStackNavigationProp<MembersStackParamList>>();
  const { activeGymId } = useAppSelector(state => state.auth);
  const [members, setMembers] = useState<Member[]>([]);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);

  const fetchMembers = useCallback(
    async (reset = false) => {
      if (!activeGymId) return;
      try {
        const currentPage = reset ? 1 : page;
        const res = await getMembersApi(activeGymId, {
          search,
          status: statusFilter === 'all' ? undefined : statusFilter,
          page: currentPage,
          limit: 20,
        });
        const data = res.data;
        const rows = data.members ?? data;
        setTotal(data.total ?? rows.length);
        setMembers(reset ? rows : prev => [...prev, ...rows]);
        if (reset) setPage(2);
        else setPage(p => p + 1);
      } catch (e) {
        console.error('Members fetch error:', e);
      } finally {
        setLoading(false);
        setRefreshing(false);
      }
    },
    [activeGymId, search, statusFilter, page],
  );

  useEffect(() => {
    setLoading(true);
    setMembers([]);
    fetchMembers(true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeGymId, search, statusFilter]);

  const statusColor = (s: string) => {
    if (s === 'Active') return '#4ade80';
    if (s === 'Expired') return '#f87171';
    return '#fbbf24';
  };

  const renderItem = ({ item }: { item: Member }) => (
    <TouchableOpacity
      style={styles.card}
      onPress={() => navigation.navigate('MemberDetail', { memberId: item.id })}
    >
      <View style={styles.cardLeft}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>
            {item.name.charAt(0).toUpperCase()}
          </Text>
        </View>
        <View>
          <Text style={styles.name}>{item.name}</Text>
          {item.memberId ? (
            <Text style={styles.meta}>ID: {item.memberId}</Text>
          ) : null}
          <Text style={styles.meta}>
            {item.packageName ?? 'No package'} · Exp: {formatDate(item.endDate)}
          </Text>
        </View>
      </View>
      <View
        style={[
          styles.statusDot,
          { backgroundColor: statusColor(item.status) },
        ]}
      />
    </TouchableOpacity>
  );

  return (
    <View style={styles.container}>
      {/* Search */}
      <View style={styles.searchRow}>
        <TextInput
          style={styles.searchInput}
          placeholder="Cari nama, email, atau ID..."
          placeholderTextColor="#666"
          value={search}
          onChangeText={t => {
            setSearch(t);
            setPage(1);
          }}
        />
        <TouchableOpacity
          style={styles.addBtn}
          onPress={() => navigation.navigate('AddMember')}
        >
          <Text style={styles.addBtnText}>+ Tambah</Text>
        </TouchableOpacity>
      </View>

      {/* Status filters */}
      <View style={styles.filterRow}>
        {STATUS_FILTERS.map(f => (
          <TouchableOpacity
            key={f}
            style={[
              styles.filterChip,
              statusFilter === f && styles.filterChipActive,
            ]}
            onPress={() => setStatusFilter(f)}
          >
            <Text
              style={[
                styles.filterText,
                statusFilter === f && styles.filterTextActive,
              ]}
            >
              {f.charAt(0).toUpperCase() + f.slice(1)}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      {loading ? (
        <ActivityIndicator color="#C8F000" style={styles.loadingSpinner} />
      ) : (
        <FlatList
          data={members}
          keyExtractor={item => String(item.id)}
          renderItem={renderItem}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={() => {
                setRefreshing(true);
                fetchMembers(true);
              }}
              tintColor="#C8F000"
            />
          }
          onEndReached={() => {
            if (members.length < total) fetchMembers();
          }}
          onEndReachedThreshold={0.5}
          ListEmptyComponent={
            <Text style={styles.empty}>Tidak ada member ditemukan</Text>
          }
          contentContainerStyle={styles.listContent}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#111' },
  searchRow: { flexDirection: 'row', padding: 16, gap: 10 },
  searchInput: {
    flex: 1,
    backgroundColor: '#1E1E1E',
    color: '#fff',
    borderRadius: 10,
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderWidth: 1,
    borderColor: '#333',
  },
  addBtn: {
    backgroundColor: '#C8F000',
    paddingHorizontal: 16,
    borderRadius: 10,
    justifyContent: 'center',
  },
  addBtnText: { fontWeight: 'bold', color: '#000', fontSize: 13 },
  filterRow: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    gap: 8,
    marginBottom: 4,
  },
  filterChip: {
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 20,
    backgroundColor: '#1E1E1E',
    borderWidth: 1,
    borderColor: '#333',
  },
  filterChipActive: { backgroundColor: '#C8F000', borderColor: '#C8F000' },
  filterText: { color: '#9CA3AF', fontSize: 13 },
  filterTextActive: { color: '#000', fontWeight: 'bold' },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#1E1E1E',
    borderRadius: 12,
    padding: 14,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: '#333',
  },
  cardLeft: { flexDirection: 'row', alignItems: 'center', gap: 12, flex: 1 },
  avatar: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: '#2C2C2C',
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarText: { color: '#C8F000', fontWeight: 'bold', fontSize: 16 },
  name: { color: '#fff', fontWeight: '600', fontSize: 15 },
  meta: { color: '#9CA3AF', fontSize: 12, marginTop: 2 },
  statusDot: { width: 10, height: 10, borderRadius: 5 },
  empty: { color: '#6B7280', textAlign: 'center', marginTop: 40 },
  loadingSpinner: { marginTop: 40 },
  listContent: { padding: 16, paddingBottom: 80 },
});
