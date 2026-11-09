import 'dart:io';

void main() {
  const roots = ['lib', 'test', 'tool', 'android', 'ios', 'web'];
  const sourceExtensions = {
    '.dart', '.yaml', '.yml', '.gradle', '.kts', '.kt', '.java',
    '.swift', '.xml', '.plist', '.properties', '.json', '.sh',
  };
  final forbidden = <String, RegExp>{
    'Supabase SDK, URL, key or REST dependency': RegExp(r'supabase', caseSensitive: false),
    'Upstash dependency': RegExp(r'upstash', caseSensitive: false),
    'Redis dependency': RegExp(r'redis', caseSensitive: false),
  };
  final failures = <String>[];

  for (final rootPath in roots) {
    final root = Directory(rootPath);
    if (!root.existsSync()) continue;
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final extension = entity.path.substring(entity.path.lastIndexOf('.')).toLowerCase();
      if (!sourceExtensions.contains(extension)) continue;
      try {
        final source = entity.readAsStringSync();
        for (final entry in forbidden.entries) {
          if (entry.value.hasMatch(source)) {
            failures.add('${entity.path}: found forbidden ${entry.key}');
          }
        }
      } on FileSystemException catch (error) {
        failures.add('${entity.path}: could not inspect file: $error');
      }
    }
  }

  final pubspec = File('pubspec.yaml');
  if (pubspec.existsSync()) {
    final source = pubspec.readAsStringSync();
    for (final entry in forbidden.entries) {
      if (entry.value.hasMatch(source)) {
        failures.add('pubspec.yaml: found forbidden ${entry.key}');
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln(failures.join('\n'));
    exitCode = 1;
    return;
  }
  stdout.writeln('Dependency boundary clean: no Supabase, Upstash or Redis references in Flutter source, platform configuration, tooling or direct dependencies.');
}
