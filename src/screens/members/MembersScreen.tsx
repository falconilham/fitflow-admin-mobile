import React, { useCallback, useRef, useState } from 'react';
import { useFocusEffect } from '@react-navigation/native';
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
const PAGE_LIMIT = 10;

// Stable function outside component — no new reference on renders
const getStatusColor = (item: Member): string => {
  const status = (item.status || '').toLowerCase();
  const isSuspended = (item as any).suspended;

  let isExpired = false;
  if (item.endDate) {
    const end = new Date(item.endDate);
    if (!isNaN(end.getTime())) {
      const today = new Date();
      end.setHours(0, 0, 0, 0);
      today.setHours(0, 0, 0, 0);
      isExpired = end < today;
    } else {
      isExpired = true;
    }
  }

  if (status === 'expired' || isExpired || isSuspended) return '#ef4444';
  if (status === 'active') return '#4ade80';
  return '#fbbf24';
};

// Memoized row — only re-renders when this member's data changes
const MemberCard = React.memo(
  ({ item, onPress }: { item: Member; onPress: (id: number) => void }) => {
    const color = getStatusColor(item);
    return (
      <TouchableOpacity style={styles.card} onPress={() => onPress(item.id)}>
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
              {item.packageName ?? 'No package'} · Exp:{' '}
              {formatDate(item.endDate)}
            </Text>
          </View>
        </View>
        <View style={[styles.statusDot, { backgroundColor: color }]} />
      </TouchableOpacity>
    );
  },
);

export default function MembersScreen() {
  const navigation =
    useNavigation<NativeStackNavigationProp<MembersStackParamList>>();
  const { activeGymId } = useAppSelector(state => state.auth);
  const [members, setMembers] = useState<Member[]>([]);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [hasMore, setHasMore] = useState(true);

  // Use refs so fetchMembers closure always has latest values
  const pageRef = useRef(1);
  const isFetchingRef = useRef(false);

  const fetchMembers = useCallback(
    async (reset = false) => {
      if (!activeGymId) return;
      if (isFetchingRef.current) return;
      isFetchingRef.current = true;

      const currentPage = reset ? 1 : pageRef.current;

      try {
        const res = await getMembersApi(activeGymId, {
          search,
          status: statusFilter === 'all' ? undefined : statusFilter,
          page: currentPage,
          limit: PAGE_LIMIT,
        });
        const data = res.data;
        const rows: Member[] = data.data ?? data.members ?? data;
        const total = data.pagination?.total ?? data.total ?? rows.length;

        setMembers(prev => (reset ? rows : [...prev, ...rows]));
        pageRef.current = currentPage + 1;
        setHasMore(currentPage * PAGE_LIMIT < total);
      } catch (e) {
        console.error('Members fetch error:', e);
      } finally {
        setLoading(false);
        setLoadingMore(false);
        setRefreshing(false);
        isFetchingRef.current = false;
      }
    },
    [activeGymId, search, statusFilter],
  );

  // Initial load & re-load when filter/search/gymId changes — but gated on
  // tab focus so we don't fire API calls in the background while another
  // tab is active (bottom tabs keep every screen mounted at all times).
  useFocusEffect(
    useCallback(() => {
      setLoading(true);
      setMembers([]);
      setHasMore(true);
      pageRef.current = 1;
      fetchMembers(true);
      // fetchMembers is memoised via useCallback and changes when
      // activeGymId / search / statusFilter change, so this re-runs correctly.
    }, [fetchMembers]),
  );

  const handleNavigate = useCallback(
    (id: number) => navigation.navigate('MemberDetail', { memberId: id }),
    [navigation],
  );

  const renderItem = useCallback(
    ({ item }: { item: Member }) => (
      <MemberCard item={item} onPress={handleNavigate} />
    ),
    [handleNavigate],
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
          }}
        />
        <View style={styles.actionButtons}>
          <TouchableOpacity
            style={styles.importBtn}
            onPress={() => navigation.navigate('ImportMember')}
          >
            <Text style={styles.importBtnText}>Import</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.addBtn}
            onPress={() => navigation.navigate('AddMember')}
          >
            <Text style={styles.addBtnText}>+ Tambah</Text>
          </TouchableOpacity>
        </View>
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
          keyExtractor={(item, index) => String(item.id) + '_' + index}
          renderItem={renderItem}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={() => {
                setRefreshing(true);
                pageRef.current = 1;
                fetchMembers(true);
              }}
              tintColor="#C8F000"
            />
          }
          onEndReached={() => {
            if (hasMore && !loadingMore) {
              setLoadingMore(true);
              fetchMembers();
            }
          }}
          onEndReachedThreshold={0.4}
          ListFooterComponent={
            loadingMore ? (
              <ActivityIndicator color="#C8F000" style={styles.loadingMore} />
            ) : null
          }
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
  actionButtons: { flexDirection: 'row', gap: 8 },
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
  importBtn: {
    backgroundColor: 'transparent',
    borderWidth: 1,
    borderColor: '#C8F000',
    paddingHorizontal: 16,
    borderRadius: 10,
    justifyContent: 'center',
  },
  importBtnText: { fontWeight: 'bold', color: '#C8F000', fontSize: 13 },
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
  loadingMore: { paddingVertical: 20 },
  listContent: { padding: 16, paddingBottom: 80 },
});
