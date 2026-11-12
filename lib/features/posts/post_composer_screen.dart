import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';

class PostComposerScreen extends StatefulWidget {
  const PostComposerScreen({super.key, required this.api});

  final BackendApi api;

  @override
  State<PostComposerScreen> createState() => _PostComposerScreenState();
}

class _PostComposerScreenState extends State<PostComposerScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _random = Random.secure();
  String _visibility = 'public';
  String? _keyPayload;
  String? _idempotencyKey;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _keyFor(String content, String visibility) {
    final payload = '$visibility\n$content';
    if (_keyPayload != payload || _idempotencyKey == null) {
      _keyPayload = payload;
      _idempotencyKey =
          'post-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_random.nextInt(1 << 32).toRadixString(36)}';
    }
    return _idempotencyKey!;
  }

  Future<void> _publish() async {
    final content = _controller.text.trim();
    if (content.isEmpty || content.runes.length > 5000 || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.api.createPost(
        content: content,
        visibility: _visibility,
        idempotencyKey: _keyFor(content, _visibility),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final length = _controller.text.runes.length;
    final canPublish = length > 0 && length <= 5000 && !_submitting;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create post'),
        leading: IconButton(
          tooltip: 'Close composer',
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: canPublish ? _publish : null,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Publish'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'Share what is happening',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your post will appear in the Testagram feed. Public posts can be federated when you have enabled federation in your settings.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              minLines: 7,
              maxLines: 14,
              maxLength: 5000,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                hintText: 'What would you like to share?',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$length / 5,000',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: _visibility,
              decoration: const InputDecoration(
                labelText: 'Who can see this post?',
                prefixIcon: Icon(Icons.visibility_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Public')),
                DropdownMenuItem(value: 'followers', child: Text('Followers')),
                DropdownMenuItem(value: 'private', child: Text('Only me')),
              ],
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _visibility = value;
                        _error = null;
                      });
                    },
            ),
            if (_visibility == 'public') ...[
              const SizedBox(height: 10),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.public),
                title: Text('Federation follows your account settings'),
                subtitle: Text(
                  'If federation is enabled, this public post is queued for delivery to connected ActivityPub servers.',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 6),
              const Text(
                'You can retry safely. Testagram uses the same request key when the content has not changed.',
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: canPublish ? _publish : null,
              icon: const Icon(Icons.send_rounded),
              label: Text(_submitting ? 'Publishing…' : 'Publish post'),
            ),
          ],
        ),
      ),
    );
  }
}
