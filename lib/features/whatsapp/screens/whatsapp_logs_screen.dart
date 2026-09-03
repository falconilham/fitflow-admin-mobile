import 'package:flutter/material.dart';
import '../../shared/widgets/custom_app_bar.dart';
import '../services/whatsapp_api_service.dart';

class WhatsappLogsScreen extends StatefulWidget {
  @override
  _WhatsappLogsScreenState createState() => _WhatsappLogsScreenState();
}

class _WhatsappLogsScreenState extends State<WhatsappLogsScreen> {
  List<dynamic> logs = [];
  bool isLoading = true;
  String error = '';
  int currentPage = 1;
  int totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => isLoading = true);
    try {
      final data = await WhatsappApiService.getLogs(page: currentPage, limit: 20);
      setState(() {
        logs = data['data']['rows'] ?? [];
        totalPages = data['data']['totalPages'] ?? 1;
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
      appBar: CustomAppBar(title: 'WhatsApp Logs'),
      body: isLoading 
        ? Center(child: CircularProgressIndicator())
        : error.isNotEmpty 
          ? Center(child: Text(error, style: TextStyle(color: Colors.red)))
          : _buildLogsList(),
    );
  }

  Widget _buildLogsList() {
    if (logs.isEmpty) {
      return Center(child: Text('Tidak ada log riwayat pesan.'));
    }

    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final status = log['status'] ?? 'unknown';
        final isSuccess = status == 'sent' || status == 'simulated';

        return ListTile(
          leading: Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? Colors.green : Colors.red,
          ),
          title: Text(log['phone'] ?? 'No Phone'),
          subtitle: Text(
            log['message'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            log['triggerType']?.toString().toUpperCase() ?? '-',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          isThreeLine: true,
        );
      },
    );
  }
}
