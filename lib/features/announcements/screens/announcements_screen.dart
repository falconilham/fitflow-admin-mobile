import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/api_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/drawer_menu_button.dart';
import '../../../shared/utils/error_handler.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------
final _announcementsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    return await ref.read(apiRepositoryProvider).getAnnouncements();
  } on DioException catch (e) {
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404)
      return [];
    rethrow;
  }
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  // ── form state ───────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _ctaTextCtrl = TextEditingController();
  final _ctaUrlCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;
  bool _saving = false;
  int? _editingId;

  // Image state
  File? _imageFile;
  String? _imagePreviewUrl; // existing URL from server

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _imageUrlCtrl.dispose();
    _ctaTextCtrl.dispose();
    _ctaUrlCtrl.dispose();
    super.dispose();
  }

  void _resetForm() {
    _titleCtrl.clear();
    _bodyCtrl.clear();
    _imageUrlCtrl.clear();
    _ctaTextCtrl.clear();
    _ctaUrlCtrl.clear();
    _startDate = null;
    _endDate = null;
    _isActive = true;
    _editingId = null;
    _imageFile = null;
    _imagePreviewUrl = null;
  }

  void _openCreate() {
    _resetForm();
    _showDialog();
  }

  void _openEdit(Map<String, dynamic> item) {
    _titleCtrl.text = item['title'] ?? '';
    _bodyCtrl.text = item['body'] ?? '';
    _ctaTextCtrl.text = item['ctaText'] ?? '';
    _ctaUrlCtrl.text = item['ctaUrl'] ?? '';
    _isActive = item['isActive'] ?? true;
    _editingId = item['id'] as int?;
    _imageFile = null;
    final existingUrl = item['imageUrl']?.toString() ?? '';
    _imagePreviewUrl = existingUrl.isNotEmpty ? existingUrl : null;
    _imageUrlCtrl.text = existingUrl;
    if (item['startDate'] != null) {
      try { _startDate = DateTime.parse(item['startDate']); } catch (_) {}
    } else { _startDate = null; }
    if (item['endDate'] != null) {
      try { _endDate = DateTime.parse(item['endDate']); } catch (_) {}
    } else { _endDate = null; }
    _showDialog();
  }

  String? _fmtDate(DateTime? d) {
    if (d == null) return null;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
          _imagePreviewUrl = null;
          _imageUrlCtrl.clear();
        });
        Navigator.of(context).pop(); // close source picker if open
        _showDialog(); // re-show main dialog
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih gambar: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.accent),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.accent),
              title: const Text('Take Photo',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(apiRepositoryProvider);

      // Build payload — use multipart if file selected, else JSON with URL
      if (_imageFile != null) {
        // Multipart upload
        final bytes = await _imageFile!.readAsBytes();
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        final payload = <String, dynamic>{
          'title': _titleCtrl.text.trim(),
          if (_bodyCtrl.text.trim().isNotEmpty) 'body': _bodyCtrl.text.trim(),
          'imageUrl': base64Image,
          if (_ctaTextCtrl.text.trim().isNotEmpty) 'ctaText': _ctaTextCtrl.text.trim(),
          if (_ctaUrlCtrl.text.trim().isNotEmpty) 'ctaUrl': _ctaUrlCtrl.text.trim(),
          'isActive': _isActive,
          'startDate': _fmtDate(_startDate),
          'endDate': _fmtDate(_endDate),
        };
        if (_editingId != null) {
          await repo.updateAnnouncement(_editingId!, payload);
        } else {
          await repo.createAnnouncement(payload);
        }
      } else {
        final urlInput = _imageUrlCtrl.text.trim();
        final payload = <String, dynamic>{
          'title': _titleCtrl.text.trim(),
          if (_bodyCtrl.text.trim().isNotEmpty) 'body': _bodyCtrl.text.trim(),
          'imageUrl': urlInput.isNotEmpty ? urlInput : null,
          if (_ctaTextCtrl.text.trim().isNotEmpty) 'ctaText': _ctaTextCtrl.text.trim(),
          if (_ctaUrlCtrl.text.trim().isNotEmpty) 'ctaUrl': _ctaUrlCtrl.text.trim(),
          'isActive': _isActive,
          'startDate': _fmtDate(_startDate),
          'endDate': _fmtDate(_endDate),
        };
        if (_editingId != null) {
          await repo.updateAnnouncement(_editingId!, payload);
        } else {
          await repo.createAnnouncement(payload);
        }
      }

      if (mounted) Navigator.of(context).pop();
      ref.invalidate(_announcementsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Announcement?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('This cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(apiRepositoryProvider).deleteAnnouncement(id);
        ref.invalidate(_announcementsProvider);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.parse(e)), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> item) async {
    try {
      await ref.read(apiRepositoryProvider).updateAnnouncement(
        item['id'] as int,
        {'isActive': !(item['isActive'] as bool? ?? false)},
      );
      ref.invalidate(_announcementsProvider);
    } catch (_) {}
  }

  Future<void> _pickDate(bool isStart, StateSetter setModalState) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.accent)),
        child: child!,
      ),
    );
    if (picked != null) {
      setModalState(() {
        if (isStart) _startDate = picked; else _endDate = picked;
      });
    }
  }

  void _showDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text(
                    _editingId != null ? 'Edit Announcement' : 'New Announcement',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  TextFormField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Title *'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Body
                  TextFormField(
                    controller: _bodyCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Body / Message'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),

                  // ── Image section ────────────────────────────────────
                  const Text('Image (optional)',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 8),

                  // Preview
                  if (_imageFile != null || (_imagePreviewUrl != null && _imagePreviewUrl!.isNotEmpty))
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _imageFile != null
                              ? Image.file(_imageFile!, height: 140, width: double.infinity, fit: BoxFit.cover)
                              : Image.network(
                                  _imagePreviewUrl!,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 80, color: AppColors.card,
                                    child: const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.textMuted)),
                                  ),
                                ),
                        ),
                        Positioned(
                          top: 6, right: 6,
                          child: GestureDetector(
                            onTap: () => setModalState(() {
                              _imageFile = null;
                              _imagePreviewUrl = null;
                              _imageUrlCtrl.clear();
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.black.withAlpha(160), borderRadius: BorderRadius.circular(20)),
                              child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (_imageFile == null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Upload button
                        OutlinedButton.icon(
                          onPressed: _showImageSourcePicker,
                          icon: const Icon(Icons.upload_rounded, size: 18, color: AppColors.textSecondary),
                          label: const Text('Upload Image', style: TextStyle(color: AppColors.textSecondary)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // OR divider
                        Row(
                          children: [
                            const Expanded(child: Divider(color: AppColors.border, height: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('OR', style: TextStyle(color: AppColors.textMuted.withAlpha(160), fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const Expanded(child: Divider(color: AppColors.border, height: 1)),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // URL input
                        TextFormField(
                          controller: _imageUrlCtrl,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Paste Image URL',
                            hintText: 'https://...',
                            prefixIcon: Icon(Icons.link_rounded, size: 18, color: AppColors.textMuted),
                          ),
                          keyboardType: TextInputType.url,
                          onChanged: (v) => setModalState(() {
                            _imagePreviewUrl = v.trim().isNotEmpty ? v.trim() : null;
                          }),
                        ),
                      ],
                    ),

                  const SizedBox(height: 14),
                  // ─────────────────────────────────────────────────────

                  // CTA row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ctaTextCtrl,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(labelText: 'CTA Text'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _ctaUrlCtrl,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(labelText: 'CTA URL'),
                          keyboardType: TextInputType.url,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Date row
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerField(
                          label: 'Start Date', value: _startDate,
                          onTap: () async { await _pickDate(true, setModalState); },
                          onClear: () => setModalState(() => _startDate = null),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DatePickerField(
                          label: 'End Date', value: _endDate,
                          onTap: () async { await _pickDate(false, setModalState); },
                          onClear: () => setModalState(() => _endDate = null),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Active toggle
                  SwitchListTile(
                    value: _isActive,
                    onChanged: (v) => setModalState(() => _isActive = v),
                    title: const Text('Active (visible to members)', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    activeColor: AppColors.accent,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : Text(_editingId != null ? 'Save Changes' : 'Create'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(_announcementsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Announcements', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: () => ref.invalidate(_announcementsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add_rounded),
      ),
      body: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
        error: (e, _) => Center(child: Text(ErrorHandler.parse(e), style: const TextStyle(color: AppColors.error))),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              color: AppColors.accent, backgroundColor: AppColors.card,
              onRefresh: () async => ref.invalidate(_announcementsProvider),
              child: ListView(children: const [
                SizedBox(height: 200),
                Center(child: Column(children: [
                  Icon(Icons.campaign_rounded, color: AppColors.textMuted, size: 48),
                  SizedBox(height: 12),
                  Text('No announcements yet.', style: TextStyle(color: AppColors.textMuted)),
                  Text('Tap + to create one.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ])),
              ]),
            );
          }

          return RefreshIndicator(
            color: AppColors.accent, backgroundColor: AppColors.card,
            onRefresh: () async => ref.invalidate(_announcementsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final item = items[i];
                final isActive = item['isActive'] as bool? ?? false;
                final title = item['title']?.toString() ?? '';
                final body = item['body']?.toString() ?? '';
                final imageUrl = item['imageUrl']?.toString() ?? '';
                final ctaText = item['ctaText']?.toString() ?? '';
                final startDate = item['startDate']?.toString() ?? '';
                final endDate = item['endDate']?.toString() ?? '';

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isActive ? AppColors.accent.withAlpha(60) : AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner image
                      if (imageUrl.isNotEmpty && !imageUrl.startsWith('data:'))
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: Image.network(
                            imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                                ),
                                GestureDetector(
                                  onTap: () => _toggleActive(item),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isActive ? AppColors.accent.withAlpha(30) : AppColors.border.withAlpha(80),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: isActive ? AppColors.accent.withAlpha(100) : AppColors.border),
                                    ),
                                    child: Text(
                                      isActive ? 'Active' : 'Inactive',
                                      style: TextStyle(color: isActive ? AppColors.accent : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (body.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                            if (ctaText.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('CTA: $ctaText', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                            if (startDate.isNotEmpty || endDate.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                [if (startDate.isNotEmpty) 'From $startDate', if (endDate.isNotEmpty) 'Until $endDate'].join('  ·  '),
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _openEdit(item),
                                  icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.textSecondary),
                                  label: const Text('Edit', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                ),
                                TextButton.icon(
                                  onPressed: () => _delete(item['id'] as int),
                                  icon: const Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
                                  label: const Text('Delete', style: TextStyle(color: AppColors.error, fontSize: 13)),
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widget
// ---------------------------------------------------------------------------
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DatePickerField({required this.label, required this.value, required this.onTap, required this.onClear});

  String get _display {
    if (value == null) return 'Not set';
    return '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(_display, style: TextStyle(color: value != null ? AppColors.textPrimary : AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (value != null)
              GestureDetector(onTap: onClear, child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted))
            else
              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
