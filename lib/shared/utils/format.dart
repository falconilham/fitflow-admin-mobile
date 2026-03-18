import 'package:intl/intl.dart';

String formatCurrency(double amount) {
  return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
}

String formatDate(String? isoString) {
  if (isoString == null || isoString.isEmpty) return '-';
  try {
    return DateFormat('d MMM yyyy', 'id_ID').format(DateTime.parse(isoString).toLocal());
  } catch (_) {
    return isoString;
  }
}

String formatTime(String? isoString) {
  if (isoString == null || isoString.isEmpty) return '-';
  try {
    return DateFormat('HH:mm').format(DateTime.parse(isoString).toLocal());
  } catch (_) {
    return isoString;
  }
}

String formatDateTime(String? isoString) {
  if (isoString == null || isoString.isEmpty) return '-';
  try {
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(DateTime.parse(isoString).toLocal());
  } catch (_) {
    return isoString;
  }
}

String formatPrice(int price) => price.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
