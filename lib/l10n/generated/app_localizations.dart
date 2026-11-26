import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id')
  ];

  /// No description provided for @appBrandName.
  ///
  /// In id, this message translates to:
  /// **'fitflow.'**
  String get appBrandName;

  /// No description provided for @roleAdminOwner.
  ///
  /// In id, this message translates to:
  /// **'ADMIN / OWNER'**
  String get roleAdminOwner;

  /// No description provided for @roleAdmin.
  ///
  /// In id, this message translates to:
  /// **'ADMIN'**
  String get roleAdmin;

  /// No description provided for @navSummary.
  ///
  /// In id, this message translates to:
  /// **'Ringkasan'**
  String get navSummary;

  /// No description provided for @navMembers.
  ///
  /// In id, this message translates to:
  /// **'Member'**
  String get navMembers;

  /// No description provided for @navCheckIn.
  ///
  /// In id, this message translates to:
  /// **'Check-in'**
  String get navCheckIn;

  /// No description provided for @navReports.
  ///
  /// In id, this message translates to:
  /// **'Laporan'**
  String get navReports;

  /// No description provided for @navMenu.
  ///
  /// In id, this message translates to:
  /// **'Menu'**
  String get navMenu;

  /// No description provided for @navProfile.
  ///
  /// In id, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @greetingMorning.
  ///
  /// In id, this message translates to:
  /// **'Selamat pagi, {name}'**
  String greetingMorning(String name);

  /// No description provided for @greetingAfternoon.
  ///
  /// In id, this message translates to:
  /// **'Selamat siang, {name}'**
  String greetingAfternoon(String name);

  /// No description provided for @greetingEvening.
  ///
  /// In id, this message translates to:
  /// **'Selamat sore, {name}'**
  String greetingEvening(String name);

  /// No description provided for @greetingNight.
  ///
  /// In id, this message translates to:
  /// **'Selamat malam, {name}'**
  String greetingNight(String name);

  /// No description provided for @summaryTitle.
  ///
  /// In id, this message translates to:
  /// **'Ringkasan gym'**
  String get summaryTitle;

  /// No description provided for @todayChip.
  ///
  /// In id, this message translates to:
  /// **'Hari ini'**
  String get todayChip;

  /// No description provided for @checkInTodayLabel.
  ///
  /// In id, this message translates to:
  /// **'Check-in hari ini'**
  String get checkInTodayLabel;

  /// No description provided for @qrManualBreakdown.
  ///
  /// In id, this message translates to:
  /// **'{qr} QR · {manual} manual'**
  String qrManualBreakdown(int qr, int manual);

  /// No description provided for @insideGymLabel.
  ///
  /// In id, this message translates to:
  /// **'Di dalam gym'**
  String get insideGymLabel;

  /// No description provided for @membersTrainingLabel.
  ///
  /// In id, this message translates to:
  /// **'Member sedang berlatih'**
  String get membersTrainingLabel;

  /// No description provided for @quickAccessTitle.
  ///
  /// In id, this message translates to:
  /// **'Akses cepat'**
  String get quickAccessTitle;

  /// No description provided for @allMenuAction.
  ///
  /// In id, this message translates to:
  /// **'Semua menu'**
  String get allMenuAction;

  /// No description provided for @quickCheckIn.
  ///
  /// In id, this message translates to:
  /// **'Check-in'**
  String get quickCheckIn;

  /// No description provided for @quickMember.
  ///
  /// In id, this message translates to:
  /// **'Member'**
  String get quickMember;

  /// No description provided for @quickPos.
  ///
  /// In id, this message translates to:
  /// **'POS'**
  String get quickPos;

  /// No description provided for @quickClasses.
  ///
  /// In id, this message translates to:
  /// **'Kelas & jadwal'**
  String get quickClasses;

  /// No description provided for @todayAttendanceTitle.
  ///
  /// In id, this message translates to:
  /// **'Kehadiran hari ini'**
  String get todayAttendanceTitle;

  /// No description provided for @checkInCountLabel.
  ///
  /// In id, this message translates to:
  /// **'{count} check-in'**
  String checkInCountLabel(int count);

  /// No description provided for @liveBadge.
  ///
  /// In id, this message translates to:
  /// **'Langsung'**
  String get liveBadge;

  /// No description provided for @recentCheckInsTitle.
  ///
  /// In id, this message translates to:
  /// **'Check-in terbaru'**
  String get recentCheckInsTitle;

  /// No description provided for @seeAllAction.
  ///
  /// In id, this message translates to:
  /// **'Lihat semua'**
  String get seeAllAction;

  /// No description provided for @noCheckInsToday.
  ///
  /// In id, this message translates to:
  /// **'Belum ada check-in hari ini'**
  String get noCheckInsToday;

  /// No description provided for @selectBranchTitle.
  ///
  /// In id, this message translates to:
  /// **'Pilih Gym Cabang'**
  String get selectBranchTitle;

  /// No description provided for @allMenuTitle.
  ///
  /// In id, this message translates to:
  /// **'Semua menu'**
  String get allMenuTitle;

  /// No description provided for @allMenuSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Kelola operasional dan bisnis dalam satu tempat.'**
  String get allMenuSubtitle;

  /// No description provided for @searchMenuHint.
  ///
  /// In id, this message translates to:
  /// **'Cari menu...'**
  String get searchMenuHint;

  /// No description provided for @menuSectionOperational.
  ///
  /// In id, this message translates to:
  /// **'Resepsionis'**
  String get menuSectionOperational;

  /// No description provided for @menuSectionSalesPackages.
  ///
  /// In id, this message translates to:
  /// **'Penjualan & Paket'**
  String get menuSectionSalesPackages;

  /// No description provided for @menuSectionBusiness.
  ///
  /// In id, this message translates to:
  /// **'BISNIS'**
  String get menuSectionBusiness;

  /// No description provided for @menuSectionMain.
  ///
  /// In id, this message translates to:
  /// **'MENU UTAMA'**
  String get menuSectionMain;

  /// No description provided for @menuSectionFinance.
  ///
  /// In id, this message translates to:
  /// **'Keuangan & Laporan'**
  String get menuSectionFinance;

  /// No description provided for @menuSectionStaffTeam.
  ///
  /// In id, this message translates to:
  /// **'Tim & Staf'**
  String get menuSectionStaffTeam;

  /// No description provided for @menuSectionMarketing.
  ///
  /// In id, this message translates to:
  /// **'Marketing & Komunitas'**
  String get menuSectionMarketing;

  /// No description provided for @menuSectionSystemAssets.
  ///
  /// In id, this message translates to:
  /// **'Fasilitas & Sistem'**
  String get menuSectionSystemAssets;

  /// No description provided for @menuSectionAccount.
  ///
  /// In id, this message translates to:
  /// **'AKUN'**
  String get menuSectionAccount;

  /// No description provided for @menuDashboard.
  ///
  /// In id, this message translates to:
  /// **'Dashboard'**
  String get menuDashboard;

  /// No description provided for @menuNotifications.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi'**
  String get menuNotifications;

  /// No description provided for @menuMember.
  ///
  /// In id, this message translates to:
  /// **'Anggota'**
  String get menuMember;

  /// No description provided for @menuCheckIn.
  ///
  /// In id, this message translates to:
  /// **'Check In'**
  String get menuCheckIn;

  /// No description provided for @menuSessions.
  ///
  /// In id, this message translates to:
  /// **'Sesi Training'**
  String get menuSessions;

  /// No description provided for @menuClasses.
  ///
  /// In id, this message translates to:
  /// **'Kelas Grup'**
  String get menuClasses;

  /// No description provided for @menuLeaderboard.
  ///
  /// In id, this message translates to:
  /// **'Papan Peringkat'**
  String get menuLeaderboard;

  /// No description provided for @menuTrainer.
  ///
  /// In id, this message translates to:
  /// **'Pelatih'**
  String get menuTrainer;

  /// No description provided for @menuPtPackages.
  ///
  /// In id, this message translates to:
  /// **'Paket PT'**
  String get menuPtPackages;

  /// No description provided for @menuPtMemberships.
  ///
  /// In id, this message translates to:
  /// **'Membership PT'**
  String get menuPtMemberships;

  /// No description provided for @menuLeads.
  ///
  /// In id, this message translates to:
  /// **'Prospek / Leads CRM'**
  String get menuLeads;

  /// No description provided for @menuMembershipPackages.
  ///
  /// In id, this message translates to:
  /// **'Paket Membership'**
  String get menuMembershipPackages;

  /// No description provided for @menuAddonServices.
  ///
  /// In id, this message translates to:
  /// **'Add-On & Rental'**
  String get menuAddonServices;

  /// No description provided for @menuPromotions.
  ///
  /// In id, this message translates to:
  /// **'Promo & Voucher'**
  String get menuPromotions;

  /// No description provided for @menuPos.
  ///
  /// In id, this message translates to:
  /// **'Kasir (POS)'**
  String get menuPos;

  /// No description provided for @menuProduct.
  ///
  /// In id, this message translates to:
  /// **'Produk'**
  String get menuProduct;

  /// No description provided for @menuTransactions.
  ///
  /// In id, this message translates to:
  /// **'Riwayat Transaksi'**
  String get menuTransactions;

  /// No description provided for @menuCashShifts.
  ///
  /// In id, this message translates to:
  /// **'Shift & Laci Kas'**
  String get menuCashShifts;

  /// No description provided for @menuRevenue.
  ///
  /// In id, this message translates to:
  /// **'Analitik Pendapatan'**
  String get menuRevenue;

  /// No description provided for @menuExpenses.
  ///
  /// In id, this message translates to:
  /// **'Pengeluaran'**
  String get menuExpenses;

  /// No description provided for @menuPayroll.
  ///
  /// In id, this message translates to:
  /// **'Penggajian (Payroll)'**
  String get menuPayroll;

  /// No description provided for @menuPayslips.
  ///
  /// In id, this message translates to:
  /// **'Slip Gaji'**
  String get menuPayslips;

  /// No description provided for @menuPaymentGateway.
  ///
  /// In id, this message translates to:
  /// **'Payment Gateway'**
  String get menuPaymentGateway;

  /// No description provided for @menuManagers.
  ///
  /// In id, this message translates to:
  /// **'Admin'**
  String get menuManagers;

  /// No description provided for @menuStaffAttendance.
  ///
  /// In id, this message translates to:
  /// **'Kehadiran Staf'**
  String get menuStaffAttendance;

  /// No description provided for @menuStaffSchedules.
  ///
  /// In id, this message translates to:
  /// **'Jadwal Staf'**
  String get menuStaffSchedules;

  /// No description provided for @menuAttendanceStats.
  ///
  /// In id, this message translates to:
  /// **'Statistik Staf'**
  String get menuAttendanceStats;

  /// No description provided for @menuEquipment.
  ///
  /// In id, this message translates to:
  /// **'Peralatan Gym'**
  String get menuEquipment;

  /// No description provided for @menuReports.
  ///
  /// In id, this message translates to:
  /// **'Laporan'**
  String get menuReports;

  /// No description provided for @menuActivity.
  ///
  /// In id, this message translates to:
  /// **'Log Aktivitas'**
  String get menuActivity;

  /// No description provided for @menuAnnouncements.
  ///
  /// In id, this message translates to:
  /// **'Pengumuman'**
  String get menuAnnouncements;

  /// No description provided for @menuSettings.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan'**
  String get menuSettings;

  /// No description provided for @menuProfile.
  ///
  /// In id, this message translates to:
  /// **'Profil Admin'**
  String get menuProfile;

  /// No description provided for @menuHelpCenter.
  ///
  /// In id, this message translates to:
  /// **'Panduan Pengguna'**
  String get menuHelpCenter;

  /// No description provided for @menuCheckUpdate.
  ///
  /// In id, this message translates to:
  /// **'Cek update'**
  String get menuCheckUpdate;

  /// No description provided for @menuSearchEmpty.
  ///
  /// In id, this message translates to:
  /// **'Menu tidak ditemukan'**
  String get menuSearchEmpty;

  /// No description provided for @activeBranchDefault.
  ///
  /// In id, this message translates to:
  /// **'FitFlow Gym'**
  String get activeBranchDefault;

  /// No description provided for @branchManagementHint.
  ///
  /// In id, this message translates to:
  /// **'Ketuk untuk ganti cabang'**
  String get branchManagementHint;

  /// No description provided for @checkInTitle.
  ///
  /// In id, this message translates to:
  /// **'Check-in'**
  String get checkInTitle;

  /// No description provided for @checkInSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Sambut member, catat kehadiran.'**
  String get checkInSubtitle;

  /// No description provided for @scanQrTab.
  ///
  /// In id, this message translates to:
  /// **'Scan QR'**
  String get scanQrTab;

  /// No description provided for @manualCheckInTab.
  ///
  /// In id, this message translates to:
  /// **'Check-in manual'**
  String get manualCheckInTab;

  /// No description provided for @searchMemberPlaceholder.
  ///
  /// In id, this message translates to:
  /// **'Cari nama atau ID member...'**
  String get searchMemberPlaceholder;

  /// No description provided for @membersFoundCount.
  ///
  /// In id, this message translates to:
  /// **'{count} member ditemukan'**
  String membersFoundCount(int count);

  /// No description provided for @membershipActiveBadge.
  ///
  /// In id, this message translates to:
  /// **'Membership aktif'**
  String get membershipActiveBadge;

  /// No description provided for @membershipExpiredBadge.
  ///
  /// In id, this message translates to:
  /// **'Kedaluwarsa'**
  String get membershipExpiredBadge;

  /// No description provided for @membershipSuspendedBadge.
  ///
  /// In id, this message translates to:
  /// **'Ditangguhkan'**
  String get membershipSuspendedBadge;

  /// No description provided for @membershipInactiveBadge.
  ///
  /// In id, this message translates to:
  /// **'Tidak aktif'**
  String get membershipInactiveBadge;

  /// No description provided for @checkedInBadge.
  ///
  /// In id, this message translates to:
  /// **'Sudah check-in'**
  String get checkedInBadge;

  /// No description provided for @notCheckedInLabel.
  ///
  /// In id, this message translates to:
  /// **'Belum check-in'**
  String get notCheckedInLabel;

  /// No description provided for @validUntilLabel.
  ///
  /// In id, this message translates to:
  /// **'Hingga {date}'**
  String validUntilLabel(String date);

  /// No description provided for @gymSessionsLabel.
  ///
  /// In id, this message translates to:
  /// **'GYM SESSIONS: {remaining}/{total}'**
  String gymSessionsLabel(int remaining, int total);

  /// No description provided for @confirmCheckInBtn.
  ///
  /// In id, this message translates to:
  /// **'Konfirmasi check-in'**
  String get confirmCheckInBtn;

  /// No description provided for @confirmCheckOutBtn.
  ///
  /// In id, this message translates to:
  /// **'Konfirmasi check-out'**
  String get confirmCheckOutBtn;

  /// No description provided for @searchMemberPrompt.
  ///
  /// In id, this message translates to:
  /// **'Cari nama, email, HP, atau ID member untuk check-in manual.'**
  String get searchMemberPrompt;

  /// No description provided for @noMembersFound.
  ///
  /// In id, this message translates to:
  /// **'Member tidak ditemukan'**
  String get noMembersFound;

  /// No description provided for @checkInSuccessTitle.
  ///
  /// In id, this message translates to:
  /// **'Check-in Berhasil!'**
  String get checkInSuccessTitle;

  /// No description provided for @checkOutSuccessTitle.
  ///
  /// In id, this message translates to:
  /// **'Check-out Berhasil!'**
  String get checkOutSuccessTitle;

  /// No description provided for @checkInDeniedTitle.
  ///
  /// In id, this message translates to:
  /// **'Akses Ditolak'**
  String get checkInDeniedTitle;

  /// No description provided for @ptPackagesTitle.
  ///
  /// In id, this message translates to:
  /// **'Paket PT'**
  String get ptPackagesTitle;

  /// No description provided for @ptPackagesEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada paket PT'**
  String get ptPackagesEmpty;

  /// No description provided for @ptMembershipsTitle.
  ///
  /// In id, this message translates to:
  /// **'Membership PT'**
  String get ptMembershipsTitle;

  /// No description provided for @ptMembershipsEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada membership PT aktif'**
  String get ptMembershipsEmpty;

  /// No description provided for @helpCenterTitle.
  ///
  /// In id, this message translates to:
  /// **'Panduan Pengguna'**
  String get helpCenterTitle;

  /// No description provided for @helpCenterSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Panduan cepat operasional & dukungan FitFlow'**
  String get helpCenterSubtitle;

  /// No description provided for @logoutAction.
  ///
  /// In id, this message translates to:
  /// **'Keluar'**
  String get logoutAction;

  /// No description provided for @profileMenuLabel.
  ///
  /// In id, this message translates to:
  /// **'Profil Admin'**
  String get profileMenuLabel;

  /// No description provided for @retryAction.
  ///
  /// In id, this message translates to:
  /// **'Coba Lagi'**
  String get retryAction;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
