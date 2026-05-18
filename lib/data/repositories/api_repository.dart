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
    final data = res.data as Map<String, dynamic>;
    // Handle both 'expenses' and 'totalExpenses' from backend
    final expenses = (data['expenses'] ?? data['totalExpenses'] ?? 0) as num;
    return DashboardStats(
      totalMembers: (data['totalMembers'] ?? 0) as int,
      activeMembers: (data['activeMembers'] ?? 0) as int,
      dailyCheckIns: (data['dailyCheckIns'] ?? 0) as int,
      expenses: expenses.toDouble(),
    );
  }

  Future<List<GymSimple>> getMyGyms() async {
    final res = await _ref.read(dioProvider).get('/admin/my-gyms');
    final data = res.data;
    if (data is! List) return [];
    return data.map((e) => GymSimple.fromJson(e as Map<String, dynamic>)).toList();
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

  Future<void> deleteMember(int memberId, {int? gymId}) async {
    await _ref.read(dioProvider).delete('/admin/members/$memberId',
        queryParameters: {if (gymId != null) 'gymId': gymId});
  }

  // Restore archived (soft-deleted) member — owner/super_admin only
  Future<void> restoreMember(int memberId, {int? gymId}) async {
    await _ref.read(dioProvider).post('/admin/members/$memberId/restore',
        queryParameters: {if (gymId != null) 'gymId': gymId});
  }

  // Permanently delete a member and all related history — owner/super_admin only
  Future<void> permanentDeleteMember(int memberId, {int? gymId}) async {
    await _ref.read(dioProvider).delete(
          '/admin/members/$memberId/permanent',
          queryParameters: {if (gymId != null) 'gymId': gymId},
        );
  }

  // Suspend / unsuspend member with optional reason + auto-reactivate date.
  // endDate: 'YYYY-MM-DD' string or null
  Future<void> suspendMember(
    int memberId, {
    required bool suspended,
    String? reason,
    String? endDate,
  }) async {
    await _ref.read(dioProvider).patch(
      '/admin/members/$memberId/suspend',
      data: {
        'suspended': suspended,
        if (suspended) 'reason': reason,
        if (suspended && endDate != null) 'endDate': endDate,
      },
    );
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
    final data = res.data;
    if (data is! List) return [];
    return data.map((e) => MembershipPackage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MembershipPackage> createPackage(int gymId, Map<String, dynamic> data) async {
    final res = await _ref.read(dioProvider).post('/admin/membership-packages', data: {...data, 'gymId': gymId});
    return MembershipPackage.fromJson(res.data as Map<String, dynamic>);
  }

  Future<MembershipPackage> updatePackage(int id, Map<String, dynamic> data) async {
    final res = await _ref.read(dioProvider).put('/admin/membership-packages/$id', data: data);
    return MembershipPackage.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deletePackage(int id) async {
    await _ref.read(dioProvider).delete('/admin/membership-packages/$id');
  }

  // Check-in — QR payload is JSON {userId, gymId, membershipId}
  Future<Map<String, dynamic>> checkInByQr(int gymId, int userId, int membershipId) async {
    final res = await _ref.read(dioProvider).post('/admin/check-in',
        data: {'gymId': gymId, 'userId': userId, 'membershipId': membershipId});
    if (res.data is! Map) return {'success': false, 'message': 'Invalid server response'};
    return res.data as Map<String, dynamic>;
  }

  Future<List<CheckInRecord>> getRecentCheckIns(int gymId, {int limit = 5}) async {
    final res = await _ref.read(dioProvider).get('/admin/check-ins', queryParameters: {'gymId': gymId, 'limit': limit});
    final data = res.data;
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map) {
      list = data['data'] as List<dynamic>? ?? data['checkIns'] as List<dynamic>? ?? [];
    } else {
      list = [];
    }
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
    final res = await _ref.read(dioProvider).get('/admin/activity-logs', queryParameters: {'gymId': gymId, 'limit': limit});
    final data = res.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    if (data is Map) return (data['data'] as List? ?? data['activityLogs'] as List? ?? []).cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> getTrainerPackages(int gymId, {int? memberId, int? trainerId, String? status}) async {
    final res = await _ref.read(dioProvider).get('/admin/trainer-packages', queryParameters: {
      'gymId': gymId,
      if (memberId != null) 'memberId': memberId,
      if (trainerId != null) 'trainerId': trainerId,
      if (status != null) 'status': status,
    });
    final data = res.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    if (data is Map) return (data['data'] as List? ?? data['trainerPackages'] as List? ?? data['packages'] as List? ?? []).cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getRevenueAnalytics(int gymId, {String period = 'monthly'}) async {
    final res = await _ref.read(dioProvider).get('/admin/revenue', queryParameters: {'gymId': gymId, 'period': period});
    if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
    return {};
  }

  // Revenue endpoint with full filter support — returns combined tx + expenses
  // shape: { summary, breakdown, pagination, transactions: [...] }
  Future<Map<String, dynamic>> getRevenueDetails(
    int gymId, {
    String? search,
    String? startDate,
    String? endDate,
    String? type,
    String? paymentMethod,
    String? status,
    int page = 1,
    int limit = 25,
  }) async {
    final res = await _ref.read(dioProvider).get('/admin/revenue', queryParameters: {
      'gymId': gymId,
      if (search != null && search.isNotEmpty) 'search': search,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      if (type != null && type != 'ALL') 'type': type,
      if (paymentMethod != null && paymentMethod != 'ALL') 'paymentMethod': paymentMethod,
      if (status != null) 'status': status,
      'page': page,
      'limit': limit,
    });
    if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
    return {};
  }

  Future<void> archiveTransaction(int id) async {
    await _ref.read(dioProvider).delete('/admin/transactions/$id');
  }

  Future<void> restoreTransaction(int id) async {
    await _ref.read(dioProvider).post('/admin/transactions/$id/restore');
  }

  Future<void> archiveExpense(int id) async {
    await _ref.read(dioProvider).delete('/admin/expenses/$id');
  }

  Future<void> restoreExpense(int id) async {
    await _ref.read(dioProvider).post('/admin/expenses/$id/restore');
  }

  Future<Map<String, dynamic>> getPeakHours(int gymId) async {
    final res = await _ref.read(dioProvider).get('/admin/reports/peak-hours', queryParameters: {'gymId': gymId});
    if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
    return {};
  }

  // Keep old method as alias for backward compat
  Future<Map<String, dynamic>> getReports(int gymId) => getPeakHours(gymId);

  // ── Member Session / Visit History (wallet usage logs) ───────────────────
  Future<List<SessionLog>> getMemberSessionHistory(int memberId) async {
    final res = await _ref.read(dioProvider).get('/admin/members/$memberId/session-history');
    final data = res.data;
    List<dynamic> rows;
    if (data is List) {
      rows = data;
    } else if (data is Map) {
      rows = data['data'] as List<dynamic>? ?? data['logs'] as List<dynamic>? ?? [];
    } else {
      rows = [];
    }
    return rows.map((e) => SessionLog.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Manually log a visit (decrement balance)
  Future<Map<String, dynamic>> logMemberVisit(int memberId, {int? minutesUsed}) async {
    final res = await _ref.read(dioProvider).post(
      '/admin/members/$memberId/log-visit',
      data: {if (minutesUsed != null) 'minutesUsed': minutesUsed},
    );
    if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
    return {};
  }

  // ── Leaderboard ──────────────────────────────────────────────────────────
  // category: 'check_ins' | 'spending' | 'sessions' | 'revenue'
  // period:   'month' | 'quarter' | 'half_year' | 'year'
  Future<List<LeaderboardEntry>> getLeaderboard(
    int gymId, {
    String category = 'check_ins',
    String period = 'month',
  }) async {
    final res = await _ref.read(dioProvider).get('/admin/leaderboard', queryParameters: {
      'gymId': gymId,
      'category': category,
      'period': period,
    });
    final data = res.data;
    List<dynamic> rows;
    if (data is List) {
      rows = data;
    } else if (data is Map) {
      rows = data['results'] as List<dynamic>? ?? data['data'] as List<dynamic>? ?? [];
    } else {
      rows = [];
    }
    return rows.map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Investor / Executive Report ──────────────────────────────────────────
  Future<InvestorReport> getInvestorReport(
    int gymId, {
    String? startDate,
    String? endDate,
  }) async {
    final res = await _ref.read(dioProvider).get(
      '/admin/reports/investor',
      queryParameters: {
        'gymId': gymId,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      },
    );
    if (res.data is Map<String, dynamic>) {
      return InvestorReport.fromJson(res.data as Map<String, dynamic>);
    }
    return const InvestorReport(
      grossRevenue: 0,
      totalExpenses: 0,
      netProfit: 0,
      profitMargin: 0,
      membershipRev: 0,
      personalTrainingRev: 0,
      posRev: 0,
      newMembers: 0,
      totalActiveMembers: 0,
      churnedMembers: 0,
      churnRate: 0,
    );
  }

  // ── Group Classes ──────────────────────────────────────────────────────────
  Future<List<GymClass>> getClasses(int gymId, {String? day, int? categoryId, int? trainerId, bool? isActive}) async {
    final res = await _ref.read(dioProvider).get(
      '/admin/classes',
      queryParameters: {
        'gymId': gymId,
        if (day != null) 'day': day,
        if (categoryId != null) 'categoryId': categoryId,
        if (trainerId != null) 'trainerId': trainerId,
        if (isActive != null) 'isActive': isActive,
      },
    );
    final data = res.data;
    if (data is! List) return [];
    return data.map((e) => GymClass.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createClass(int gymId, Map<String, dynamic> data) async {
    await _ref.read(dioProvider).post('/admin/classes', data: {...data, 'gymId': gymId});
  }

  Future<void> updateClass(int classId, Map<String, dynamic> data) async {
    await _ref.read(dioProvider).put('/admin/classes/$classId', data: data);
  }

  Future<void> deleteClass(int classId) async {
    await _ref.read(dioProvider).delete('/admin/classes/$classId');
  }

  // Class Categories
  Future<List<ClassCategory>> getClassCategories(int gymId) async {
    final res = await _ref.read(dioProvider).get(
      '/admin/class-categories',
      queryParameters: {'gymId': gymId},
    );
    final data = res.data;
    if (data is! List) return [];
    return data.map((e) => ClassCategory.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createClassCategory(int gymId, Map<String, dynamic> data) async {
    await _ref.read(dioProvider).post('/admin/class-categories', data: {...data, 'gymId': gymId});
  }

  Future<void> updateClassCategory(int catId, Map<String, dynamic> data) async {
    await _ref.read(dioProvider).put('/admin/class-categories/$catId', data: data);
  }

  Future<void> deleteClassCategory(int catId) async {
    await _ref.read(dioProvider).delete('/admin/class-categories/$catId');
  }

  // Roster / bookings & attendance
  Future<Map<String, dynamic>> getClassBookings(int classId) async {
    final res = await _ref.read(dioProvider).get('/admin/classes/$classId/bookings');
    final data = res.data as Map<String, dynamic>;
    
    final classObj = GymClass.fromJson(data['class'] as Map<String, dynamic>);
    final bookingsList = (data['bookings'] as List<dynamic>?)
            ?.map((e) => ClassBooking.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    
    final groupedMap = <String, List<ClassBooking>>{};
    if (data['grouped'] is Map) {
      final groupedRaw = data['grouped'] as Map<String, dynamic>;
      for (final key in groupedRaw.keys) {
        final list = (groupedRaw[key] as List<dynamic>?)
                ?.map((e) => ClassBooking.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        groupedMap[key] = list;
      }
    }
    
    return {
      'class': classObj,
      'bookings': bookingsList,
      'grouped': groupedMap,
    };
  }

  Future<void> addClassMember(int classId, int memberId) async {
    await _ref.read(dioProvider).post(
      '/admin/classes/$classId/bookings',
      data: {'memberId': memberId},
    );
  }

  Future<void> cancelClassBooking(int classId, int bookingId) async {
    await _ref.read(dioProvider).delete('/admin/classes/$classId/bookings/$bookingId');
  }

  Future<void> markClassAttendance(int classId, int bookingId, String status) async {
    await _ref.read(dioProvider).post(
      '/admin/classes/$classId/bookings/$bookingId/attendance',
      data: {'status': status},
    );
  }
}
