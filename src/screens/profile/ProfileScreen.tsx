import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert } from 'react-native';
import { useAppDispatch, useAppSelector } from '../../store/hooks';
import { logout } from '../../store/authSlice';
import {
  UserRound,
  LogOut,
  ChevronRight,
  Settings,
  ShieldCheck,
} from 'lucide-react-native';

export default function ProfileScreen() {
  const dispatch = useAppDispatch();
  const { admin } = useAppSelector(state => state.auth);

  const handleLogout = () => {
    Alert.alert('Log Out', 'Are you sure you want to log out?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Log Out',
        style: 'destructive',
        onPress: () => dispatch(logout()),
      },
    ]);
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.avatarContainer}>
          <UserRound size={40} color="#C8F000" strokeWidth={1.5} />
        </View>
        <Text style={styles.userName}>{admin?.name || 'Admin User'}</Text>
        <Text style={styles.userRole}>
          {admin?.role?.toUpperCase() || 'MANAGER'}
        </Text>
      </View>

      {/* Menu Options */}
      <View style={styles.menuSection}>
        <TouchableOpacity style={styles.menuItem}>
          <View style={styles.menuItemLeft}>
            <View style={[styles.iconBox, styles.iconBoxGrey]}>
              <Settings size={20} color="#9CA3AF" />
            </View>
            <Text style={styles.menuItemText}>Account Settings</Text>
          </View>
          <ChevronRight size={20} color="#374151" />
        </TouchableOpacity>

        <TouchableOpacity style={styles.menuItem}>
          <View style={styles.menuItemLeft}>
            <View style={[styles.iconBox, styles.iconBoxGrey]}>
              <ShieldCheck size={20} color="#9CA3AF" />
            </View>
            <Text style={styles.menuItemText}>Privacy & Security</Text>
          </View>
          <ChevronRight size={20} color="#374151" />
        </TouchableOpacity>

        <View style={styles.divider} />

        <TouchableOpacity style={styles.logoutItem} onPress={handleLogout}>
          <View style={styles.menuItemLeft}>
            <View style={[styles.iconBox, styles.iconBoxRed]}>
              <LogOut size={20} color="#ef4444" />
            </View>
            <Text style={styles.logoutText}>Sign Out</Text>
          </View>
        </TouchableOpacity>
      </View>

      <View style={styles.footer}>
        <Text style={styles.versionText}>FitFlow Admin v1.0.0</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0A0A0A' },
  header: {
    alignItems: 'center',
    paddingTop: 60,
    paddingBottom: 40,
    backgroundColor: '#111',
    borderBottomWidth: 1,
    borderBottomColor: '#222',
  },
  avatarContainer: {
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: '#1A1A1A',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: '#C8F000',
    marginBottom: 16,
    shadowColor: '#C8F000',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.2,
    shadowRadius: 15,
  },
  userName: {
    color: '#fff',
    fontSize: 24,
    fontWeight: '900',
    letterSpacing: -0.5,
  },
  userRole: {
    color: '#6B7280',
    fontSize: 13,
    fontWeight: '700',
    marginTop: 4,
    letterSpacing: 1,
  },
  menuSection: { marginTop: 20, paddingHorizontal: 20 },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 16,
  },
  menuItemLeft: { flexDirection: 'row', alignItems: 'center', gap: 16 },
  iconBox: {
    width: 44,
    height: 44,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
  },
  iconBoxGrey: { backgroundColor: '#1A1A1A' },
  iconBoxRed: { backgroundColor: '#fee2e2' },
  menuItemText: { color: '#D1D5DB', fontSize: 16, fontWeight: '600' },

  divider: { height: 1, backgroundColor: '#222', marginVertical: 8 },
  logoutItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 16,
  },
  logoutText: { color: '#ef4444', fontSize: 16, fontWeight: '700' },
  footer: { marginTop: 'auto', marginBottom: 40, alignItems: 'center' },
  versionText: { color: '#4B5563', fontSize: 12, fontWeight: '500' },
});
