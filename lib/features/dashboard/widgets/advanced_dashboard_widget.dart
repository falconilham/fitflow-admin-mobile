import 'package:flutter/material.dart';

class AdvancedDashboardWidget extends StatelessWidget {
  final Map<String, dynamic> analyticsData;

  const AdvancedDashboardWidget({Key? key, required this.analyticsData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analytics Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            // Placeholder for fl_chart
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart, size: 48, color: Colors.blue),
                    SizedBox(height: 8),
                    Text('Advanced Chart\n(Revenue & Check-in Trends)', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total Member', analyticsData['totalMembers']?.toString() ?? '0'),
                _buildStatItem('Active PT', analyticsData['activePT']?.toString() ?? '0'),
                _buildStatItem('Revenue', 'Rp ${analyticsData['monthlyRevenue'] ?? 0}'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
