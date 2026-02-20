import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
} from 'react-native';
import { useAppDispatch, useAppSelector } from '../../store/hooks';
import { setActiveGym } from '../../store/authSlice';
import { getStatsApi, getMyGymsApi } from '../../api/endpoints';
import { formatCurrency } from '../../utils/format';

interface Stats {
  totalMembers: number;
  activeMembers: number;
  dailyCheckIns: number;
  expenses: number;
}

interface Gym {
  id: number;
  name: string;
}

import {
  Users as UsersIcon,
  UserCheck,
  Wallet,
  Plus,
  RefreshCw,
  History,
} from 'lucide-react-native';

const StatCard = ({
  label,
  value,
  color,
  icon: IconComponent,
}: {
  label: string;
  value: string;
  color: string;
  icon: any;
}) => (
  <View style={styles.statCard}>
    <View style={[styles.statIconContainer, { backgroundColor: `${color}15` }]}>
      <IconComponent size={20} color={color} />
    </View>

    <View style={styles.statInfo}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  </View>
);

export default function DashboardScreen() {
  const dispatch = useAppDispatch();
  const { admin, activeGymId } = useAppSelector(state => state.auth);
  const [stats, setStats] = useState<Stats | null>(null);
  const [gyms, setGyms] = useState<Gym[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const fetchData = useCallback(async () => {
    try {
      let currentGymId = activeGymId;
      if (!currentGymId && admin?.role === 'owner') {
        const gymsRes = await getMyGymsApi();
        if (gymsRes.data.length > 0) {
          setGyms(gymsRes.data);
          currentGymId = gymsRes.data[0].id;
          dispatch(setActiveGym(gymsRes.data[0].id));
        }
      }
      if (!currentGymId) return;

      const [statsRes, gymsRes] = await Promise.all([
        getStatsApi(currentGymId),
        admin?.role === 'owner' && gyms.length === 0
          ? getMyGymsApi()
          : Promise.resolve({ data: gyms }),
      ]);
      setStats(statsRes.data);
      if (gymsRes.data.length > 0 && gyms.length === 0) {
        setGyms(gymsRes.data);
      }
    } catch (e: any) {
      console.error('Dashboard fetch error:', e?.message || e);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [activeGymId, admin?.role, dispatch, gyms]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const onRefresh = () => {
    setRefreshing(true);
    fetchData();
  };

  if (loading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color="#C8F000" size="large" />
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.scrollContent}
      refreshControl={
        <RefreshControl
          refreshing={refreshing}
          onRefresh={onRefresh}
          tintColor="#C8F000"
        />
      }
    >
      {/* Premium Header */}
      <View style={styles.header}>
        <View style={styles.headerTop}>
          <View>
            <Text style={styles.gymName}>{admin?.Gym?.name || 'My Gym'}</Text>
            <Text style={styles.headerSubtitle}>
              Real-time performance summary
            </Text>
          </View>
        </View>
      </View>

      {/* Quick Stats Grid */}
      <View style={styles.statsGrid}>
        <StatCard
          label="Total Member"
          value={String(stats?.totalMembers ?? 0)}
          color="#C8F000"
          icon={UsersIcon}
        />
        <StatCard
          label="Member Aktif"
          value={String(stats?.activeMembers ?? 0)}
          color="#60a5fa"
          icon={UserCheck}
        />
        <StatCard
          label="Check-in"
          value={String(stats?.dailyCheckIns ?? 0)}
          color="#4ade80"
          icon={Plus}
        />
        <StatCard
          label="Expenses"
          value={formatCurrency(stats?.expenses ?? 0)}
          color="#f87171"
          icon={Wallet}
        />
      </View>

      {/* Quick Actions */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>
        <View style={styles.actionGrid}>
          <TouchableOpacity style={styles.actionCard}>
            <View style={[styles.actionIcon, styles.actionIconAdd]}>
              <Plus size={20} color="#000" />
            </View>
            <Text style={styles.actionLabel}>Add Member</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.actionCard}>
            <View style={[styles.actionIcon, styles.actionIconRenew]}>
              <RefreshCw size={20} color="#fff" />
            </View>
            <Text style={styles.actionLabel}>Renew</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Recent Activity Placeholder */}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Recent Activity</Text>
          <TouchableOpacity>
            <Text style={styles.viewAll}>View All</Text>
          </TouchableOpacity>
        </View>
        <View style={styles.activityList}>
          {[1, 2, 3].map(i => (
            <View key={i} style={styles.activityItem}>
              <View style={styles.activityDot} />
              <View style={styles.activityInfo}>
                <Text style={styles.activityTitle}>
                  Member Check-in completed
                </Text>
                <Text style={styles.activityTime}>{i * 5} mins ago</Text>
              </View>
              <History size={16} color="#4B5563" />
            </View>
          ))}
        </View>
      </View>

      {/* Gym Switcher (Owner only) */}
      {admin?.role === 'owner' && gyms.length > 1 && (
        <View style={styles.gymSwitcher}>
          <Text style={styles.sectionTitle}>Switch Gym</Text>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            style={styles.chipScroll}
          >
            {gyms.map(gym => (
              <TouchableOpacity
                key={gym.id}
                style={[
                  styles.gymChip,
                  activeGymId === gym.id && styles.gymChipActive,
                ]}
                onPress={() => dispatch(setActiveGym(gym.id))}
              >
                <Text
                  style={[
                    styles.gymChipText,
                    activeGymId === gym.id && styles.gymChipTextActive,
                  ]}
                >
                  {gym.name}
                </Text>
              </TouchableOpacity>
            ))}
          </ScrollView>
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0A0A0A' },
  scrollContent: { paddingBottom: 40 },
  centered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#0A0A0A',
  },
  header: {
    padding: 24,
    paddingTop: 20,
    backgroundColor: '#111',
    borderBottomWidth: 1,
    borderBottomColor: '#222',
    marginBottom: 20,
  },
  headerTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  gymName: {
    color: '#C8F000',
    fontSize: 28,
    fontWeight: '900',
    letterSpacing: -0.5,
  },
  headerSubtitle: {
    color: '#6B7280',
    fontSize: 13,
    marginTop: 4,
    fontWeight: '500',
  },
  logoutBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#1A1A1A',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#333',
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    paddingHorizontal: 16,
    gap: 12,
  },
  statCard: {
    backgroundColor: '#161616',
    borderRadius: 20,
    padding: 16,
    width: '48%',
    borderWidth: 1,
    borderColor: '#262626',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  statIconContainer: {
    width: 44,
    height: 44,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
  },
  statInfo: { flex: 1 },
  statValue: { color: '#fff', fontSize: 18, fontWeight: '800' },
  statLabel: {
    color: '#6B7280',
    fontSize: 11,
    fontWeight: '600',
    marginTop: 2,
  },
  section: { marginTop: 32, paddingHorizontal: 20 },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  sectionTitle: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
    letterSpacing: 0.5,
  },
  viewAll: { color: '#C8F000', fontSize: 12, fontWeight: '600' },
  actionGrid: { flexDirection: 'row', gap: 12, marginTop: 12 },
  actionCard: {
    flex: 1,
    backgroundColor: '#161616',
    borderRadius: 16,
    padding: 16,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#262626',
  },
  actionIcon: {
    width: 44,
    height: 44,
    borderRadius: 22,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 8,
  },
  actionIconAdd: { backgroundColor: '#C8F000' },
  actionIconRenew: { backgroundColor: '#2C2C2C' },
  actionLabel: { color: '#fff', fontSize: 12, fontWeight: '600' },

  activityList: {
    backgroundColor: '#111',
    borderRadius: 20,
    padding: 4,
    borderWidth: 1,
    borderColor: '#222',
  },
  activityItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    gap: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#222',
  },
  activityDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#C8F000',
  },
  activityInfo: { flex: 1 },
  activityTitle: { color: '#D1D5DB', fontSize: 13, fontWeight: '500' },
  activityTime: { color: '#6B7280', fontSize: 11, marginTop: 2 },
  gymSwitcher: { marginTop: 32 },
  chipScroll: { marginTop: 12, paddingLeft: 20 },
  gymChip: {
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 12,
    backgroundColor: '#1A1A1A',
    marginRight: 10,
    borderWidth: 1,
    borderColor: '#333',
  },
  gymChipActive: { backgroundColor: '#C8F000', borderColor: '#C8F000' },
  gymChipText: { color: '#9CA3AF', fontSize: 13, fontWeight: '600' },
  gymChipTextActive: { color: '#000', fontWeight: 'bold' },
});
