import 'package:flutter/material.dart';
import '../../shared/widgets/custom_app_bar.dart';
import '../services/whatsapp_api_service.dart';

class WhatsappDashboardScreen extends StatefulWidget {
  @override
  _WhatsappDashboardScreenState createState() => _WhatsappDashboardScreenState();
}

class _WhatsappDashboardScreenState extends State<WhatsappDashboardScreen> {
  Map<String, dynamic>? settings;
  bool isLoading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await WhatsappApiService.getSettings();
      setState(() {
        settings = data['data'];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'WhatsApp Automation'),
      body: isLoading 
        ? Center(child: CircularProgressIndicator())
        : error.isNotEmpty 
          ? Center(child: Text(error, style: TextStyle(color: Colors.red)))
          : _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    if (settings == null) {
      return Center(child: Text('Settings not found. Please configure on Web.'));
    }

    final isEnabled = settings!['isEnabled'] ?? false;
    final provider = settings!['provider'] ?? 'Not set';
    final usedCount = settings!['usedCount'] ?? 0;
    final monthlyQuota = settings!['monthlyQuota'] ?? 0;

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Card(
          color: isEnabled ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: isEnabled ? Colors.green : Colors.red,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Status Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Icon(
                      isEnabled ? Icons.check_circle : Icons.error, 
                      color: isEnabled ? Colors.green : Colors.red,
                    )
                  ],
                ),
                SizedBox(height: 8),
                Text(isEnabled ? 'Engine Aktif dan berjalan' : 'Engine Dinonaktifkan'),
                SizedBox(height: 16),
                Text('Provider: ${provider.toString().toUpperCase()}', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Penggunaan Bulan Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 16),
                LinearProgressIndicator(
                  value: monthlyQuota > 0 ? (usedCount / monthlyQuota) : 0,
                  backgroundColor: Colors.grey[800],
                  color: Colors.blue,
                  minHeight: 10,
                ),
                SizedBox(height: 8),
                Text('$usedCount / $monthlyQuota Pesan terkirim'),
              ],
            ),
          ),
        ),
        SizedBox(height: 24),
        ElevatedButton.icon(
          icon: Icon(Icons.list),
          label: Text('Lihat Riwayat Logs'),
          onPressed: () {
            // Navigator.push to logs
          },
        ),
        SizedBox(height: 12),
        ElevatedButton.icon(
          icon: Icon(Icons.campaign),
          label: Text('Kirim Pesan Broadcast'),
          onPressed: () {
            // Navigator.push to broadcast
          },
        ),
      ],
    );
  }
}
