import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    required this.api,
    required this.profile,
  });

  final BackendApi api;
  final Map<String, dynamic> profile;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _displayName;
  late final TextEditingController _bio;
  late final TextEditingController _website;
  late final TextEditingController _location;
  late final TextEditingController _x;
  late final TextEditingController _instagram;
  late final TextEditingController _linkedin;

  Uint8List? _avatarBytes;
  Uint8List? _coverBytes;
  XFile? _avatarFile;
  XFile? _coverFile;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final links = widget.profile['social_links'] is Map
        ? Map<String, dynamic>.from(widget.profile['social_links'] as Map)
        : <String, dynamic>{};
    _displayName = TextEditingController(text: _value('display_name'));
    _bio = TextEditingController(text: _value('bio'));
    _website = TextEditingController(text: _value('website'));
    _location = TextEditingController(text: _value('location'));
    _x = TextEditingController(text: (links['x'] ?? links['twitter'] ?? '').toString());
    _instagram = TextEditingController(text: (links['instagram'] ?? '').toString());
    _linkedin = TextEditingController(text: (links['linkedin'] ?? '').toString());
  }

  String _value(String key) => (widget.profile[key] ?? '').toString();

  @override
  void dispose() {
    _displayName.dispose();
    _bio.dispose();
    _website.dispose();
    _location.dispose();
    _x.dispose();
    _instagram.dispose();
    _linkedin.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool cover}) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 84,
        maxWidth: cover ? 1600 : 640,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
        throw const BackendApiException('Choose an image smaller than 20 MiB.');
      }
      if (!mounted) return;
      setState(() {
        if (cover) {
          _coverFile = file;
          _coverBytes = bytes;
        } else {
          _avatarFile = file;
          _avatarBytes = bytes;
        }
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  String _contentType(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    if (name.endsWith('.avif')) return 'image/avif';
    return 'image/jpeg';
  }

  Future<String> _upload(XFile file, Uint8List bytes, String kind) async {
    final asset = await widget.api.uploadPublicImage(
      name: file.name,
      contentType: _contentType(file),
      bytes: bytes,
    );
    final key = (asset['key'] ?? '').toString();
    if (key.isEmpty) {
      throw BackendApiException('The $kind image upload was not confirmed.');
    }
    return key;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var avatarKey = _value('avatar_key');
      var coverKey = _value('cover_key');
      if (_avatarFile != null && _avatarBytes != null) {
        avatarKey = await _upload(_avatarFile!, _avatarBytes!, 'Avatar');
      }
      if (_coverFile != null && _coverBytes != null) {
        coverKey = await _upload(_coverFile!, _coverBytes!, 'Cover');
      }
      final response = await widget.api.updateMyProfile(
        displayName: _displayName.text.trim(),
        bio: _bio.text.trim(),
        website: _website.text.trim(),
        location: _location.text.trim(),
        avatarKey: avatarKey,
        coverKey: coverKey,
        socialLinks: {
          'x': _x.text.trim(),
          'instagram': _instagram.text.trim(),
          'linkedin': _linkedin.text.trim(),
        },
      );
      final data = response['data'];
      if (data is! Map) {
        throw const BackendApiException('The server did not return the updated profile.');
      }
      if (mounted) Navigator.of(context).pop(Map<String, dynamic>.from(data));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _imagePreview({
    required bool cover,
    required String url,
    required Uint8List? bytes,
  }) {
    final fallback = cover
        ? Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.landscape_rounded, size: 36)),
          )
        : CircleAvatar(
            radius: 38,
            child: Text(
              _displayName.text.isEmpty ? '?' : _displayName.text[0].toUpperCase(),
            ),
          );
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity);
    }
    if (url.startsWith('https://') || url.startsWith('http://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl = _value('cover_url');
    final avatarUrl = _value('avatar_url');
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 150,
                child: _imagePreview(cover: true, url: coverUrl, bytes: _coverBytes),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _saving ? null : () => _pickImage(cover: true),
                icon: const Icon(Icons.photo_camera_back_outlined),
                label: const Text('Change cover'),
              ),
            ),
            Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: _imagePreview(cover: false, url: avatarUrl, bytes: _avatarBytes),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile photo', style: theme.textTheme.titleMedium),
                      Text('Use a clear square image.', style: theme.textTheme.bodySmall),
                      TextButton.icon(
                        onPressed: _saving ? null : () => _pickImage(cover: false),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Change photo'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _displayName,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Display name'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Enter a display name.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bio,
              maxLength: 500,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell people a little about yourself',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Location',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _website,
              maxLength: 2048,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Website',
                hintText: 'https://example.com',
                prefixIcon: Icon(Icons.link_rounded),
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return null;
                final uri = Uri.tryParse(text);
                if (uri == null || !uri.hasAuthority ||
                    (uri.scheme != 'https' && uri.scheme != 'http')) {
                  return 'Use a valid http:// or https:// address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text('Social links', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _x,
              maxLength: 256,
              decoration: const InputDecoration(
                labelText: 'X username or profile URL',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            TextFormField(
              controller: _instagram,
              maxLength: 256,
              decoration: const InputDecoration(
                labelText: 'Instagram username or URL',
                prefixIcon: Icon(Icons.camera_alt_outlined),
              ),
            ),
            TextFormField(
              controller: _linkedin,
              maxLength: 256,
              decoration: const InputDecoration(
                labelText: 'LinkedIn profile URL',
                prefixIcon: Icon(Icons.work_outline_rounded),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Saving profile…' : 'Save profile'),
            ),
          ],
        ),
      ),
    );
  }
}
