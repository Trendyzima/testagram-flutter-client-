/// Defensive display parsing for creator analytics; it does not fetch or authorize data.
class PodcastAnalyticsPolicy {
  const PodcastAnalyticsPolicy._();
  static bool isLocked(dynamic record) => record is Map && record['is_locked'] == true;
  static int asCount(dynamic value) => int.tryParse('$value') ?? 0;
  static double asAmount(dynamic value) {
    final parsed = double.tryParse('$value') ?? 0;
    return parsed.isFinite ? parsed : 0;
  }
  static String formatDuration(dynamic seconds) {
    final value = asCount(seconds);
    if (value < 1) return '0m';
    final hours = value ~/ 3600;
    final minutes = (value % 3600) ~/ 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }
}
