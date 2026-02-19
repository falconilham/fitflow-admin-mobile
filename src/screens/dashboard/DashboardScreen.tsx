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
import { logout, setActiveGym } from '../../store/authSlice';
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

const StatCard = ({
  label,
  value,
  color,
}: {
  label: string;
  value: string;
  color: string;
}) => (
  <View style={[styles.statCard, { borderLeftColor: color }]}>
    <Text style={styles.statValue}>{value}</Text>
    <Text style={styles.statLabel}>{label}</Text>
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
      if (!activeGymId) return;
      const [statsRes, gymsRes] = await Promise.all([
        getStatsApi(activeGymId),
        admin?.role === 'owner'
          ? getMyGymsApi()
          : Promise.resolve({ data: [] }),
      ]);
      setStats(statsRes.data);
      if (gymsRes.data.length > 0) setGyms(gymsRes.data);
    } catch (e) {
      console.error('Dashboard fetch error:', e);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [activeGymId, admin?.role]);

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
      refreshControl={
        <RefreshControl
          refreshing={refreshing}
          onRefresh={onRefresh}
          tintColor="#C8F000"
        />
      }
    >
      {/* Header */}
      <View style={styles.header}>
        <View>
          <Text style={styles.greeting}>Selamat datang,</Text>
          <Text style={styles.adminName}>{admin?.name} 👋</Text>
          <Text style={styles.gymName}>{admin?.Gym?.name}</Text>
        </View>
        <TouchableOpacity
          onPress={() => dispatch(logout())}
          style={styles.logoutBtn}
        >
          <Text style={styles.logoutText}>Keluar</Text>
        </TouchableOpacity>
      </View>

      {/* Gym Switcher (Owner only) */}
      {admin?.role === 'owner' && gyms.length > 1 && (
        <View style={styles.gymSwitcher}>
          <Text style={styles.sectionTitle}>Pilih Gym</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false}>
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

      {/* Stats Cards */}
      <Text style={styles.sectionTitle}>Ringkasan Hari Ini</Text>
      <View style={styles.statsGrid}>
        <StatCard
          label="Total Member"
          value={String(stats?.totalMembers ?? 0)}
          color="#C8F000"
        />
        <StatCard
          label="Member Aktif"
          value={String(stats?.activeMembers ?? 0)}
          color="#60a5fa"
        />
        <StatCard
          label="Check-in Hari Ini"
          value={String(stats?.dailyCheckIns ?? 0)}
          color="#4ade80"
        />
        <StatCard
          label="Pengeluaran Bulan Ini"
          value={formatCurrency(stats?.expenses ?? 0)}
          color="#f87171"
        />
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
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    padding: 20,
    paddingTop: 16,
    backgroundColor: '#1E1E1E',
    borderBottomWidth: 1,
    borderBottomColor: '#333',
  },
  greeting: { color: '#9CA3AF', fontSize: 13 },
  adminName: { color: '#fff', fontSize: 20, fontWeight: 'bold', marginTop: 2 },
  gymName: { color: '#C8F000', fontSize: 13, marginTop: 2 },
  logoutBtn: {
    backgroundColor: '#2C2C2C',
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#333',
  },
  logoutText: { color: '#f87171', fontSize: 13, fontWeight: '600' },
  gymSwitcher: { paddingHorizontal: 16, paddingTop: 16 },
  sectionTitle: {
    color: '#9CA3AF',
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    paddingHorizontal: 16,
    paddingTop: 20,
    paddingBottom: 10,
  },
  gymChip: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: '#2C2C2C',
    marginRight: 8,
    borderWidth: 1,
    borderColor: '#444',
  },
  gymChipActive: { backgroundColor: '#C8F000', borderColor: '#C8F000' },
  gymChipText: { color: '#9CA3AF', fontSize: 14 },
  gymChipTextActive: { color: '#000', fontWeight: 'bold' },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    paddingHorizontal: 12,
    gap: 12,
    paddingBottom: 24,
  },
  statCard: {
    backgroundColor: '#1E1E1E',
    borderRadius: 12,
    padding: 16,
    width: '46%',
    borderLeftWidth: 4,
    borderWidth: 1,
    borderColor: '#333',
  },
  statValue: { color: '#fff', fontSize: 24, fontWeight: 'bold' },
  statLabel: { color: '#9CA3AF', fontSize: 12, marginTop: 4 },
});
