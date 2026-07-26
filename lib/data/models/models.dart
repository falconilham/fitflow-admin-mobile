class AdminInfo {
  final int id;
  final String name;
  final String email;
  final String role;
  final int? gymId;
  final GymInfo? gym;

  AdminInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.gymId,
    this.gym,
  });

  bool get isOwner {
    final r = role.toLowerCase();
    return r == 'owner' || r == 'super_admin' || r == 'superadmin';
  }
  String? get gymName => gym?.name;

  factory AdminInfo.fromJson(Map<String, dynamic> json) {
    return AdminInfo(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      gymId: (json['gymId'] as num?)?.toInt(),
      gym: json['gym'] != null ? GymInfo.fromJson(json['gym'] as Map<String, dynamic>) : null,
    );
  }
}

class GymInfo {
  final String name;
  final List<String> features;
  GymInfo({required this.name, this.features = const []});
  factory GymInfo.fromJson(Map<String, dynamic> json) => GymInfo(
        name: json['name'] as String? ?? '',
        features: (json['features'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

class GymSimple {
  final int id;
  final String name;

  GymSimple({required this.id, required this.name});

  factory GymSimple.fromJson(Map<String, dynamic> json) {
    return GymSimple(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}

class DashboardStats {
  final int totalMembers;
  final int activeMembers;
  final int dailyCheckIns;
  final double expenses;

  const DashboardStats({
    required this.totalMembers,
    required this.activeMembers,
    required this.dailyCheckIns,
    required this.expenses,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalMembers: (json['totalMembers'] as num?)?.toInt() ?? 0,
      activeMembers: (json['activeMembers'] as num?)?.toInt() ?? 0,
      dailyCheckIns: (json['dailyCheckIns'] as num?)?.toInt() ?? 0,
      expenses: (json['expenses'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Member {
  final int id;
  final String name;
  final String? memberId;
  final String status;
  final bool suspended;
  final String? suspensionReason;
  final String? suspensionEndDate;
  final String email;
  final String? phone;
  final String? memberPhoto;
  final String? address;
  final String joinDate;
  final String endDate;
  final int? packageId;
  final String? packageName;
  final int? packagePrice;
  final int? userId;
  final int? referenceMemberId;
  // Wallet / quota balance fields
  final int? totalSessions;
  final int? usedSessions;
  final int? totalMinutes;
  final int? usedMinutes;
  final int? sessionDuration;
  final bool hasVisitPackage;
  // Remaining trainer (PT) sessions from active TrainerPackages
  final int remainingPtSessions;
  // Total & completed PT (TrainingSession) history
  final int ptSessionTotal;
  final int ptSessionCompleted;

  Member({
    required this.id,
    required this.name,
    this.memberId,
    required this.status,
    required this.suspended,
    this.suspensionReason,
    this.suspensionEndDate,
    required this.email,
    this.phone,
    this.memberPhoto,
    this.address,
    required this.joinDate,
    required this.endDate,
    this.packageId,
    this.packageName,
    this.packagePrice,
    this.userId,
    this.referenceMemberId,
    this.totalSessions,
    this.usedSessions,
    this.totalMinutes,
    this.usedMinutes,
    this.sessionDuration,
    this.hasVisitPackage = false,
    this.remainingPtSessions = 0,
    this.ptSessionTotal = 0,
    this.ptSessionCompleted = 0,
  });

  bool get isArchived => status.toLowerCase() == 'deleted';

  String get displayStatus {
    if (isArchived) return 'Archived';
    if (suspended) return 'Suspended';
    bool dateExpired = false;
    try {
      final end = DateTime.parse(endDate);
      final today = DateTime.now();
      final endDay = DateTime(end.year, end.month, end.day);
      final todayDay = DateTime(today.year, today.month, today.day);
      dateExpired = endDay.isBefore(todayDay);
    } catch (_) {}
    if (status.toLowerCase() == 'expired' || dateExpired) return 'Expired';
    return status;
  }

  int? get remainingSessions {
    if (totalSessions == null) return null;
    return (totalSessions! - (usedSessions ?? 0)).clamp(0, totalSessions!);
  }

  int? get remainingMinutes {
    if (totalMinutes == null) return null;
    return (totalMinutes! - (usedMinutes ?? 0)).clamp(0, totalMinutes!);
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      memberId: json['memberId'] as String?,
      status: json['status'] as String? ?? 'Inactive',
      suspended: json['suspended'] as bool? ?? false,
      suspensionReason: json['suspensionReason'] as String?,
      suspensionEndDate: json['suspensionEndDate'] as String?,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      memberPhoto: json['memberPhoto'] as String?,
      address: json['address'] as String?,
      joinDate: json['joinDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      packageId: (json['packageId'] as num?)?.toInt(),
      packageName: json['packageName'] ?? (json['MembershipPackage']?['name']),
      packagePrice: (json['packagePrice'] as num?)?.toInt() ?? (json['MembershipPackage']?['price'] as num?)?.toInt(),
      userId: (json['userId'] as num?)?.toInt(),
      referenceMemberId: (json['referenceMemberId'] as num?)?.toInt(),
      totalSessions: (json['totalSessions'] as num?)?.toInt(),
      usedSessions: (json['usedSessions'] as num?)?.toInt(),
      totalMinutes: (json['totalMinutes'] as num?)?.toInt(),
      usedMinutes: (json['usedMinutes'] as num?)?.toInt(),
      sessionDuration: (json['sessionDuration'] as num?)?.toInt(),
      hasVisitPackage: json['hasVisitPackage'] as bool? ?? false,
      remainingPtSessions: (json['remainingSessions'] as num?)?.toInt() ?? 0,
      ptSessionTotal: (json['ptSessionTotal'] as num?)?.toInt() ?? 0,
      ptSessionCompleted: (json['ptSessionCompleted'] as num?)?.toInt() ?? 0,
    );
  }
}

class SessionLog {
  final int id;
  final String timestamp;
  final int duration;
  final String? adminName;
  final String? packageName;

  const SessionLog({
    required this.id,
    required this.timestamp,
    required this.duration,
    this.adminName,
    this.packageName,
  });

  factory SessionLog.fromJson(Map<String, dynamic> json) {
    return SessionLog(
      id: (json['id'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] as String? ?? json['createdAt'] as String? ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      adminName: json['adminName'] as String?,
      packageName: json['packageName'] as String?,
    );
  }
}

class LeaderboardEntry {
  final int rank;
  final String name;
  final String? photo;
  final int score;
  final int? entityId;

  const LeaderboardEntry({
    required this.rank,
    required this.name,
    this.photo,
    required this.score,
    this.entityId,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      photo: json['photo'] as String?,
      score: (json['score'] as num?)?.toInt() ?? 0,
      entityId: (json['entityId'] as num?)?.toInt(),
    );
  }
}

class InvestorReport {
  final double grossRevenue;
  final double totalExpenses;
  final double netProfit;
  final double profitMargin;
  final double membershipRev;
  final double personalTrainingRev;
  final double posRev;
  final int newMembers;
  final int totalActiveMembers;
  final int churnedMembers;
  final double churnRate;
  final String? periodStart;
  final String? periodEnd;

  const InvestorReport({
    required this.grossRevenue,
    required this.totalExpenses,
    required this.netProfit,
    required this.profitMargin,
    required this.membershipRev,
    required this.personalTrainingRev,
    required this.posRev,
    required this.newMembers,
    required this.totalActiveMembers,
    required this.churnedMembers,
    required this.churnRate,
    this.periodStart,
    this.periodEnd,
  });

  factory InvestorReport.fromJson(Map<String, dynamic> json) {
    final fh = (json['financialHealth'] as Map?) ?? const {};
    final rd = (json['revenueDistribution'] as Map?) ?? const {};
    final gm = (json['growthMetrics'] as Map?) ?? const {};
    final period = (json['period'] as Map?) ?? const {};

    double asDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int asInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    return InvestorReport(
      grossRevenue: asDouble(fh['grossRevenue']),
      totalExpenses: asDouble(fh['totalExpenses']),
      netProfit: asDouble(fh['netProfit']),
      profitMargin: asDouble(fh['profitMargin']),
      membershipRev: asDouble(rd['membership']),
      personalTrainingRev: asDouble(rd['personalTraining']),
      posRev: asDouble(rd['posAndRetail']),
      newMembers: asInt(gm['newMembers']),
      totalActiveMembers: asInt(gm['totalActiveMembers']),
      churnedMembers: asInt(gm['churnedMembers']),
      churnRate: asDouble(gm['churnRate']),
      periodStart: period['start'] as String?,
      periodEnd: period['end'] as String?,
    );
  }
}

class MembershipPackage {
  final int id;
  final String name;
  final int durationMonths;
  final int price;
  final String? type;
  final String? description;
  final bool hasRegistrationFee;
  final int? totalSessions;
  final int? sessionDuration;
  final bool isActive;

  MembershipPackage({
    required this.id,
    required this.name,
    required this.durationMonths,
    required this.price,
    this.type,
    this.description,
    this.hasRegistrationFee = true,
    this.totalSessions,
    this.sessionDuration,
    this.isActive = true,
  });

  factory MembershipPackage.fromJson(Map<String, dynamic> json) {
    return MembershipPackage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      durationMonths: (json['durationMonths'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toInt() ?? 0,
      type: json['type'] as String?,
      description: json['description'] as String?,
      hasRegistrationFee: json['hasRegistrationFee'] as bool? ?? true,
      totalSessions: (json['totalSessions'] as num?)?.toInt(),
      sessionDuration: (json['sessionDuration'] as num?)?.toInt(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class GymSettings {
  final int id;
  final String name;
  final String? logo;
  final String primaryColor;
  final String secondaryColor;
  final String? address;
  final String? phone;
  final String? email;
  final int registrationFee;
  final int reRegistrationFee;
  final int inactivityGracePeriod;
  final String mandatoryContact;
  final bool requireMemberId;
  final String? memberIdPrefix;
  final double taxRate;

  const GymSettings({
    this.id = 0,
    this.name = '',
    this.logo,
    this.primaryColor = '#bef264',
    this.secondaryColor = '#1a1a1a',
    this.address,
    this.phone,
    this.email,
    this.registrationFee = 0,
    this.reRegistrationFee = 0,
    this.inactivityGracePeriod = 3,
    this.mandatoryContact = 'none',
    this.requireMemberId = false,
    this.memberIdPrefix = 'MEM-',
    this.taxRate = 0.0,
  });

  factory GymSettings.fromJson(Map<String, dynamic> json) {
    return GymSettings(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      logo: json['logo'] as String?,
      primaryColor: json['primaryColor'] as String? ?? '#bef264',
      secondaryColor: json['secondaryColor'] as String? ?? '#1a1a1a',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      registrationFee: (json['registrationFee'] as num?)?.toInt() ?? 0,
      reRegistrationFee: (json['reRegistrationFee'] as num?)?.toInt() ?? 0,
      inactivityGracePeriod: (json['inactivityGracePeriod'] as num?)?.toInt() ?? 3,
      mandatoryContact: json['mandatoryContact'] as String? ?? 'none',
      requireMemberId: json['requireMemberId'] as bool? ?? false,
      memberIdPrefix: json['memberIdPrefix'] as String? ?? 'MEM-',
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'address': address,
      'phone': phone,
      'email': email,
      'registrationFee': registrationFee,
      'reRegistrationFee': reRegistrationFee,
      'inactivityGracePeriod': inactivityGracePeriod,
      'mandatoryContact': mandatoryContact,
      'requireMemberId': requireMemberId,
      'memberIdPrefix': memberIdPrefix,
      'taxRate': taxRate,
    };
  }
}

class Product {
  final int id;
  final String name;
  final int price;
  final int stock;
  final String category;
  final String? description;
  final String? imageUrl;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.category,
    this.description,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? 'Other',
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String? ?? json['image'] as String?,
    );
  }
}

class CheckInRecord {
  final int id;
  final String memberName;
  final String? memberPhoto;
  final String checkedInAt;

  CheckInRecord({
    required this.id,
    required this.memberName,
    this.memberPhoto,
    required this.checkedInAt,
  });

  factory CheckInRecord.fromJson(Map<String, dynamic> json) {
    return CheckInRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      memberName: json['memberName'] as String? ?? json['name'] as String? ?? 'Unknown',
      memberPhoto: json['memberPhoto'] as String?,
      checkedInAt: json['checkedInAt'] as String? ?? json['createdAt'] as String? ?? '',
    );
  }
}

class GymClass {
  final int id;
  final int gymId;
  final String title;
  final String? description;
  final String trainer;
  final int? trainerId;
  final int? categoryId;
  final String day;
  final String time;
  final String duration;
  final int capacity;
  final int booked;
  final String? color;
  final bool isActive;
  final String? categoryName;
  final String? categoryColor;

  GymClass({
    required this.id,
    required this.gymId,
    required this.title,
    this.description,
    required this.trainer,
    this.trainerId,
    this.categoryId,
    required this.day,
    required this.time,
    required this.duration,
    required this.capacity,
    required this.booked,
    this.color,
    required this.isActive,
    this.categoryName,
    this.categoryColor,
  });

  factory GymClass.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['category'] as Map<String, dynamic>?;
    return GymClass(
      id: (json['id'] as num?)?.toInt() ?? 0,
      gymId: (json['gymId'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      trainer: json['trainer'] as String? ?? '',
      trainerId: (json['trainerId'] as num?)?.toInt(),
      categoryId: (json['categoryId'] as num?)?.toInt(),
      day: json['day'] as String? ?? 'Monday',
      time: json['time'] as String? ?? '08:00',
      duration: json['duration'] as String? ?? '60',
      capacity: (json['capacity'] as num?)?.toInt() ?? 10,
      booked: (json['booked'] as num?)?.toInt() ?? 0,
      color: json['color'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      categoryName: categoryJson?['name'] as String?,
      categoryColor: categoryJson?['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'trainerId': trainerId,
      'categoryId': categoryId,
      'day': day,
      'time': time,
      'duration': duration,
      'capacity': capacity,
      'color': color,
      'isActive': isActive,
    };
  }
}

class ClassCategory {
  final int id;
  final int gymId;
  final String name;
  final String? color;

  ClassCategory({
    required this.id,
    required this.gymId,
    required this.name,
    this.color,
  });

  factory ClassCategory.fromJson(Map<String, dynamic> json) {
    return ClassCategory(
      id: (json['id'] as num?)?.toInt() ?? 0,
      gymId: (json['gymId'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'color': color,
    };
  }
}

class ClassBooking {
  final int id;
  final int classId;
  final int memberId;
  final int gymId;
  final String status; // 'booked' | 'waitlist' | 'attended' | 'no_show' | 'cancelled'
  final int? waitlistPosition;
  final String bookedAt;
  final String? cancelledAt;
  final String? attendedAt;
  final String? cancelledBy;
  final String? memberName;
  final String? memberPhoto;
  final String? memberIdString;

  ClassBooking({
    required this.id,
    required this.classId,
    required this.memberId,
    required this.gymId,
    required this.status,
    this.waitlistPosition,
    required this.bookedAt,
    this.cancelledAt,
    this.attendedAt,
    this.cancelledBy,
    this.memberName,
    this.memberPhoto,
    this.memberIdString,
  });

  factory ClassBooking.fromJson(Map<String, dynamic> json) {
    final memberJson = json['member'] as Map<String, dynamic>?;
    return ClassBooking(
      id: (json['id'] as num?)?.toInt() ?? 0,
      classId: (json['classId'] as num?)?.toInt() ?? 0,
      memberId: (json['memberId'] as num?)?.toInt() ?? 0,
      gymId: (json['gymId'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'booked',
      waitlistPosition: (json['waitlistPosition'] as num?)?.toInt(),
      bookedAt: json['bookedAt'] as String? ?? json['createdAt'] as String? ?? '',
      cancelledAt: json['cancelledAt'] as String?,
      attendedAt: json['attendedAt'] as String?,
      cancelledBy: json['cancelledBy'] as String?,
      memberName: memberJson?['name'] as String?,
      memberPhoto: memberJson?['memberPhoto'] as String?,
      memberIdString: memberJson?['memberId'] as String?,
    );
  }
}

class Equipment {
  final int id;
  final String name;
  final String? brand;
  final String category;
  final String status;

  const Equipment({
    required this.id,
    required this.name,
    this.brand,
    required this.category,
    required this.status,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String?,
      category: json['category'] as String? ?? 'General',
      status: json['status'] as String? ?? 'Active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'brand': brand,
      'category': category,
      'status': status,
    };
  }
}

class StaffSchedule {
  final int id;
  final String staffId;
  final String staffName;
  final String role;
  final String dayOfWeek;
  final String startTime;
  final String endTime;

  StaffSchedule({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.role,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory StaffSchedule.fromJson(Map<String, dynamic> json) {
    return StaffSchedule(
      id: (json['id'] as num?)?.toInt() ?? 0,
      staffId: json['staffId']?.toString() ?? '',
      staffName: json['staffName'] as String? ?? '',
      role: json['role'] as String? ?? '',
      dayOfWeek: json['dayOfWeek'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
    );
  }
}

class PieChartData {
  final String name;
  final int value;
  final String color;

  PieChartData({required this.name, required this.value, required this.color});

  factory PieChartData.fromJson(Map<String, dynamic> json) {
    return PieChartData(
      name: json['name'] as String? ?? '',
      value: (json['value'] as num?)?.toInt() ?? 0,
      color: json['color'] as String? ?? '#888888',
    );
  }
}

class LineChartData {
  final String date;
  final int checkIns;

  LineChartData({required this.date, required this.checkIns});

  factory LineChartData.fromJson(Map<String, dynamic> json) {
    return LineChartData(
      date: json['date'] as String? ?? '',
      checkIns: (json['checkIns'] as num?)?.toInt() ?? 0,
    );
  }
}

class AttendanceStats {
  final int totalCheckIns;
  final int onTimeCount;
  final int lateCount;
  final List<PieChartData> pieChartData;
  final List<LineChartData> lineChartData;

  AttendanceStats({
    required this.totalCheckIns,
    required this.onTimeCount,
    required this.lateCount,
    required this.pieChartData,
    required this.lineChartData,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) {
    return AttendanceStats(
      totalCheckIns: (json['totalCheckIns'] as num?)?.toInt() ?? 0,
      onTimeCount: (json['onTimeCount'] as num?)?.toInt() ?? 0,
      lateCount: (json['lateCount'] as num?)?.toInt() ?? 0,
      pieChartData: (json['pieChartData'] as List?)?.map((e) => PieChartData.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      lineChartData: (json['lineChartData'] as List?)?.map((e) => LineChartData.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class StaffInfo {
  final String id;
  final String name;
  final String role;
  final String? email;

  StaffInfo({required this.id, required this.name, required this.role, this.email});

  factory StaffInfo.fromJson(Map<String, dynamic> json) {
    return StaffInfo(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}