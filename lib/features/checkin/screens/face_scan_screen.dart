import 'package:flutter/material.dart';
import '../../shared/widgets/custom_app_bar.dart';

class FaceScanScreen extends StatefulWidget {
  @override
  _FaceScanScreenState createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  bool _isProcessing = false;
  String _statusMessage = 'Arahkan wajah member ke kamera...';

  void _onFaceDetected() {
    // Simulasi deteksi wajah ML Kit
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Memproses landmark wajah...';
    });

    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Check-in Berhasil: Budi Santoso (Pro Plan)';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check-in Berhasil!'),
            backgroundColor: Colors.green,
          )
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Face Recognition Scanner'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Dummy Camera View / Placeholder
          Container(
            color: Colors.black,
            child: Center(
              child: Icon(
                Icons.face_retouching_natural, 
                size: 120, 
                color: Colors.white.withOpacity(0.3)
              ),
            ),
          ),
          
          // Face Guide Overlay
          Center(
            child: Container(
              width: 280,
              height: 380,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isProcessing ? Colors.blue : Colors.green,
                  width: 3,
                ),
                borderRadius: BorderRadius.all(Radius.elliptical(140, 190)),
              ),
            ),
          ),
          
          // Status Footer
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isProcessing) 
                      CircularProgressIndicator() 
                    else 
                      Icon(Icons.center_focus_strong, color: Colors.green, size: 32),
                    SizedBox(height: 12),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _onFaceDetected,
                      child: Text('Simulasi Pindai Wajah'),
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
