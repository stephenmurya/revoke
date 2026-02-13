import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/native_bridge.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/squad_service.dart';
import '../../core/theme/app_theme.dart';
import '../squad/tribunal_screen.dart';

class BegForTimeScreen extends StatefulWidget {
  final String appName;
  final String packageName;

  const BegForTimeScreen({
    super.key,
    required this.appName,
    required this.packageName,
  });

  @override
  State<BegForTimeScreen> createState() => _BegForTimeScreenState();
}

class _BegForTimeScreenState extends State<BegForTimeScreen> {
  static const List<int> _durationOptions = [5, 10, 20, 30];

  final TextEditingController _reasonController = TextEditingController();
  int _selectedMinutes = 5;
  bool _submitting = false;

  Future<Map<String, dynamic>> _loadAppDetails() async {
    try {
      return await NativeBridge.getAppDetails(widget.packageName);
    } catch (_) {
      return {'name': widget.appName};
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitPlea() async {
    if (_submitting) return;

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ADD A REASON FOR THE SQUAD.')),
      );
      return;
    }

    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);
    try {
      final userData = await AuthService.getUserData();
      final squadId = (userData?['squadId'] as String?)?.trim();
      final nickname = (userData?['nickname'] as String?)?.trim();

      if (squadId == null || squadId.isEmpty) {
        throw Exception('NO SQUAD FOUND');
      }

      final newPleaId = await SquadService.createPlea(
        uid: uid,
        userName: nickname?.isNotEmpty == true ? nickname! : 'A Member',
        squadId: squadId,
        appName: widget.appName,
        packageName: widget.packageName,
        durationMinutes: _selectedMinutes,
        reason: reason,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TribunalScreen(pleaId: newPleaId)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PLEA FAILED: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Beg for time', style: AppTheme.h3),
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _loadAppDetails(),
          builder: (context, snapshot) {
            final appData = snapshot.data;
            final iconBytes = appData?['icon'] as Uint8List?;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: AppSemanticColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppSemanticColors.primaryText.withValues(
                            alpha: 0.08,
                          ),
                          width: 1.5,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: iconBytes != null
                          ? Image.memory(iconBytes, fit: BoxFit.cover)
                          : const Icon(
                              Icons.apps_rounded,
                              size: 56,
                              color: AppSemanticColors.accent,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.appName,
                    textAlign: TextAlign.center,
                    style: AppTheme.xlMedium,
                  ),
                  const SizedBox(height: 24),
                  Text('Time request', style: AppTheme.labelSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _durationOptions.map((minutes) {
                      final selected = _selectedMinutes == minutes;
                      return ChoiceChip(
                        label: Text('$minutes mins'),
                        selected: selected,
                        labelStyle: AppTheme.smBold.copyWith(
                          color: selected
                              ? AppSemanticColors.onAccentText
                              : AppSemanticColors.primaryText,
                        ),
                        selectedColor: AppSemanticColors.accent,
                        backgroundColor: AppSemanticColors.surface,
                        side: BorderSide(
                          color: selected
                              ? AppSemanticColors.accent
                              : AppSemanticColors.primaryText,
                        ),
                        onSelected: (_) {
                          setState(() => _selectedMinutes = minutes);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _reasonController,
                    maxLines: 4,
                    maxLength: 180,
                    decoration: AppTheme.defaultInputDecoration(
                      labelText: 'Why do you need more time?',
                      hintText: 'Tell your squad exactly why...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submitPlea,
                    style: AppTheme.primaryButtonStyle,
                    child: Text(_submitting ? 'Sending...' : 'Beg for time'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _submitting ? null : () => context.go('/home'),
                    style: AppTheme.secondaryButtonStyle,
                    child: const Text('Cancel plea'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
