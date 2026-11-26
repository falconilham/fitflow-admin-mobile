// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appBrandName => 'fitflow.';

  @override
  String get roleAdminOwner => 'ADMIN / OWNER';

  @override
  String get roleAdmin => 'ADMIN';

  @override
  String get navSummary => 'Ringkasan';

  @override
  String get navMembers => 'Member';

  @override
  String get navCheckIn => 'Check-in';

  @override
  String get navReports => 'Laporan';

  @override
  String get navMenu => 'Menu';

  @override
  String get navProfile => 'Profil';

  @override
  String greetingMorning(String name) {
    return 'Selamat pagi, $name';
  }

  @override
  String greetingAfternoon(String name) {
    return 'Selamat siang, $name';
  }

  @override
  String greetingEvening(String name) {
    return 'Selamat sore, $name';
  }

  @override
  String greetingNight(String name) {
    return 'Selamat malam, $name';
  }

  @override
  String get summaryTitle => 'Ringkasan gym';

  @override
  String get todayChip => 'Hari ini';

  @override
  String get checkInTodayLabel => 'Check-in hari ini';

  @override
  String qrManualBreakdown(int qr, int manual) {
    return '$qr QR · $manual manual';
  }

  @override
  String get insideGymLabel => 'Di dalam gym';

  @override
  String get membersTrainingLabel => 'Member sedang berlatih';

  @override
  String get quickAccessTitle => 'Akses cepat';

  @override
  String get allMenuAction => 'Semua menu';

  @override
  String get quickCheckIn => 'Check-in';

  @override
  String get quickMember => 'Member';

  @override
  String get quickPos => 'POS';

  @override
  String get quickClasses => 'Kelas & jadwal';

  @override
  String get todayAttendanceTitle => 'Kehadiran hari ini';

  @override
  String checkInCountLabel(int count) {
    return '$count check-in';
  }

  @override
  String get liveBadge => 'Langsung';

  @override
  String get recentCheckInsTitle => 'Check-in terbaru';

  @override
  String get seeAllAction => 'Lihat semua';

  @override
  String get noCheckInsToday => 'Belum ada check-in hari ini';

  @override
  String get selectBranchTitle => 'Pilih Gym Cabang';

  @override
  String get allMenuTitle => 'Semua menu';

  @override
  String get allMenuSubtitle =>
      'Kelola operasional dan bisnis dalam satu tempat.';

  @override
  String get searchMenuHint => 'Cari menu...';

  @override
  String get menuSectionOperational => 'Resepsionis';

  @override
  String get menuSectionSalesPackages => 'Penjualan & Paket';

  @override
  String get menuSectionBusiness => 'BISNIS';

  @override
  String get menuSectionMain => 'MENU UTAMA';

  @override
  String get menuSectionFinance => 'Keuangan & Laporan';

  @override
  String get menuSectionStaffTeam => 'Tim & Staf';

  @override
  String get menuSectionMarketing => 'Marketing & Komunitas';

  @override
  String get menuSectionSystemAssets => 'Fasilitas & Sistem';

  @override
  String get menuSectionAccount => 'AKUN';

  @override
  String get menuDashboard => 'Dashboard';

  @override
  String get menuNotifications => 'Notifikasi';

  @override
  String get menuMember => 'Anggota';

  @override
  String get menuCheckIn => 'Check In';

  @override
  String get menuSessions => 'Sesi Training';

  @override
  String get menuClasses => 'Kelas Grup';

  @override
  String get menuLeaderboard => 'Papan Peringkat';

  @override
  String get menuTrainer => 'Pelatih';

  @override
  String get menuPtPackages => 'Paket PT';

  @override
  String get menuPtMemberships => 'Membership PT';

  @override
  String get menuLeads => 'Prospek / Leads CRM';

  @override
  String get menuMembershipPackages => 'Paket Membership';

  @override
  String get menuAddonServices => 'Add-On & Rental';

  @override
  String get menuPromotions => 'Promo & Voucher';

  @override
  String get menuPos => 'Kasir (POS)';

  @override
  String get menuProduct => 'Produk';

  @override
  String get menuTransactions => 'Riwayat Transaksi';

  @override
  String get menuCashShifts => 'Shift & Laci Kas';

  @override
  String get menuRevenue => 'Analitik Pendapatan';

  @override
  String get menuExpenses => 'Pengeluaran';

  @override
  String get menuPayroll => 'Penggajian (Payroll)';

  @override
  String get menuPayslips => 'Slip Gaji';

  @override
  String get menuPaymentGateway => 'Payment Gateway';

  @override
  String get menuManagers => 'Admin';

  @override
  String get menuStaffAttendance => 'Kehadiran Staf';

  @override
  String get menuStaffSchedules => 'Jadwal Staf';

  @override
  String get menuAttendanceStats => 'Statistik Staf';

  @override
  String get menuEquipment => 'Peralatan Gym';

  @override
  String get menuReports => 'Laporan';

  @override
  String get menuActivity => 'Log Aktivitas';

  @override
  String get menuAnnouncements => 'Pengumuman';

  @override
  String get menuSettings => 'Pengaturan';

  @override
  String get menuProfile => 'Profil Admin';

  @override
  String get menuHelpCenter => 'Panduan Pengguna';

  @override
  String get menuCheckUpdate => 'Cek update';

  @override
  String get menuSearchEmpty => 'Menu tidak ditemukan';

  @override
  String get activeBranchDefault => 'FitFlow Gym';

  @override
  String get branchManagementHint => 'Ketuk untuk ganti cabang';

  @override
  String get checkInTitle => 'Check-in';

  @override
  String get checkInSubtitle => 'Sambut member, catat kehadiran.';

  @override
  String get scanQrTab => 'Scan QR';

  @override
  String get manualCheckInTab => 'Check-in manual';

  @override
  String get searchMemberPlaceholder => 'Cari nama atau ID member...';

  @override
  String membersFoundCount(int count) {
    return '$count member ditemukan';
  }

  @override
  String get membershipActiveBadge => 'Membership aktif';

  @override
  String get membershipExpiredBadge => 'Kedaluwarsa';

  @override
  String get membershipSuspendedBadge => 'Ditangguhkan';

  @override
  String get membershipInactiveBadge => 'Tidak aktif';

  @override
  String get checkedInBadge => 'Sudah check-in';

  @override
  String get notCheckedInLabel => 'Belum check-in';

  @override
  String validUntilLabel(String date) {
    return 'Hingga $date';
  }

  @override
  String gymSessionsLabel(int remaining, int total) {
    return 'GYM SESSIONS: $remaining/$total';
  }

  @override
  String get confirmCheckInBtn => 'Konfirmasi check-in';

  @override
  String get confirmCheckOutBtn => 'Konfirmasi check-out';

  @override
  String get searchMemberPrompt =>
      'Cari nama, email, HP, atau ID member untuk check-in manual.';

  @override
  String get noMembersFound => 'Member tidak ditemukan';

  @override
  String get checkInSuccessTitle => 'Check-in Berhasil!';

  @override
  String get checkOutSuccessTitle => 'Check-out Berhasil!';

  @override
  String get checkInDeniedTitle => 'Akses Ditolak';

  @override
  String get ptPackagesTitle => 'Paket PT';

  @override
  String get ptPackagesEmpty => 'Belum ada paket PT';

  @override
  String get ptMembershipsTitle => 'Membership PT';

  @override
  String get ptMembershipsEmpty => 'Belum ada membership PT aktif';

  @override
  String get helpCenterTitle => 'Panduan Pengguna';

  @override
  String get helpCenterSubtitle =>
      'Panduan cepat operasional & dukungan FitFlow';

  @override
  String get logoutAction => 'Keluar';

  @override
  String get profileMenuLabel => 'Profil Admin';

  @override
  String get retryAction => 'Coba Lagi';
}
