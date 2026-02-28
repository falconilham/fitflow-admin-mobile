import React, { useCallback, useState } from 'react';
import { useFocusEffect } from '@react-navigation/native';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { BottomTabNavigationProp } from '@react-navigation/bottom-tabs';
import { CompositeNavigationProp } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useAppDispatch, useAppSelector } from '../../store/hooks';
import { setActiveGym } from '../../store/authSlice';
import {
  getStatsApi,
  getMyGymsApi,
  getRecentCheckInsApi,
} from '../../api/endpoints';
import { formatCurrency, formatDate } from '../../utils/format';
import {
  Users as UsersIcon,
  UserCheck,
  Wallet,
  Plus,
  RefreshCw,
  History,
  UserPlus,
} from 'lucide-react-native';
import {
  MainTabParamList,
  MembersStackParamList,
} from '../../navigation/types';

// Composite type: we're inside the Tab, but need to jump into Members stack
type DashboardNavProp = CompositeNavigationProp<
  BottomTabNavigationProp<MainTabParamList, 'Dashboard'>,
  NativeStackNavigationProp<MembersStackParamList>
>;

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

interface CheckInRecord {
  id: number;
  memberName: string;
  memberId?: string;
  checkedInAt: string;
}

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
      <Text
        style={styles.statValue}
        numberOfLines={1}
        adjustsFontSizeToFit
        minimumFontScale={0.6}
      >
        {value}
      </Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  </View>
);

export default function DashboardScreen() {
  const navigation = useNavigation<DashboardNavProp>();
  const dispatch = useAppDispatch();
  const { admin, activeGymId } = useAppSelector(state => state.auth);
  const [stats, setStats] = useState<Stats | null>(null);
  const [gyms, setGyms] = useState<Gym[]>([]);
  const [recentCheckIns, setRecentCheckIns] = useState<CheckInRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  // Derive the active gym's display name from the list (handles gym switching)
  const activeGymName =
    gyms.find(g => g.id === activeGymId)?.name ?? admin?.Gym?.name ?? 'My Gym';

  const fetchData = useCallback(
    async (currentActiveGymId: number | null = activeGymId) => {
      try {
        let gymId = currentActiveGymId;

        // Owner with no gym yet — fetch their gyms first
        if (!gymId && admin?.role === 'owner') {
          const gymsRes = await getMyGymsApi();
          console.log({ gymsRes });
          if (gymsRes.data.length > 0) {
            setGyms(gymsRes.data);
            gymId = gymsRes.data[0].id;
            dispatch(setActiveGym(gymsRes.data[0].id));
          }
        }
        if (!gymId) return;

        // Fetch stats + gym list + recent check-ins in parallel
        const [statsRes, gymsRes, checkInsRes] = await Promise.all([
          getStatsApi(gymId),
          admin?.role === 'owner' ? getMyGymsApi() : Promise.resolve(null),
          getRecentCheckInsApi(gymId, 5),
        ]);

        setStats(statsRes.data);

        if (gymsRes && gymsRes.data.length > 0) {
          setGyms(gymsRes.data);
        }

        // Normalise: backend may return array directly or { data: [...] }
        const checkInsData = Array.isArray(checkInsRes.data)
          ? checkInsRes.data
          : checkInsRes.data?.data ?? checkInsRes.data?.checkIns ?? [];
        setRecentCheckIns(checkInsData.slice(0, 5));
      } catch (e: any) {
        console.log({ e });
        console.error('Dashboard fetch error:', e?.message || e);
      } finally {
        setLoading(false);
        setRefreshing(false);
      }
    },
    [activeGymId, admin?.role, dispatch],
  );

  // Only fetch when this tab is actually focused — avoids background API calls
  // when other tabs are active (bottom tabs keep all screens mounted)
  useFocusEffect(
    useCallback(() => {
      fetchData();
    }, [fetchData]),
  );

  const onRefresh = () => {
    setRefreshing(true);
    fetchData();
  };

  // Navigate into Members tab then push the desired screen
  const goToAddMember = () => {
    navigation.navigate('Members');
    // Small delay lets the tab switch settle before pushing onto the stack
    setTimeout(() => navigation.navigate('AddMember'), 100);
  };

  const goToRenewMember = () => {
    navigation.navigate('Members');
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
      {/* Header — shows the currently selected gym name */}
      <View style={styles.header}>
        <View style={styles.headerTop}>
          <View>
            <Text style={styles.gymName}>{activeGymName}</Text>
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
          label="Check-in Hari Ini"
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

      {/* Quick Actions — wired to navigation */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>
        <View style={styles.actionGrid}>
          <TouchableOpacity style={styles.actionCard} onPress={goToAddMember}>
            <View style={[styles.actionIcon, styles.actionIconAdd]}>
              <UserPlus size={20} color="#000" />
            </View>
            <Text style={styles.actionLabel}>Add Member</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.actionCard} onPress={goToRenewMember}>
            <View style={[styles.actionIcon, styles.actionIconRenew]}>
              <RefreshCw size={20} color="#fff" />
            </View>
            <Text style={styles.actionLabel}>Renew</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Recent Activity — real data from API */}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Recent Activity</Text>
          <TouchableOpacity onPress={() => navigation.navigate('CheckIn')}>
            <Text style={styles.viewAll}>View All</Text>
          </TouchableOpacity>
        </View>
        <View style={styles.activityList}>
          {recentCheckIns.length > 0 ? (
            recentCheckIns.map(record => (
              <View key={record.id} style={styles.activityItem}>
                <View style={styles.activityDot} />
                <View style={styles.activityInfo}>
                  <Text style={styles.activityTitle}>
                    {record.memberName} check-in
                  </Text>
                  <Text style={styles.activityTime}>
                    {formatDate(record.checkedInAt)}
                  </Text>
                </View>
                <History size={16} color="#4B5563" />
              </View>
            ))
          ) : (
            // Graceful empty state when there are no check-ins yet
            <View style={styles.activityItem}>
              <View style={[styles.activityDot, styles.activityDotEmpty]} />
              <View style={styles.activityInfo}>
                <Text style={styles.activityTitle}>
                  Belum ada check-in hari ini
                </Text>
                <Text style={styles.activityTime}>—</Text>
              </View>
            </View>
          )}
        </View>
      </View>

      {/* Gym Switcher (Owner only) */}
      {admin?.role === 'owner' && gyms.length > 1 && (
        <View style={styles.gymSwitcher}>
          <Text style={[styles.sectionTitle, styles.switherTitle]}>
            Switch Gym
          </Text>
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
    marginTop: 16,
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
  activityDotEmpty: { backgroundColor: '#374151' },
  activityInfo: { flex: 1 },
  activityTitle: { color: '#D1D5DB', fontSize: 13, fontWeight: '500' },
  activityTime: { color: '#6B7280', fontSize: 11, marginTop: 2 },
  gymSwitcher: { marginTop: 32 },
  switherTitle: { paddingHorizontal: 20 },
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
