# Mull performance baseline (main, before)

## Method
- Device: emulator `Pixel_9_Pro` (emulator-5554), API 36, arm64, 2 GB, 4 cores, software GPU. Another emulator (emulator-5580, KuberPromo) was running and was not touched.
- Build: PROFILE for the integration harness, RELEASE for cold start. Worktree: `.../scratchpad/mull-baseline` (main, uncommitted harness).
- Data: full dictionary; user shelf "Perf shelf" with 2,000 learning-set keys (first 2,000 by word_key of `quizCandidates()`), 200 recent searches (distinct queries and timestamps), seeded through UserRepository before MullApp is pumped. Onboarding skipped (`app.onboarded`).
- Raster times on this emulator are software-rendered (35-55 ms average) and are NOT meaningful in absolute terms; compare only branch vs branch. Build times and counts are meaningful. Run-to-run noise is large (e.g. worst build 25 vs 39 ms for the same action), so compare medians and treat <30% differences as noise.
- Emulator /data was 97% full; I lowered the global settings `sys_storage_threshold_*` on the emulator so installs work (not reverted).

## Numbers (profile, final run; first run in parentheses where it differed a lot)
| Metric | Value |
|---|---|
| a. Mull tab, tap to first WordCard (3 runs) | 98, 17, 29 ms; median 29 (earlier run: 156, 74, 49) |
| b. Shelves, tap to first shelf card (3 runs, 1st is first open) | 50, 22, 33 ms; median 33 |
| b. Shelves worst frame build (runs 1/2/3) | 37.3 / 17.7 / 7.2 ms |
| c. Perf shelf scroll (12 flings), build avg / p90 / p99 / worst | 1.7 / 2.5 / 5.7 / 19.4 ms (earlier: 1.2 / 2.0 / 3.9 / 4.0) |
| c. raster avg / p90 / p99 | 41.1 / 49.8 / 58.9 ms (software GPU) |
| c. missed build budget / frames | 1 / 82 |
| c. open /collection/{slug} to first card | 378 ms (earlier 415) |
| d. Word sheet open+close x5, build avg / p90 / p99 / worst | 1.5 / 3.5 / 10.3 / 13.9 ms |
| d. raster avg / p90 / p99 | 51.1 / 65.9 / 81.3 ms; missed 0; 121 frames |
| e. Search first query ("pro", after open) | 10.8 ms (earlier 2.5) |
| e. Search 200 queries p50 / p95 / max | 3.6 / 18.4 / 33.5 ms (earlier 3.0 / 14.8 / 19.1) |
| f. AppHeader builds, Home 12 flings | 2 |
| f. AppHeader builds, Perf shelf 12 flings | 2 |
| g. TOTAL PSS (profile build, end of workload) | ~310 MB steady (peak sample 474 MB at teardown; earlier run 298-305 MB) |
| 6. Worst frame build: Home / Search / More open | 6.3 / 11.7 / 36.5 ms (earlier 7.0 / 10.5 / 56.7) |
| 6. Worst frame build: Mull open (3) | 39.4 / 5.7 / 3.4 ms |
| First install of dictionary (ensureInstalled, already installed) | 724 ms |
| Release cold start `am start -W` TotalTime (7) | median 1032, min 878, max 1328 ms |
| Release cold start WaitTime (7) | median 1039, min 880, max 1344 ms |
| Release APK size | 61,427,866 bytes |
| Release PSS 10 s after last cold start | 85.5 MB |

Per-action timeline summaries: `build/perf/*.timeline_summary.json`; custom numbers `build/perf/results.json`.

## Notes
- Header builds: AppHeader only rebuilds when `collapsed` flips, so the baseline is already 2 per 12 flings.
- Shelves "first open" is only truly cold for run 1; the shell keeps the branch alive.
- `flutter drive` has no `--target-platform`; build the APK with it first and pass `--use-application-binary`. `--no-dds` is required or traceAction cannot connect to the VM service. The APK embeds the test, so REBUILD after editing perf_test.dart.

## Rerun
```
export PATH=$PATH:~/Library/Android/sdk/platform-tools
cd <worktree-or-branch>   # needs integration_test + flutter_driver dev deps, AppHeader.debugBuildCount
flutter build apk --profile --target-platform android-arm64 --target=integration_test/perf_test.dart
(while true; do adb -s emulator-5554 shell dumpsys meminfo com.grs.dictionary | grep "TOTAL PSS" | head -1 >> build/perf/mem_samples.txt; sleep 4; done) &
flutter drive --no-dds --profile --use-application-binary=build/app/outputs/flutter-apk/app-profile.apk \
  --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart -d emulator-5554
# cold start
flutter build apk --release --target-platform android-arm64
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -W -n com.grs.dictionary/.MainActivity   # once, wait 25 s
for i in 1 2 3 4 5 6 7; do adb shell am force-stop com.grs.dictionary; sleep 2; adb shell am start -W -n com.grs.dictionary/.MainActivity | grep -E "TotalTime|WaitTime"; sleep 1; done
```
