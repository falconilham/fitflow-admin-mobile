import 'package:flutter/material.dart';
import '../../../shared/widgets/custom_app_bar.dart';

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
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

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Check-in Berhasil: Budi Santoso (Pro Plan)';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-in Berhasil!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Face Recognition Scanner'),
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
                color: Colors.white.withValues(alpha: 0.3),
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
                borderRadius: const BorderRadius.all(Radius.elliptical(140, 190)),
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
                      const CircularProgressIndicator() 
                    else 
                      const Icon(Icons.center_focus_strong, color: Colors.green, size: 32),
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _onFaceDetected,
                      child: const Text('Simulasi Pindai Wajah'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
