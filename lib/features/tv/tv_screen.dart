import 'package:flutter/material.dart';

import '../../core/backend_api.dart';
import 'tv_repository.dart';
import 'tv_models.dart';
import 'tv_player_screen.dart';

class TvScreen extends StatefulWidget {
  const TvScreen({
    super.key,
    required this.api,
    required this.allowedPlaybackHosts,
  });

  final BackendApi api;
  final Set<String> allowedPlaybackHosts;

  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
  late TvRepository _repository;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _channels = <TvChannel>[];
  String? _cursor;
  String? _error;
  String? _category;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _repository = TvRepository(
      api: widget.api,
      allowedPlaybackHosts: widget.allowedPlaybackHosts,
    );
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void didUpdateWidget(covariant TvScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.api, widget.api) ||
        !setEquals(oldWidget.allowedPlaybackHosts, widget.allowedPlaybackHosts)) {
      _repository = TvRepository(
        api: widget.api,
        allowedPlaybackHosts: widget.allowedPlaybackHosts,
      );
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || !_hasMore) return;
    if (_scroll.position.extentAfter < 500) _loadMore();
  }

  Future<void> _load({required bool reset}) async {
    if (_loading || _loadingMore && !reset) return;
    final generation = ++_generation;
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
        _channels.clear();
        _cursor = null;
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final page = await _repository.listChannels(
        limit: 30,
        cursor: reset ? null : _cursor,
        category: _category,
        query: _search.text.trim().isEmpty ? null : _search.text.trim(),
      );
      if (!mounted || generation != _generation) return;
      final existing = _channels.map((channel) => channel.id).toSet();
      setState(() {
        for (final channel in page.items) {
          if (existing.add(channel.id)) _channels.add(channel);
        }
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null && page.items.isNotEmpty;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error is BackendApiException
            ? error.message
            : 'TV catalogue is unavailable. Check your connection and retry.';
      });
    }
  }

  Future<void> _loadMore() => _load(reset: false);

  Future<void> _openChannel(TvChannel channel) async {
    if (channel.availability == 'offline') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This channel is currently offline.')),
      );
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TvPlayerScreen(
        repository: _repository,
        channel: channel,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.live_tv_rounded, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Testagram TV', style: theme.textTheme.headlineSmall),
                ),
                IconButton(
                  tooltip: 'Refresh channels',
                  onPressed: _loading ? null : () => _load(reset: true),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(reset: true),
              decoration: InputDecoration(
                hintText: 'Search channels',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _search.clear();
                    _load(reset: true);
                  },
                  icon: const Icon(Icons.clear),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                _categoryChip('All', null),
                _categoryChip('News', 'news'),
                _categoryChip('Sports', 'sports'),
                _categoryChip('Music', 'music'),
                _categoryChip('Entertainment', 'entertainment'),
                _categoryChip('Kids', 'kids'),
                _categoryChip('Documentary', 'documentary'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: _buildCatalogue(theme)),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, String? value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: _category == value,
          onSelected: (_) {
            if (_category == value) return;
            setState(() => _category = value);
            _load(reset: true);
          },
        ),
      );

  Widget _buildCatalogue(ThemeData theme) {
    if (_loading && _channels.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _channels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tv_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.live_tv_outlined, size: 48),
            const SizedBox(height: 12),
            Text('No channels found', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text('Try another search or category.'),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: _channels.length + (_loadingMore || _hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _channels.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: _loadMore,
                        child: const Text('Load more'),
                      ),
              ),
            );
          }
          final channel = _channels[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              leading: _channelLogo(channel),
              title: Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [
                  if (channel.countryCode != null) channel.countryCode!,
                  if (channel.categories.isNotEmpty) channel.categories.take(2).join(' • '),
                  channel.availability,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.play_circle_outline, size: 30),
              onTap: () => _openChannel(channel),
            ),
          );
        },
      ),
    );
  }

  Widget _channelLogo(TvChannel channel) {
    final uri = channel.logoUrl;
    if (uri == null) {
      return const CircleAvatar(child: Icon(Icons.live_tv));
    }
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ClipOval(
        child: Image.network(
          uri.toString(),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.live_tv),
        ),
      ),
    );
  }
}
