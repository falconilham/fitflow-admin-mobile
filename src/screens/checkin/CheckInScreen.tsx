import React, { useState, useEffect } from 'react';
import { useIsFocused } from '@react-navigation/native';
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
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAppSelector } from '../../store/hooks';
import { getMembersApi, checkInByQrApi } from '../../api/endpoints';
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
  useCodeScanner,
  CameraRuntimeError,
} from 'react-native-vision-camera';

interface Member {
  id: number;
  userId: number;
  name: string;
  memberId?: string;
  status: string;
  endDate?: string;
}

export default function CheckInScreen() {
  const insets = useSafeAreaInsets();
  const isFocused = useIsFocused();
  const { activeGymId } = useAppSelector(state => state.auth);
  const [tab, setTab] = useState<'scan' | 'manual'>('manual');
  const [search, setSearch] = useState('');
  const [members, setMembers] = useState<Member[]>([]);
  const [loading, setLoading] = useState(false);
  const [checkinLoading, setCheckinLoading] = useState<number | null>(null);

  const device = useCameraDevice('back');
  const { hasPermission, requestPermission } = useCameraPermission();
  const [isScanning, setIsScanning] = useState(false);
  const [cameraError, setCameraError] = useState<string | null>(null);

  useEffect(() => {
    if (tab === 'scan' && !hasPermission) {
      requestPermission();
    }
  }, [tab, hasPermission, requestPermission]);

  const handleCheckInByQr = async (qrData: string) => {
    if (!activeGymId) return;
    try {
      // QR codes are JSON strings: { userId, gymId, membershipId }
      let parsed: { userId?: number; gymId?: number; membershipId?: number };
      try {
        parsed = JSON.parse(qrData);
      } catch {
        Alert.alert('❌ QR Tidak Valid', 'Format QR code tidak dikenali.');
        return;
      }

      const { userId, gymId: scannedGymId, membershipId } = parsed;
      if (!userId || !scannedGymId || !membershipId) {
        Alert.alert(
          '❌ QR Tidak Valid',
          'QR code tidak mengandung data yang diperlukan.',
        );
        return;
      }

      const res = await checkInByQrApi(scannedGymId, userId, membershipId);
      const data = res.data;
      Alert.alert(
        data.access === 'granted'
          ? data.type === 'checkout'
            ? '✅ Check-out Berhasil'
            : '✅ Check-in Berhasil'
          : '❌ Check-in Ditolak',
        `${data.member?.name || 'Member'}: ${data.message || data.status}`,
        [
          {
            text: 'OK',
            onPress: () => setTimeout(() => setIsScanning(false), 2000),
          },
        ],
      );
    } catch (e: any) {
      Alert.alert(
        '❌ Ditolak',
        e?.response?.data?.message ??
          e?.response?.data?.error ??
          'Check-in gagal',
        [
          {
            text: 'OK',
            onPress: () => setTimeout(() => setIsScanning(false), 2000),
          },
        ],
      );
    }
  };

  const codeScanner = useCodeScanner({
    codeTypes: ['qr', 'ean-13'],
    onCodeScanned: codes => {
      if (isScanning || codes.length === 0) return;
      const scannedValue = codes[0].value;
      if (scannedValue) {
        setIsScanning(true);
        handleCheckInByQr(scannedValue);
      }
    },
  });

  const handleSearch = async () => {
    if (!search.trim() || !activeGymId) return;
    setLoading(true);
    try {
      const res = await getMembersApi(activeGymId, { search: search.trim() });
      setMembers(res.data.data ?? res.data.members ?? res.data);
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
      const res = await checkInByQrApi(activeGymId, member.userId, member.id);
      const data = res.data;
      const isCheckout = data.type === 'checkout';
      Alert.alert(
        data.access === 'granted'
          ? isCheckout
            ? '✅ Check-out Berhasil'
            : '✅ Check-in Berhasil'
          : '❌ Check-in Ditolak',
        `${member.name}: ${data.message ?? data.status}`,
      );
    } catch (e: any) {
      Alert.alert(
        '❌ Ditolak',
        e?.response?.data?.message ??
          e?.response?.data?.error ??
          'Check-in gagal',
      );
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
    <View style={[styles.container, { paddingTop: insets.top }]}>
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
              keyExtractor={(item, index) => String(item.id) + '_' + index}
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
        <View style={styles.cameraContainer}>
          {!hasPermission ? (
            <Text style={styles.scanSub}>Meminta izin kamera...</Text>
          ) : !device ? (
            <Text style={styles.scanSub}>
              Kamera tidak tersedia pada perangkat ini
            </Text>
          ) : cameraError ? (
            <View style={styles.errorContainer}>
              <Text style={styles.errorText}>⚠️ {cameraError}</Text>
              <Text style={styles.errorSub}>
                Tunggu sebentar selagi sistem mengunduh modul scanner (pastikan
                internet aktif).
              </Text>
              <TouchableOpacity
                style={styles.retryBtn}
                onPress={() => setCameraError(null)}
              >
                <Text style={styles.retryBtnText}>Coba Lagi</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <>
              <Camera
                style={StyleSheet.absoluteFill}
                device={device}
                isActive={isFocused && tab === 'scan' && !isScanning}
                codeScanner={codeScanner}
                onError={(e: CameraRuntimeError) => {
                  console.error('Camera Error:', e);
                  if (e.message.includes('barcode')) {
                    setCameraError('Menunggu modul scanner diunduh...');
                  } else {
                    setCameraError(e.message);
                  }
                }}
              />
              <View style={styles.overlay}>
                <View style={styles.scanBox} />
                <Text style={styles.overlayText}>
                  Arahkan QR Code ke dalam kotak
                </Text>
              </View>
            </>
          )}
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
  cameraContainer: {
    flex: 1,
    backgroundColor: '#000',
    justifyContent: 'center',
    alignItems: 'center',
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.5)',
  },
  scanBox: {
    width: 250,
    height: 250,
    borderWidth: 2,
    borderColor: '#C8F000',
    backgroundColor: 'transparent',
    borderRadius: 12,
  },
  overlayText: {
    color: '#fff',
    marginTop: 20,
    fontSize: 16,
    fontWeight: 'bold',
  },
  scanSub: {
    color: '#9CA3AF',
    fontSize: 13,
    textAlign: 'center',
    paddingHorizontal: 32,
  },
  emptyText: {
    color: '#6B7280',
    textAlign: 'center',
    marginTop: 40,
    fontSize: 14,
  },
  loadingSpinner: { marginTop: 32 },
  errorContainer: {
    padding: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  errorText: {
    color: '#f87171',
    fontSize: 14,
    fontWeight: 'bold',
    textAlign: 'center',
  },
  errorSub: {
    color: '#9CA3AF',
    fontSize: 12,
    textAlign: 'center',
    marginTop: 8,
  },
  retryBtn: {
    marginTop: 16,
    backgroundColor: '#333',
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#444',
  },
  retryBtnText: { color: '#fff', fontSize: 13, fontWeight: '600' },
});
