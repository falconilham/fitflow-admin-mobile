import React, { useEffect, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { RouteProp, useRoute, useNavigation } from '@react-navigation/native';
import { useAppSelector } from '../../store/hooks';
import {
  getMemberDetailApi,
  updateMemberApi,
  getGymSettingsPublicApi,
  generateMemberIdApi,
} from '../../api/endpoints';
import { MembersStackParamList } from '../../navigation/types';

type RouteProps = RouteProp<MembersStackParamList, 'EditMember'>;

export default function EditMemberScreen() {
  const route = useRoute<RouteProps>();
  const navigation = useNavigation();
  const { memberId } = route.params;
  const { activeGymId } = useAppSelector(state => state.auth);

  const [form, setForm] = useState({
    name: '',
    email: '',
    phone: '',
    memberId: '',
  });
  const [loading, setLoading] = useState(false);
  const [fetching, setFetching] = useState(true);
  const [generatingId, setGeneratingId] = useState(false);

  // Settings from /admin/settings/public
  const [mandatoryContact, setMandatoryContact] = useState<'email' | 'phone'>(
    'email',
  );
  const [requireMemberId, setRequireMemberId] = useState(false);

  const phoneRequired = mandatoryContact === 'phone';
  const emailRequired = mandatoryContact === 'email';

  const fetchData = useCallback(async () => {
    try {
      const [memberRes, settingsRes] = await Promise.all([
        getMemberDetailApi(memberId),
        activeGymId
          ? getGymSettingsPublicApi(activeGymId)
          : Promise.resolve(null),
      ]);

      const m = memberRes.data;
      setForm({
        name: m.User?.name ?? m.name ?? '',
        email: m.User?.email ?? m.email ?? '',
        phone: m.User?.phone ?? m.phone ?? '',
        memberId: m.memberId ?? '',
      });

      if (settingsRes) {
        setMandatoryContact(settingsRes.data.mandatoryContact || 'email');
        setRequireMemberId(settingsRes.data.requireMemberId || false);
      }
    } catch {
      Alert.alert('Error', 'Gagal memuat data member');
    } finally {
      setFetching(false);
    }
  }, [memberId, activeGymId]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const handleAutoId = async () => {
    if (!activeGymId) return;
    setGeneratingId(true);
    try {
      const res = await generateMemberIdApi(activeGymId);
      setForm(prev => ({ ...prev, memberId: res.data.generatedId }));
    } catch {
      Alert.alert('Error', 'Gagal generate Member ID');
    } finally {
      setGeneratingId(false);
    }
  };

  const handleSubmit = async () => {
    if (!form.name.trim()) {
      Alert.alert('Error', 'Nama wajib diisi');
      return;
    }
    if (emailRequired && !form.email.trim()) {
      Alert.alert('Error', 'Email wajib diisi');
      return;
    }
    if (phoneRequired && !form.phone.trim()) {
      Alert.alert('Error', 'No. HP wajib diisi');
      return;
    }
    if (requireMemberId && !form.memberId.trim()) {
      Alert.alert('Error', 'Member ID wajib diisi');
      return;
    }

    setLoading(true);
    try {
      await updateMemberApi(memberId, {
        name: form.name,
        email: form.email,
        phone: form.phone,
        memberId: form.memberId || undefined,
      });
      Alert.alert('Berhasil', 'Data member berhasil diperbarui', [
        { text: 'OK', onPress: () => navigation.goBack() },
      ]);
    } catch (e: any) {
      Alert.alert(
        'Error',
        e?.response?.data?.message ??
          e?.response?.data?.error ??
          'Gagal memperbarui member',
      );
    } finally {
      setLoading(false);
    }
  };

  if (fetching) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color="#C8F000" size="large" />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} keyboardShouldPersistTaps="handled">
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Informasi Member</Text>

        {/* Name */}
        <View style={styles.fieldGroup}>
          <Text style={styles.label}>Nama Lengkap *</Text>
          <TextInput
            style={styles.input}
            placeholderTextColor="#666"
            placeholder="John Doe"
            autoCapitalize="words"
            value={form.name}
            onChangeText={t => setForm(prev => ({ ...prev, name: t }))}
          />
        </View>

        {/* Member ID */}
        <View style={styles.fieldGroup}>
          <Text style={styles.label}>
            Member ID{requireMemberId ? ' *' : ' (Opsional)'}
          </Text>
          <View style={styles.inputRow}>
            <TextInput
              style={[styles.input, styles.inputFlex]}
              placeholderTextColor="#666"
              placeholder="e.g. MEM-001"
              autoCapitalize="characters"
              value={form.memberId}
              onChangeText={t => setForm(prev => ({ ...prev, memberId: t }))}
            />
            <TouchableOpacity
              style={styles.autoBtn}
              onPress={handleAutoId}
              disabled={generatingId}
            >
              {generatingId ? (
                <ActivityIndicator color="#000" size="small" />
              ) : (
                <Text style={styles.autoBtnText}>Auto</Text>
              )}
            </TouchableOpacity>
          </View>
        </View>

        {/* Email */}
        <View style={styles.fieldGroup}>
          <Text style={styles.label}>
            Email{emailRequired ? ' *' : ' (Opsional)'}
          </Text>
          <TextInput
            style={styles.input}
            placeholderTextColor="#666"
            placeholder={emailRequired ? 'john@email.com' : 'Email (Opsional)'}
            keyboardType="email-address"
            autoCapitalize="none"
            value={form.email}
            onChangeText={t => setForm(prev => ({ ...prev, email: t }))}
          />
        </View>

        {/* Phone */}
        <View style={styles.fieldGroup}>
          <Text style={styles.label}>
            No. HP{phoneRequired ? ' *' : ' (Opsional)'}
          </Text>
          <TextInput
            style={styles.input}
            placeholderTextColor="#666"
            placeholder={phoneRequired ? '08xxxxxxxxxx' : 'No. HP (Opsional)'}
            keyboardType="phone-pad"
            value={form.phone}
            onChangeText={t => setForm(prev => ({ ...prev, phone: t }))}
          />
        </View>
      </View>

      <TouchableOpacity
        style={[styles.submitBtn, loading && styles.submitBtnDisabled]}
        onPress={handleSubmit}
        disabled={loading}
      >
        {loading ? (
          <ActivityIndicator color="#000" />
        ) : (
          <Text style={styles.submitBtnText}>Simpan Perubahan</Text>
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
    marginBottom: 16,
  },
  fieldGroup: { marginBottom: 14 },
  label: { color: '#9CA3AF', fontSize: 13, marginBottom: 6 },
  inputRow: { flexDirection: 'row', gap: 8 },
  inputFlex: { flex: 1 },
  input: {
    backgroundColor: '#2C2C2C',
    color: '#fff',
    borderRadius: 10,
    paddingHorizontal: 14,
    paddingVertical: 11,
    fontSize: 15,
    borderWidth: 1,
    borderColor: '#444',
  },
  autoBtn: {
    backgroundColor: '#C8F000',
    borderRadius: 10,
    paddingHorizontal: 16,
    justifyContent: 'center',
    alignItems: 'center',
    minWidth: 64,
  },
  autoBtnText: { fontWeight: 'bold', color: '#000', fontSize: 13 },
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
