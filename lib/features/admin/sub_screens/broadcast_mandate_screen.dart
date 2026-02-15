import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/theme_extensions.dart';

class BroadcastMandateScreen extends StatefulWidget {
  const BroadcastMandateScreen({super.key});

  @override
  State<BroadcastMandateScreen> createState() => _BroadcastMandateScreenState();
}

class _BroadcastMandateScreenState extends State<BroadcastMandateScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required.')),
      );
      return;
    }

    setState(() => _sending = true);
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

    try {
      await functions.httpsCallable('broadcastSystemMandate').call({
        'title': title,
        'body': body,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System mandate broadcasted.')),
      );
      Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = e.message ?? e.code;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $message')),
      );
      setState(() => _sending = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Broadcast mandate',
          style: context.text.titleLarge ?? AppTheme.h3,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Send a system notification to the global citizens topic.',
              style: AppTheme.baseRegular.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              maxLength: 60,
              textCapitalization: AppTheme.defaultTextCapitalization,
              style: context.text.bodyLarge ?? AppTheme.bodyLarge,
              decoration: AppTheme.defaultInputDecoration(
                hintText: 'Title of the mandate. Be concise. Be bold.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              textInputAction: TextInputAction.newline,
              maxLength: 240,
              minLines: 4,
              maxLines: 6,
              textCapitalization: AppTheme.defaultTextCapitalization,
              style: context.text.bodyLarge ?? AppTheme.bodyLarge,
              decoration: AppTheme.defaultInputDecoration(
                hintText: 'Write the mandate. Be brief. Be absolute.',
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.campaign_rounded, size: 18),
              label: Text(_sending ? 'Broadcasting...' : 'Broadcast'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
