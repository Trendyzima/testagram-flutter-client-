  Future<Map<String, dynamic>> listTvChannels({
    int limit = 20,
    String? cursor,
    String? country,
    String? category,
    String? language,
    String? query,
  }) {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be between 1 and 50');
    }
    if (country != null && !RegExp(r'^[A-Za-z]{2}$').hasMatch(country)) {
      throw ArgumentError.value(country, 'country', 'Country must be a two-letter ISO code');
    }
    return _request('GET', baseUri.resolve('/api/tv/channels').replace(queryParameters: {
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (country != null) 'country': country.toUpperCase(),
      if (category != null && category.isNotEmpty) 'category': category,
      if (language != null && language.isNotEmpty) 'language': language,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    }));
  }

  Future<Map<String, dynamic>> getTvPlayback(String channelId) {
    if (channelId.trim().isEmpty || channelId.length > 128 ||
        channelId.contains('/') || channelId.contains('..')) {
      throw ArgumentError.value(channelId, 'channelId', 'Invalid channel ID');
    }
    return _request('POST', baseUri.resolve('/api/tv/channels/${Uri.encodeComponent(channelId)}/playback'));
  }

