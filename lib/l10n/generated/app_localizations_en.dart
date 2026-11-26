// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appBrandName => 'fitflow.';

  @override
  String get roleAdminOwner => 'ADMIN / OWNER';

  @override
  String get roleAdmin => 'ADMIN';

  @override
  String get navSummary => 'Overview';

  @override
  String get navMembers => 'Members';

  @override
  String get navCheckIn => 'Check-in';

  @override
  String get navReports => 'Reports';

  @override
  String get navMenu => 'Menu';

  @override
  String get navProfile => 'Profile';

  @override
  String greetingMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String greetingAfternoon(String name) {
    return 'Good afternoon, $name';
  }

  @override
  String greetingEvening(String name) {
    return 'Good evening, $name';
  }

  @override
  String greetingNight(String name) {
    return 'Good evening, $name';
  }

  @override
  String get summaryTitle => 'Gym overview';

  @override
  String get todayChip => 'Today';

  @override
  String get checkInTodayLabel => 'Check-ins today';

  @override
  String qrManualBreakdown(int qr, int manual) {
    return '$qr QR · $manual manual';
  }

  @override
  String get insideGymLabel => 'Inside gym';

  @override
  String get membersTrainingLabel => 'Members training now';

  @override
  String get quickAccessTitle => 'Quick access';

  @override
  String get allMenuAction => 'All menu';

  @override
  String get quickCheckIn => 'Check-in';

  @override
  String get quickMember => 'Members';

  @override
  String get quickPos => 'POS';

  @override
  String get quickClasses => 'Classes & schedule';

  @override
  String get todayAttendanceTitle => 'Today\'s attendance';

  @override
  String checkInCountLabel(int count) {
    return '$count check-ins';
  }

  @override
  String get liveBadge => 'Live';

  @override
  String get recentCheckInsTitle => 'Recent check-ins';

  @override
  String get seeAllAction => 'See all';

  @override
  String get noCheckInsToday => 'No check-ins today yet';

  @override
  String get selectBranchTitle => 'Select Gym Branch';

  @override
  String get allMenuTitle => 'All menu';

  @override
  String get allMenuSubtitle => 'Manage operations and business in one place.';

  @override
  String get searchMenuHint => 'Search menu...';

  @override
  String get menuSectionOperational => 'Front Desk';

  @override
  String get menuSectionSalesPackages => 'Sales & Packages';

  @override
  String get menuSectionBusiness => 'BUSINESS';

  @override
  String get menuSectionMain => 'MAIN MENU';

  @override
  String get menuSectionFinance => 'Finance & Reports';

  @override
  String get menuSectionStaffTeam => 'Team & Staff';

  @override
  String get menuSectionMarketing => 'Marketing & Community';

  @override
  String get menuSectionSystemAssets => 'Facility & System';

  @override
  String get menuSectionAccount => 'ACCOUNT';

  @override
  String get menuDashboard => 'Dashboard';

  @override
  String get menuNotifications => 'Notifications';

  @override
  String get menuMember => 'Members';

  @override
  String get menuCheckIn => 'Check In';

  @override
  String get menuSessions => 'Training Sessions';

  @override
  String get menuClasses => 'Group Classes';

  @override
  String get menuLeaderboard => 'Leaderboard';

  @override
  String get menuTrainer => 'Trainers';

  @override
  String get menuPtPackages => 'PT Packages';

  @override
  String get menuPtMemberships => 'PT Memberships';

  @override
  String get menuLeads => 'Leads CRM & Pipeline';

  @override
  String get menuMembershipPackages => 'Membership Packages';

  @override
  String get menuAddonServices => 'Add-On & Rental';

  @override
  String get menuPromotions => 'Promo & Vouchers';

  @override
  String get menuPos => 'Point of Sale';

  @override
  String get menuProduct => 'Products';

  @override
  String get menuTransactions => 'Transactions';

  @override
  String get menuCashShifts => 'Cash Shifts & Drawer';

  @override
  String get menuRevenue => 'Revenue Analytics';

  @override
  String get menuExpenses => 'Expenses';

  @override
  String get menuPayroll => 'Payroll';

  @override
  String get menuPayslips => 'Payslips';

  @override
  String get menuPaymentGateway => 'Payment Gateway';

  @override
  String get menuManagers => 'Admin';

  @override
  String get menuStaffAttendance => 'Staff Attendance';

  @override
  String get menuStaffSchedules => 'Staff Schedules';

  @override
  String get menuAttendanceStats => 'Staff Statistics';

  @override
  String get menuEquipment => 'Gym Equipment';

  @override
  String get menuReports => 'Reports';

  @override
  String get menuActivity => 'Activity Logs';

  @override
  String get menuAnnouncements => 'Announcements';

  @override
  String get menuSettings => 'Settings';

  @override
  String get menuProfile => 'Admin Profile';

  @override
  String get menuHelpCenter => 'User Guide';

  @override
  String get menuCheckUpdate => 'Check update';

  @override
  String get menuSearchEmpty => 'No matching menu found';

  @override
  String get activeBranchDefault => 'FitFlow Gym';

  @override
  String get branchManagementHint => 'Tap to switch branch';

  @override
  String get checkInTitle => 'Check-in';

  @override
  String get checkInSubtitle => 'Welcome members, record attendance.';

  @override
  String get scanQrTab => 'Scan QR';

  @override
  String get manualCheckInTab => 'Manual check-in';

  @override
  String get searchMemberPlaceholder => 'Search member name or ID...';

  @override
  String membersFoundCount(int count) {
    return '$count members found';
  }

  @override
  String get membershipActiveBadge => 'Active membership';

  @override
  String get membershipExpiredBadge => 'Expired';

  @override
  String get membershipSuspendedBadge => 'Suspended';

  @override
  String get membershipInactiveBadge => 'Inactive';

  @override
  String get checkedInBadge => 'Checked in';

  @override
  String get notCheckedInLabel => 'Not checked in';

  @override
  String validUntilLabel(String date) {
    return 'Until $date';
  }

  @override
  String gymSessionsLabel(int remaining, int total) {
    return 'GYM SESSIONS: $remaining/$total';
  }

  @override
  String get confirmCheckInBtn => 'Confirm check-in';

  @override
  String get confirmCheckOutBtn => 'Confirm check-out';

  @override
  String get searchMemberPrompt =>
      'Search name, email, phone, or member ID for manual check-in.';

  @override
  String get noMembersFound => 'No members found';

  @override
  String get checkInSuccessTitle => 'Check-in Granted!';

  @override
  String get checkOutSuccessTitle => 'Check-out Completed!';

  @override
  String get checkInDeniedTitle => 'Access Denied';

  @override
  String get ptPackagesTitle => 'PT Packages';

  @override
  String get ptPackagesEmpty => 'No PT packages yet';

  @override
  String get ptMembershipsTitle => 'PT Memberships';

  @override
  String get ptMembershipsEmpty => 'No active PT memberships';

  @override
  String get helpCenterTitle => 'User Guide';

  @override
  String get helpCenterSubtitle => 'Quick operations guide & FitFlow support';

  @override
  String get logoutAction => 'Logout';

  @override
  String get profileMenuLabel => 'Admin Profile';

  @override
  String get retryAction => 'Retry';
}
