import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/utils/error_handler.dart';

final _managersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
  if (gymId == null) return [];
  try {
    return await ref.read(apiRepositoryProvider).getManagers(gymId);
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) return [];
    rethrow;
  }
});

class ManagersScreen extends ConsumerStatefulWidget {
  const ManagersScreen({super.key});

  @override
  ConsumerState<ManagersScreen> createState() => _ManagersScreenState();
}

class _ManagersScreenState extends ConsumerState<ManagersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  List<String> _permissions = [];
  bool _submitting = false;
  int? _editingId;

  // Available permissions matching the screenshot
  final List<Map<String, String>> _availablePermissions = [
    {'id': 'dashboard', 'label': 'Dashboard'},
    {'id': 'members', 'label': 'Members'},
    {'id': 'activity', 'label': 'Activity'},
    {'id': 'checkin', 'label': 'Check In'},
    {'id': 'staff', 'label': 'Staff'},
    {'id': 'reports', 'label': 'Reports'},
    {'id': 'equipment', 'label': 'Equipment'},
    {'id': 'settings', 'label': 'Settings'},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showForm([Map<String, dynamic>? manager]) {
    if (manager != null) {
      _editingId = manager['id'] as int?;
      _nameCtrl.text = (manager['name'] ?? '').toString();
      _emailCtrl.text = (manager['email'] ?? '').toString();
      _passwordCtrl.clear();
      final rawPerms = manager['permissions'];
      if (rawPerms is List) {
        _permissions = List<String>.from(rawPerms);
      } else {
        _permissions = [];
      }
    } else {
      _editingId = null;
      _nameCtrl.clear();
      _emailCtrl.clear();
      _passwordCtrl.clear();
      _permissions = _availablePermissions.map((e) => e['id']!).toList(); // Default all for new
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_editingId != null ? 'Edit Staff Member' : 'Add Staff Member',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 16),
              TextFormField(controller: _nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _decor('Name *'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _decor('Email *'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _passwordCtrl, obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _decor(_editingId != null ? 'New Password (Optional)' : 'Password *'),
                validator: (v) => _editingId == null && (v == null || v.isEmpty) ? 'Required' : null),
              
              const SizedBox(height: 24),
              const Text('FEATURE PERMISSIONS',
                  style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.2)),
              const SizedBox(height: 16),
              
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _availablePermissions.length,
                itemBuilder: (context, index) {
                  final perm = _availablePermissions[index];
                  final isChecked = _permissions.contains(perm['id']);
                  return InkWell(
                    onTap: () {
                      setModalState(() {
                        if (isChecked) {
                          _permissions.remove(perm['id']);
                        } else {
                          _permissions.add(perm['id']!);
                        }
                      });
                    },
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: isChecked,
                            onChanged: (v) {
                              setModalState(() {
                                if (v == true) {
                                  _permissions.add(perm['id']!);
                                } else {
                                  _permissions.remove(perm['id']);
                                }
                              });
                            },
                            activeColor: AppColors.accent,
                            checkColor: Colors.black,
                            side: const BorderSide(color: AppColors.textMuted, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          perm['label']!,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: _submitting ? null : () => _submit(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent, 
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _submitting
                  ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
                  : Text(_editingId != null ? 'Update' : 'Add', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext ctx) async {
    if (!_formKey.currentState!.validate()) return;
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    if (gymId == null) return;
    setState(() => _submitting = true);
    try {
      final data = {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'permissions': _permissions,
        if (_passwordCtrl.text.isNotEmpty) 'password': _passwordCtrl.text,
      };
      if (_editingId != null) {
        await ref.read(apiRepositoryProvider).updateManager(_editingId!, data);
      } else {
        await ref.read(apiRepositoryProvider).createManager(gymId, data);
      }
      ref.invalidate(_managersProvider);
      if (ctx.mounted) Navigator.pop(ctx);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.parse(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Delete Manager?', style: TextStyle(color: AppColors.textPrimary)),
      content: const Text('This will remove their access.', style: TextStyle(color: AppColors.textMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
      ],
    ));
    if (confirm != true) return;
    try {
      await ref.read(apiRepositoryProvider).deleteManager(id);
      ref.invalidate(_managersProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.parse(e))));
    }
  }

  InputDecoration _decor(String label) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(color: AppColors.textMuted),
    filled: true, fillColor: AppColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
  );

  @override
  Widget build(BuildContext context) {
    final mgAsync = ref.watch(_managersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Admin', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.black),
              label: const Text('Add Admin', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: mgAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
        error: (e, _) => Center(child: Text(ErrorHandler.parse(e), style: const TextStyle(color: AppColors.error))),
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              color: AppColors.accent, backgroundColor: AppColors.card,
              onRefresh: () async => ref.invalidate(_managersProvider),
              child: ListView(children: const [
                SizedBox(height: 200),
                Center(child: Text('No admins yet. Tap Add Admin to start.', style: TextStyle(color: AppColors.textMuted))),
              ]),
            );
          }
          return RefreshIndicator(
            color: AppColors.accent, backgroundColor: AppColors.card,
            onRefresh: () async => ref.invalidate(_managersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final m = list[i];
                final name = (m['name'] ?? 'Unknown').toString();
                final email = (m['email'] ?? '').toString();
                final initials = name.isNotEmpty ? name[0].toUpperCase() : 'A';
                final joinedAt = m['createdAt'] ?? m['created_at'];
                final joinedStr = joinedAt != null ? formatDate(joinedAt.toString()) : '';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card, 
                    borderRadius: BorderRadius.circular(16), 
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF84CC16).withAlpha(150), // Lime green like web
                      radius: 20,
                      child: Text(initials, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (email.isNotEmpty) Text(email, style: const TextStyle(color: AppColors.textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                    if (joinedStr.isNotEmpty)
                      Text(joinedStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _showForm(m),
                          icon: const Icon(Icons.edit_note_rounded, color: AppColors.textMuted, size: 24),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          onPressed: () => _delete((m['id'] as num).toInt()),
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 24),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
