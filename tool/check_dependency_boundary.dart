import 'dart:io';

void main() {
  const roots = ['lib', 'test', 'tool', 'android', 'ios', 'web'];
  const sourceExtensions = {
    '.dart', '.yaml', '.yml', '.gradle', '.kts', '.kt', '.java',
    '.swift', '.xml', '.plist', '.properties', '.json', '.sh',
  };
  // Assemble signatures so this guard does not match its own implementation.
  final forbidden = <String, RegExp>{
    'backend SDK or URL dependency': RegExp('sup' + 'abase', caseSensitive: false),
    'hosted cache dependency': RegExp('up' + 'stash', caseSensitive: false),
    'external in-memory datastore dependency': RegExp('re' + 'dis', caseSensitive: false),
  };
  final failures = <String>[];

  for (final rootPath in roots) {
    final root = Directory(rootPath);
    if (!root.existsSync()) continue;
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final dot = entity.path.lastIndexOf('.');
      if (dot < 0) continue;
      final extension = entity.path.substring(dot).toLowerCase();
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
  stdout.writeln('Dependency boundary clean: no prohibited backend/cache/datastore references in Flutter source, platform configuration, tooling or direct dependencies.');
}
