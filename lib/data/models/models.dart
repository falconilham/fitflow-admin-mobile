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

  bool get isOwner => role.toLowerCase() == 'owner';
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
  GymInfo({required this.name});
  factory GymInfo.fromJson(Map<String, dynamic> json) => GymInfo(name: json['name'] as String? ?? '');
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
  final String email;
  final String? phone;
  final String joinDate;
  final String endDate;
  final int? packageId;
  final String? packageName;
  final int? packagePrice;
  final int? userId;

  Member({
    required this.id,
    required this.name,
    this.memberId,
    required this.status,
    required this.suspended,
    required this.email,
    this.phone,
    required this.joinDate,
    required this.endDate,
    this.packageId,
    this.packageName,
    this.packagePrice,
    this.userId,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      memberId: json['memberId'] as String?,
      status: json['status'] as String? ?? 'Inactive',
      suspended: json['suspended'] as bool? ?? false,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      joinDate: json['joinDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      packageId: (json['packageId'] as num?)?.toInt(),
      packageName: json['packageName'] ?? (json['MembershipPackage']?['name']),
      packagePrice: (json['packagePrice'] as num?)?.toInt() ?? (json['MembershipPackage']?['price'] as num?)?.toInt(),
      userId: (json['userId'] as num?)?.toInt(),
    );
  }
}

class MembershipPackage {
  final int id;
  final String name;
  final int durationMonths;
  final int price;
  final String? type;

  MembershipPackage({
    required this.id,
    required this.name,
    required this.durationMonths,
    required this.price,
    this.type,
  });

  factory MembershipPackage.fromJson(Map<String, dynamic> json) {
    return MembershipPackage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      durationMonths: (json['durationMonths'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toInt() ?? 0,
      type: json['type'] as String?,
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