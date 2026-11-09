import 'dart:io';

void main() {
  final roots = <Directory>[Directory('lib'), Directory('test')];
  final forbidden = <String, RegExp>{
    'Supabase SDK, URL, key or REST dependency': RegExp(r'supabase', caseSensitive: false),
    'Upstash dependency': RegExp(r'upstash', caseSensitive: false),
    'Redis dependency': RegExp(r'redis', caseSensitive: false),
  };
  final failures = <String>[];

  for (final root in roots) {
    if (!root.existsSync()) continue;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File) continue;
      final source = entity.readAsStringSync();
      for (final entry in forbidden.entries) {
        if (entry.value.hasMatch(source)) {
          failures.add('${entity.path}: found forbidden ${entry.key}');
        }
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
  stdout.writeln('Dependency boundary clean: no Supabase, Upstash or Redis references in Flutter source or direct dependencies.');
}
