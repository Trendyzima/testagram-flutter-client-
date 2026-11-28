import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production Pages signup probe reaches password validation without identity review', () {
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
    expect(probe, contains('intentionally invalid password'));
    expect(probe, contains('-X POST'));
    expect(probe, contains('INVALID_PASSWORD'));
    expect(probe, contains(r'"$status" != "400"'));
    expect(probe, contains(r'"$code" != "INVALID_PASSWORD"'));
    expect(probe, contains('--data'));
    expect(probe, contains('signup-readiness@example.invalid'));
    expect(probe, contains('"password":"short"'));
  });
}
