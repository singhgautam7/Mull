import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Writes build/perf/KEY.timeline_summary.json for every traced action and
/// build/perf/results.json for the custom numbers.
Future<void> main() async {
  await integrationDriver(
    responseDataCallback: (Map<String, dynamic>? data) async {
      if (data == null) return;
      Directory('build/perf').createSync(recursive: true);
      for (final MapEntry<String, dynamic> e in data.entries) {
        if (e.key == 'results') {
          File('build/perf/results.json').writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(e.value),
          );
        } else if (e.value is Map<String, dynamic> &&
            (e.value as Map<String, dynamic>).containsKey('traceEvents')) {
          final driver.TimelineSummary s = driver.TimelineSummary.summarize(
            driver.Timeline.fromJson(e.value as Map<String, dynamic>),
          );
          await s.writeTimelineToFile(e.key, destinationDirectory: 'build/perf', pretty: true);
        }
      }
    },
  );
}
