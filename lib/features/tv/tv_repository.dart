import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/tv/tv_models.dart';

/// Typed TV client. All catalogue reads and playback grants go through Backend.
class TvRepository {
  const TvRepository({
    required this.api,
    required this.allowedPlaybackHosts,
  });

  final BackendApi api;

  /// Exact host allowlist supplied by release configuration. An empty set
  /// intentionally rejects every playback grant until the CDN hostname is approved.
  final Set<String> allowedPlaybackHosts;

  Future<TvChannelPage> listChannels({
    int limit = 20,
    String? cursor,
    String? country,
    String? category,
    String? language,
    String? query,
  }) async {
    final response = await api.listTvChannels(
      limit: limit,
      cursor: cursor,
      country: country,
      category: category,
      language: language,
      query: query,
    );
    return TvChannelPage.fromJson(_data(response));
  }

  Future<TvChannel> getChannel(String channelId) async {
    final response = await api.getTvChannel(channelId);
    return TvChannel.fromJson(_data(response));
  }

  Future<TvPlaybackGrant> requestPlayback(
    String channelId, {
    String profile = 'auto',
    DateTime? now,
  }) async {
    final response = await api.createTvPlaybackGrant(
      channelId,
      playbackProfile: profile,
    );
    return TvPlaybackGrant.fromJson(
      _data(response),
      allowedHosts: allowedPlaybackHosts,
      now: now,
    );
  }

  Map<String, dynamic> _data(Map<String, dynamic> response) {
    if (response['ok'] == false) {
      throw const BackendApiException('The TV service rejected this request.');
    }
    final value = response['data'];
    if (value is Map) return Map<String, dynamic>.from(value);
    // Some Backend routes return their DTO as the root object. Only accept
    // this shape when it is clearly a TV response, not an arbitrary envelope.
    if (response.containsKey('items') || response.containsKey('channel_id')) {
      return response;
    }
    throw const FormatException('Backend returned an invalid TV response envelope');
  }
}
