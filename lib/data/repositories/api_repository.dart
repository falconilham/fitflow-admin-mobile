import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../models/models.dart';

final apiRepositoryProvider = Provider<ApiRepository>((ref) => ApiRepository(ref));

class ApiRepository {
  ApiRepository(this._ref);
  final Ref _ref;

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _ref.read(dioProvider).post('/admin/login', data: {'email': email, 'password': password});
    return res.data as Map<String, dynamic>;
  }

  Future<AdminInfo> getMe() async {
    final res = await _ref.read(dioProvider).get('/admin/me');
    return AdminInfo.fromJson(res.data as Map<String, dynamic>);
  }

  // Dashboard
  Future<DashboardStats> getStats(int gymId) async {
    final res = await _ref.read(dioProvider).get('/admin/stats', queryParameters: {'gymId': gymId});
    return DashboardStats.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<GymSimple>> getMyGyms() async {
    final res = await _ref.read(dioProvider).get('/admin/my-gyms');
    final list = res.data as List<dynamic>;
    return list.map((e) => GymSimple.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Members — parses multiple response shapes
  Future<Map<String, dynamic>> getMembersRaw(int gymId,
      {String? search, String? status, int page = 1, int limit = 10}) async {
    final res = await _ref.read(dioProvider).get('/admin/members', queryParameters: {
      'gymId': gymId,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status != 'all') 'status': status,
      'page': page,
      'limit': limit,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<Member>> getMembers(int gymId,
      {String? search, String? status, int page = 1, int limit = 10}) async {
    final res = await _ref.read(dioProvider).get('/admin/members', queryParameters: {
      'gymId': gymId,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status != 'all') 'status': status,
      'page': page, 'limit': limit,
    });
    final data = res.data;
    List<dynamic> rows;
    if (data is List) {
      rows = data;
    } else if (data is Map) {
      rows = data['data'] as List<dynamic>? ?? data['members'] as List<dynamic>? ?? [];
    } else {
      rows = [];
    }
    return rows.map((e) => Member.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> getMembersTotal(int gymId, {String? search, String? status}) async {
    final res = await _ref.read(dioProvider).get('/admin/members', queryParameters: {
      'gymId': gymId,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status != 'all') 'status': status,
      'page': 1, 'limit': 10,
    });
    final data = res.data;
    if (data is Map) {
      return data['pagination']?['total'] as int? ?? data['total'] as int? ?? 0;
    }
    return 0;
  }

  Future<Member> getMemberDetail(int memberId) async {
    final res = await _ref.read(dioProvider).get('/admin/members/$memberId');
    return Member.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> createMember(int gymId, Map<String, dynamic> data) async {
    await _ref.read(dioProvider).post('/admin/members', data: {...data, 'gymId': gymId});
  }

  Future<void> updateMember(int memberId, Map<String, dynamic> data) async {
    await _ref.read(dioProvider).put('/admin/members/$memberId', data: data);
  }

  Future<void> deleteMember(int memberId) async {
    await _ref.read(dioProvider).delete('/admin/members/$memberId');
  }

  Future<void> importMembers(int gymId, Map<String, dynamic> data) async {
    await _ref.read(dioProvider).post('/admin/members/import', data: {...data, 'gymId': gymId});
  }

  Future<String> generateMemberId(int gymId) async {
    final res = await _ref.read(dioProvider).get('/admin/members/generate-id', queryParameters: {'gymId': gymId});
    return res.data['generatedId'] as String? ?? res.data['memberId'] as String? ?? '';
  }

  // Settings
  Future<GymSettings> getGymSettings(int gymId) async {
    final res = await _ref.read(dioProvider).get('/admin/settings', queryParameters: {'gymId': gymId});
    return GymSettings.fromJson(res.data as Map<String, dynamic>);
  }

  Future<GymSettings> updateGymSettings(int gymId, Map<String, dynamic> data) async {
    final res = await _ref.read(dioProvider).put('/admin/settings', data: {...data, 'gymId': gymId});
    return GymSettings.fromJson(res.data as Map<String, dynamic>);
  }

  // Packages
  Future<List<MembershipPackage>> getPackages(int gymId) async {
    final res = await _ref.read(dioProvider).get('/admin/membership-packages', queryParameters: {'gymId': gymId});
    return (res.data as List<dynamic>).map((e) => MembershipPackage.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Check-in — QR payload is JSON {userId, gymId, membershipId}
  Future<Map<String, dynamic>> checkInByQr(int gymId, int userId, int membershipId) async {
    final res = await _ref.read(dioProvider).post('/admin/check-in',
        data: {'gymId': gymId, 'userId': userId, 'membershipId': membershipId});
    return res.data as Map<String, dynamic>;
  }

  Future<List<CheckInRecord>> getRecentCheckIns(int gymId, {int limit = 5}) async {
    final res = await _ref.read(dioProvider).get('/admin/check-ins', queryParameters: {'gymId': gymId, 'limit': limit});
    final data = res.data;
    List<dynamic> list;
    if (data is List) list = data;
    else if (data is Map) list = data['data'] as List<dynamic>? ?? data['checkIns'] as List<dynamic>? ?? [];
    else list = [];
    return list.map((e) => CheckInRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Store — Products
  Future<List<Product>> getProducts(int gymId) async {
    final res = await _ref.read(dioProvider).get('/admin/products', queryParameters: {'gymId': gymId});
    final data = res.data;
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map) {
      list = data['data'] as List<dynamic>? ?? data['products'] as List<dynamic>? ?? [];
    } else {
      list = [];
    }
    return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createProduct(Map<String, dynamic> data) async {
    await _ref.read(dioProvider).post('/admin/products', data: data);
  }

  Future<void> updateProduct(int id, Map<String, dynamic> data) async {
    await _ref.read(dioProvider).put('/admin/products/$id', data: data);
  }

  Future<void> deleteProduct(int id) async {
    await _ref.read(dioProvider).delete('/admin/products/$id');
  }

  Future<void> createTransaction(Map<String, dynamic> data) async {
    await _ref.read(dioProvider).post('/admin/transactions', data: data);
  }

  Future<List<Map<String, dynamic>>> getTransactions(int gymId) async {
    final res = await _ref.read(dioProvider).get('/admin/transactions', queryParameters: {'gymId': gymId});
    final data = res.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    if (data is Map) return (data['data'] as List? ?? data['transactions'] as List? ?? []).cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getExpenses(int gymId) async {
    final res = await _ref.read(dioProvider).get('/admin/expenses', queryParameters: {'gymId': gymId});
    final data = res.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    if (data is Map) return (data['data'] as List? ?? []).cast<Map<String, dynamic>>();
    return [];
  }

  Future<void> createExpense(Map<String, dynamic> data) async {
    await _ref.read(dioProvider).post('/admin/expenses', data: data);
  }

  Future<List<Map<String, dynamic>>> getManagers(int gymId) async {
    final res = await _ref.read(dioProvider).get('/admin/managers', queryParameters: {'gymId': gymId});
    final data = res.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    if (data is Map) return (data['data'] as List? ?? []).cast<Map<String, dynamic>>();
    return [];
  }

  Future<void> createManager(int gymId, Map<String, dynamic> data) async {
    await _ref.read(dioProvider).post('/admin/managers', data: {...data, 'gymId': gymId});
  }

  Future<void> updateManager(int id, Map<String, dynamic> data) async {
    await _ref.read(dioProvider).put('/admin/managers/$id', data: data);
  }

  Future<void> deleteManager(int id) async {
    await _ref.read(dioProvider).delete('/admin/managers/$id');
  }

  Future<List<Map<String, dynamic>>> getTrainers(int gymId) async {
    final res = await _ref.read(dioProvider).get('/admin/trainers', queryParameters: {'gymId': gymId, 'limit': 100});
    final data = res.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    if (data is Map) return (data['data'] as List? ?? []).cast<Map<String, dynamic>>();
    return [];
  }

  Future<void> createTrainer(int gymId, Map<String, dynamic> data) async {
    await _ref.read(dioProvider).post('/admin/trainers', data: {...data, 'gymId': gymId});
  }

  Future<void> updateTrainer(int id, int gymId, Map<String, dynamic> data) async {
    await _ref.read(dioProvider).put('/admin/trainers/$id', data: {...data, 'gymId': gymId});
  }

  Future<void> deleteTrainer(int id) async {
    await _ref.read(dioProvider).delete('/admin/trainers/$id');
  }

  Future<List<Map<String, dynamic>>> getSessions(int gymId) async {
    final res = await _ref.read(dioProvider).get('/admin/sessions', queryParameters: {'gymId': gymId});
    final data = res.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    if (data is Map) return (data['data'] as List? ?? []).cast<Map<String, dynamic>>();
    return [];
  }

  Future<void> createSession(Map<String, dynamic> data) async {
    await _ref.read(dioProvider).post('/admin/sessions', data: data);
  }

  Future<void> updateSession(int id, Map<String, dynamic> data) async {
    await _ref.read(dioProvider).put('/admin/sessions/$id', data: data);
  }

  Future<void> deleteSession(int id) async {
    await _ref.read(dioProvider).delete('/admin/sessions/$id');
  }

  Future<List<Map<String, dynamic>>> getActivity(int gymId, {int limit = 50}) async {
    final res = await _ref.read(dioProvider).get('/admin/check-ins', queryParameters: {'gymId': gymId, 'limit': limit});
    final data = res.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    if (data is Map) return (data['data'] as List? ?? data['checkIns'] as List? ?? []).cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getRevenueAnalytics(int gymId, {String period = 'monthly'}) async {
    final res = await _ref.read(dioProvider).get('/admin/revenue', queryParameters: {'gymId': gymId, 'period': period});
    if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
    return {};
  }

  Future<Map<String, dynamic>> getPeakHours(int gymId) async {
    final res = await _ref.read(dioProvider).get('/admin/reports/peak-hours', queryParameters: {'gymId': gymId});
    if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
    return {};
  }

  // Keep old method as alias for backward compat
  Future<Map<String, dynamic>> getReports(int gymId) => getPeakHours(gymId);
}
