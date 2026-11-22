import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Writes build/perf/KEY.timeline_summary.json for every traced action and
/// build/perf/results.json for the custom numbers.
const Set<String> _watched = <String>{
  'MullApp', 'MaterialApp', 'NavShell', 'MullNavPill', 'HomeScreen', 'CollectionsScreen', 'SearchScreen',
  'MoreScreen', 'LingerScreen', 'AppHeader', 'HeaderPage', 'TopicCard', 'BandRow', 'ListRow', 'YourLists',
  'SettingsRow', 'WordCard', 'SectionHeader', 'TwoColumnGrid', 'PillChip', 'ProgressRing', 'ProgressTrack',
  '_ShelfGrid', '_ContinueSection', '_YourShelves', '_WotdSection', '_RecentSection', 'Consumer',
};

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
        } else if (e.key.startsWith('rebuilds_') && e.value is Map<String, dynamic>) {
          // Build events per widget type (debugProfileBuildsEnabled was on).
          final List<dynamic> events = (e.value as Map<String, dynamic>)['traceEvents'] as List<dynamic>;
          final Map<String, int> counts = <String, int>{};
          int total = 0;
          for (final dynamic ev in events) {
            final Map<String, dynamic> m = ev as Map<String, dynamic>;
            if (m['ph'] != 'B' && m['ph'] != 'X') continue;
            final String name = m['name'] as String;
            if (!_watched.contains(name)) continue;
            counts[name] = (counts[name] ?? 0) + 1;
          }
          for (final dynamic ev in events) {
            final Map<String, dynamic> m = ev as Map<String, dynamic>;
            if ((m['ph'] == 'B' || m['ph'] == 'X') && m['cat'] == 'Dart') total++;
          }
          counts['_all_dart_events'] = total;
          File('build/perf/${e.key}.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(counts));
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
