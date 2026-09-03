import 'package:flutter/material.dart';
import '../../core/utils/auth_utils.dart';

class GymSwitcherWidget extends StatefulWidget {
  @override
  _GymSwitcherWidgetState createState() => _GymSwitcherWidgetState();
}

class _GymSwitcherWidgetState extends State<GymSwitcherWidget> {
  List<dynamic> _availableGyms = [];
  String? _currentGymId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGyms();
  }

  Future<void> _loadGyms() async {
    // In a real implementation, this would fetch from an API
    // For now, we simulate fetching the list of gyms the owner manages
    final current = await AuthUtils.getGymId();
    setState(() {
      _currentGymId = current;
      _availableGyms = [
        {'id': current ?? '1', 'name': 'Demo Gym (Current)'},
        {'id': '2', 'name': 'Demo Gym Branch 2'},
        {'id': '3', 'name': 'Demo Gym Premium'}
      ];
      _isLoading = false;
    });
  }

  Future<void> _switchGym(String newGymId) async {
    // Logic to clear local state and reload app with new gym id
    await AuthUtils.setGymId(newGymId);
    setState(() {
      _currentGymId = newGymId;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Beralih ke cabang baru...'))
    );
    
    // Navigator.pushAndRemoveUntil(...) to reload dashboard
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return CircularProgressIndicator();

    return PopupMenuButton<String>(
      icon: Icon(Icons.store),
      tooltip: 'Pindah Cabang Gym',
      onSelected: _switchGym,
      itemBuilder: (BuildContext context) {
        return _availableGyms.map((gym) {
          return PopupMenuItem<String>(
            value: gym['id'].toString(),
            child: Row(
              children: [
                Icon(
                  gym['id'] == _currentGymId ? Icons.check_circle : Icons.storefront,
                  color: gym['id'] == _currentGymId ? Colors.green : Colors.grey,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(gym['name']),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
