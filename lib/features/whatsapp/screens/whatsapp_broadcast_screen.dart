import 'package:flutter/material.dart';
import '../../shared/widgets/custom_app_bar.dart';
import '../services/whatsapp_api_service.dart';

class WhatsappBroadcastScreen extends StatefulWidget {
  @override
  _WhatsappBroadcastScreenState createState() => _WhatsappBroadcastScreenState();
}

class _WhatsappBroadcastScreenState extends State<WhatsappBroadcastScreen> {
  final TextEditingController _messageController = TextEditingController();
  String _selectedTarget = 'active'; // active, expired, all
  bool _isSending = false;

  Future<void> _sendBroadcast() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pesan tidak boleh kosong')));
      return;
    }

    setState(() => _isSending = true);

    try {
      final success = await WhatsappApiService.sendBroadcast({
        'targetSegment': _selectedTarget,
        'message': _messageController.text.trim(),
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Broadcast berhasil diproses')));
        _messageController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memproses broadcast')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Broadcast WhatsApp'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Target Penerima', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedTarget,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                DropdownMenuItem(value: 'active', child: Text('Member Aktif')),
                DropdownMenuItem(value: 'expired', child: Text('Member Expired')),
                DropdownMenuItem(value: 'all', child: Text('Semua Member')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedTarget = val);
              },
            ),
            SizedBox(height: 16),
            Text('Pesan Broadcast', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Ketik pesan broadcast Anda di sini...\nGunakan {nama_member} untuk memanggil nama member.',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSending ? null : _sendBroadcast,
              child: _isSending 
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Kirim Pesan Massal'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            )
          ],
        ),
      ),
    );
  }
}
