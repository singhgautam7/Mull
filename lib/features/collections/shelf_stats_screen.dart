import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/user_db.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/progress.dart';
import '../../shared/widgets/states.dart';

class ShelfStatsScreen extends ConsumerStatefulWidget {
  const ShelfStatsScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<ShelfStatsScreen> createState() => _ShelfStatsScreenState();
}

class _ShelfStatsScreenState extends ConsumerState<ShelfStatsScreen> {
  bool _loading = true;
  int _quizzesTaken = 0;
  int _totalQuestions = 0;
  int _totalCorrect = 0;
  List<({DictionaryWord word, int wrongCount, int totalCount})> _missedWords =
      <({DictionaryWord word, int wrongCount, int totalCount})>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userRepo = ref.read(userRepositoryProvider);
    final dict = ref.read(dictProvider);
    final stats = await userRepo.shelfQuizStats(widget.slug);

    final List<({DictionaryWord word, int wrongCount, int totalCount})> missed =
        <({DictionaryWord word, int wrongCount, int totalCount})>[];

    for (final ({String wordKey, int wrongCount, int totalCount}) m in stats.consistentlyMissed) {
      final DictionaryWord? w = dict.byKey(m.wordKey);
      if (w != null) {
        missed.add((word: w, wrongCount: m.wrongCount, totalCount: m.totalCount));
      }
    }

    if (mounted) {
      setState(() {
        _quizzesTaken = stats.quizzesTaken;
        _totalQuestions = stats.totalQuestions;
        _totalCorrect = stats.totalCorrect;
        _missedWords = missed;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final List<String> shelfKeys = ref.watch(collectionKeysProvider)[widget.slug] ?? const <String>[];
    final Map<String, SeenWord> seenMap = ref.watch(seenMapProvider).value ?? const <String, SeenWord>{};
    final int seenCount = shelfKeys.where(seenMap.containsKey).length;

    final String accuracyStr = _totalQuestions > 0
        ? '${((_totalCorrect / _totalQuestions) * 100).round()}%'
        : 'no accuracy yet';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppHeader(
              title: 'Shelf stats',
              onBack: () => Navigator.of(context).pop(),
            ),
            LoadingHairline(visible: _loading),
            Expanded(
              child: _loading
                  ? const SizedBox.shrink()
                  : ListView(
              padding: const EdgeInsets.all(Space.screen),
              children: <Widget>[
                // Three figures in a row
                Container(
                  padding: const EdgeInsets.all(Space.lg),
                  decoration: BoxDecoration(
                    color: c.surfaceContainer,
                    borderRadius: Radii.cardR,
                    border: Border.all(color: c.outline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      _StatColumn(
                        figure: '$seenCount of ${shelfKeys.length}',
                        label: 'SEEN OF TOTAL',
                      ),
                      _StatColumn(
                        figure: '$_quizzesTaken',
                        label: 'QUIZZES TAKEN',
                      ),
                      _StatColumn(
                        figure: accuracyStr,
                        label: 'ACCURACY',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.section),

                if (_quizzesTaken == 0) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(Space.lg),
                    decoration: BoxDecoration(
                      color: c.surfaceContainer,
                      borderRadius: Radii.cardR,
                      border: Border.all(color: c.outline, style: BorderStyle.solid),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'No quizzes on this shelf yet',
                          style: MullType.titleMedium.copyWith(color: c.onSurface, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Once you have taken one, the words that keep going wrong are listed here. There is nothing to show before then, and no reason to take one now.',
                          style: MullType.note.copyWith(color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ] else ...<Widget>[
                  Text(
                    'GOES WRONG MOST',
                    style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'seen at least twice · a word leaves this list once it has been right twice running',
                    style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                  ),
                  const SizedBox(height: Space.md),

                  if (_missedWords.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(Space.lg),
                      decoration: BoxDecoration(
                        color: c.surfaceContainer,
                        borderRadius: Radii.cardR,
                        border: Border.all(color: c.outline),
                      ),
                      child: Text(
                        'No words have gone wrong twice yet.',
                        style: MullType.note.copyWith(color: c.onSurfaceVariant),
                      ),
                    )
                  else ...<Widget>[
                    for (final ({DictionaryWord word, int wrongCount, int totalCount}) item in _missedWords) ...<Widget>[
                      _MissedWordRow(
                        word: item.word,
                        wrongCount: item.wrongCount,
                        totalCount: item.totalCount,
                      ),
                      const SizedBox(height: Space.sm),
                    ],
                    const SizedBox(height: Space.md),
                    AppButton(
                      label: 'Quiz only these ${_missedWords.length}',
                      type: AppButtonType.outlined,
                      fullWidth: true,
                      onPressed: () => context.push(Routes.quiz(widget.slug)),
                    ),
                  ],
                ],
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.figure, required this.label});

  final String figure;
  final String label;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Column(
      children: <Widget>[
        Text(
          figure,
          style: MullType.monoTabular.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: c.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: MullType.monoLabel.copyWith(fontSize: 10, color: c.onSurfaceMuted),
        ),
      ],
    );
  }
}

class _MissedWordRow extends StatelessWidget {
  const _MissedWordRow({
    required this.word,
    required this.wrongCount,
    required this.totalCount,
  });

  final DictionaryWord word;
  final int wrongCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final double fraction = totalCount > 0 ? wrongCount / totalCount : 0.0;
    final bool highDanger = fraction >= 0.5;

    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.cardR,
        border: Border.all(color: c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                word.headword,
                style: MullType.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.onSurface,
                ),
              ),
              Text(
                'wrong $wrongCount of $totalCount',
                style: MullType.monoLabel.copyWith(
                  color: highDanger ? c.danger : c.onSurfaceVariant,
                  fontWeight: highDanger ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            word.definitionShort,
            style: MullType.body.copyWith(color: c.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Space.sm),
          ProgressTrack(fraction: fraction),
        ],
      ),
    );
  }
}
