import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production Pages signup probe is bodyless and requires identity review', () {
    final workflow = File(
      '.github/workflows/deploy-cloudflare-pages-production.yml',
    ).readAsStringSync();
    final start = workflow.indexOf(
      '      - name: Verify live native signup readiness',
    );
    expect(start, greaterThanOrEqualTo(0));
    final end = workflow.indexOf('      - name: Install Flutter', start);
    expect(end, greaterThan(start));

    final probe = workflow.substring(start, end);
    expect(
      workflow,
      contains("github.event_name == 'workflow_dispatch' && inputs.confirm_production_pages_deploy == true"),
    );
    expect(workflow, isNot(contains("github.event_name == 'push' ||")));
    expect(probe, contains('bodyless POST'));
    expect(probe, contains('-X POST'));
    expect(probe, contains('IDENTITY_REVIEW_REQUIRED'));
    expect(probe, contains(r'"$status" != "403"'));
    expect(probe, contains(r'"$code" != "IDENTITY_REVIEW_REQUIRED"'));
    expect(probe, isNot(contains('--data-binary')));
    expect(probe, isNot(contains('INVALID_PASSWORD')));
    expect(probe, isNot(contains('"password"')));
  });
}
