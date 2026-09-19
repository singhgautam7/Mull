import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/user_db.dart';
import '../../core/database/user_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/progress.dart';
import '../../shared/widgets/states.dart';
import '../dictionary/word_sheet.dart';
import 'quiz_engine.dart';

/// HANDOFF 17 to 19. Opened only from a shelf's overflow; writes quiz history
/// and never the Mull tab's seen state.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({required this.slug, super.key});
  final String slug;

  /// Below this a shelf's overflow shows the quiz entry disabled, with why.
  static const int minimumWords = 10;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  List<QuizQuestion> _questions = const <QuizQuestion>[];
  int _index = 0;
  int _correct = 0;
  int _skipped = 0;
  int? _sessionId;
  String? _chosen;
  bool _revealed = false;
  bool _loading = true;
  DateTime? _startedAt;

  final List<({DictionaryWord word, bool skipped})> _missed =
      <({DictionaryWord word, bool skipped})>[];
  final List<DictionaryWord> _correctWords = <DictionaryWord>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<String> keys =
        ref.read(collectionKeysProvider)[widget.slug] ?? const <String>[];
    final DictionaryDb dictionary = ref.read(dictProvider);
    final Map<String, SeenWord> seenMap =
        ref.read(seenMapProvider).value ?? const <String, SeenWord>{};

    final List<DictionaryWord> words = dictionary.byKeys(keys);
    final List<QuizQuestion> questions = words.length < QuizScreen.minimumWords
        ? const <QuizQuestion>[]
        : QuizEngine(dictionary).build(words, seenKeys: seenMap.keys.toSet());

    final int? session = questions.isEmpty
        ? null
        : await ref
            .read(userRepositoryProvider)
            .beginQuiz(widget.slug, questions.length);

    if (!mounted) return;
    setState(() {
      _questions = questions;
      _sessionId = session;
      _loading = false;
      _startedAt = DateTime.now();
      _index = 0;
      _correct = 0;
      _skipped = 0;
      _chosen = null;
      _missed.clear();
      _correctWords.clear();
    });
  }

  /// HANDOFF 18 in two beats: the tapped option is marked at once, then the
  /// result resolves. The gap is one `instant`, so the tap reads as acknowledged
  /// before the answer is judged.
  Future<void> _choose(String? chosen) async {
    if (_chosen != null) return;
    final QuizQuestion question = _questions[_index];
    final bool isSkip = chosen == null;
    final bool correct = !isSkip && chosen == question.answer.wordKey;

    setState(() {
      _chosen = chosen ?? '';
      _revealed = false;
      if (correct) {
        _correct++;
        _correctWords.add(question.answer);
      } else {
        if (isSkip) _skipped++;
        _missed.add((word: question.answer, skipped: isSkip));
      }
    });
    await Future<void>.delayed(Motion.of(context, Motion.instant));
    if (mounted) setState(() => _revealed = true);

    await ref.read(userRepositoryProvider).answerQuiz(
      _sessionId!,
      wordKey: question.answer.wordKey,
      type: question.type.name,
      correct: correct,
      chosenKey: chosen,
    );
  }

  Future<void> _advance() async {
    if (_index == _questions.length - 1) {
      await ref.read(userRepositoryProvider).finishQuiz(
        _sessionId!,
        correctCount: _correct,
        abandoned: false,
      );
    }
    setState(() {
      _index++;
      _chosen = null;
      _revealed = false;
    });
  }

  _OptionState _optionState(
    DictionaryWord option,
    QuizQuestion question,
    bool answered,
    bool isCorrect,
  ) {
    final bool isAnswer = option.wordKey == question.answer.wordKey;
    final bool isChosen = option.wordKey == _chosen;
    if (!answered) return isChosen ? _OptionState.chosen : _OptionState.idle;
    if (isAnswer) return _OptionState.correct;
    if (isChosen) return _OptionState.wrong;
    return isCorrect ? _OptionState.muted : _OptionState.gone;
  }

  Future<void> _handleClose() async {
    if (_index < _questions.length) {
      final bool? ok = await showAppBottomSheet<bool>(
        context: context,
        title: 'Leave the quiz?',
        description:
            'The answers so far are kept as an unfinished attempt. Nothing is scored.',
        builder: (BuildContext ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppButton(
              label: 'Leave',
              type: AppButtonType.danger,
              fullWidth: true,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: Space.sm),
            AppButton(
              label: 'Keep going',
              type: AppButtonType.outlined,
              fullWidth: true,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      await ref.read(userRepositoryProvider).finishQuiz(
        _sessionId!,
        correctCount: _correct,
        abandoned: true,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final List<Collection> all = ref.watch(collectionsProvider);
    final String shelfTitle =
        all.where((Collection x) => x.slug == widget.slug).firstOrNull?.title ??
            widget.slug;

    if (_loading || _questions.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppHeader(
                title: 'Quiz',
                subtitle: shelfTitle,
                onBack: () => Navigator.of(context).pop(),
              ),
              LoadingHairline(visible: _loading),
              if (!_loading)
                const Expanded(
                  child: EmptyState(
                    title: 'Not enough to quiz on',
                    message:
                        'A quiz needs ${QuizScreen.minimumWords} words with fair wrong answers to draw from. This shelf does not have that yet.',
                  ),
                ),
            ],
          ),
        ),
      );
    }
    if (_index >= _questions.length) {
      final int minutes = _startedAt != null
          ? (DateTime.now().difference(_startedAt!).inMinutes).clamp(1, 999)
          : 1;
      return _QuizResultView(
        shelfTitle: shelfTitle,
        total: _questions.length,
        correct: _correct,
        wrong: _missed.where((m) => !m.skipped).length,
        skipped: _skipped,
        durationMinutes: minutes,
        missed: _missed,
        correctWords: _correctWords,
        onRetake: _load,
      );
    }

    final QuizQuestion question = _questions[_index];
    final bool chosen = _chosen != null;
    final bool answered = chosen && _revealed;
    final bool isCorrect = answered && _chosen == question.answer.wordKey;
    final bool isSkipped = answered && _chosen!.isEmpty;
    final bool isWrong = answered && !isCorrect && !isSkipped;

    final String prompt = switch (question.type) {
      QuizQuestionType.wordToDefinition => 'WHAT DOES IT MEAN',
      QuizQuestionType.definitionToWord => 'WHICH WORD MEANS THIS',
      QuizQuestionType.cloze => 'FILL THE GAP',
    };

    final DictionaryWord? chosenWord = isWrong
        ? question.options.where((DictionaryWord w) => w.wordKey == _chosen).firstOrNull
        : null;

    final double progress = (_index + 1) / _questions.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Top bar with close, progress, and label
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.screen, 0),
              child: Row(
                children: <Widget>[
                  AppIconButton(
                    icon: Icons.close_rounded,
                    semanticLabel: 'Close quiz',
                    onPressed: _handleClose,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${_index + 1} of ${_questions.length} · $shelfTitle',
                          style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                        ),
                        const SizedBox(height: 4),
                        ProgressTrack(fraction: progress),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              // Question change: the outgoing question fades as the incoming
              // one settles up into place. System-caused, so decelerate.
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.containerTransform),
                switchInCurve: Interval(0.3, 1, curve: Motion.curveOf(context, Motion.decelerate)),
                switchOutCurve: Interval(0.6, 1, curve: Motion.curveOf(context, Motion.decelerate)),
                layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[...previous, ?current],
                ),
                transitionBuilder: (Widget child, Animation<double> animation) =>
                    FadeTransition(
                      opacity: animation,
                      child: Motion.reduced(context)
                          ? child
                          : SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.04),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                    ),
                child: ListView(
                key: ValueKey<int>(_index),
                padding: const EdgeInsets.all(Space.screen),
                children: <Widget>[
                  Text(
                    prompt,
                    style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                  ),
                  const SizedBox(height: Space.sm),

                  // Question body
                  if (question.type == QuizQuestionType.cloze)
                    Container(
                      padding: const EdgeInsets.all(Space.lg),
                      decoration: BoxDecoration(
                        color: c.surfaceContainer,
                        borderRadius: Radii.cardR,
                      ),
                      child: Text(
                        question.cloze!,
                        style: MullType.title.copyWith(
                          color: c.onSurface,
                          fontStyle: FontStyle.italic,
                          height: 1.45,
                        ),
                      ),
                    )
                  else if (question.type == QuizQuestionType.wordToDefinition) ...<Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          question.answer.headword,
                          style: MullType.display.copyWith(color: c.onSurface),
                        ),
                        const SizedBox(width: Space.sm),
                        Text(
                          question.answer.pos,
                          style: MullType.note.copyWith(
                            color: c.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ] else ...<Widget>[
                    Text(
                      question.answer.definitionShort,
                      style: MullType.title.copyWith(color: c.onSurface, height: 1.35),
                    ),
                  ],

                  const SizedBox(height: Space.xl),

                  // Options. On a wrong answer the two irrelevant ones fold
                  // away so the chosen and the correct card sit side by side.
                  for (final DictionaryWord option in question.options)
                    _QuizOptionCard(
                      key: ValueKey<String>(option.wordKey),
                      option: option,
                      type: question.type,
                      state: _optionState(option, question, answered, isCorrect),
                      onTap: chosen ? null : () => _choose(option.wordKey),
                    ),

                  // Answer feedback grows in on the reveal's own beat, so the
                  // page never jumps under the finger.
                  AnimatedSize(
                    duration: Motion.of(
                      context,
                      isCorrect ? Motion.fast : Motion.containerTransform,
                    ),
                    curve: Motion.curveOf(context, Motion.decelerate),
                    alignment: Alignment.topCenter,
                    child: !answered
                        ? const SizedBox(width: double.infinity)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const SizedBox(height: Space.sm),
                              if (isCorrect)
                                Text(
                                  'Correct.',
                                  style: MullType.monoLabel.copyWith(color: c.primary),
                                )
                              else if (isSkipped)
                                Text(
                                  'Skipped. The answer was ${question.answer.headword}.',
                                  style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                                )
                              else if (isWrong && chosenWord != null)
                                Text(
                                  '${chosenWord.headword} means ${chosenWord.definitionShort}.',
                                  style: MullType.monoLabel.copyWith(color: c.danger),
                                ),
                              if (!isCorrect) ...<Widget>[
                                const SizedBox(height: Space.md),
                                _AnswerDetailCard(
                                  word: question.answer,
                                  onOpenEntry: () => showWordSheet(
                                    context,
                                    wordKey: question.answer.wordKey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
              ),
            ),

            // Footer: Skip gives way to Next on the reveal.
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.md),
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.fast),
                switchInCurve: Motion.curveOf(context, Motion.decelerate),
                child: answered
                    ? AppButton(
                        key: const ValueKey<String>('next'),
                        label: _index == _questions.length - 1 ? 'See results' : 'Next',
                        fullWidth: true,
                        onPressed: _advance,
                      )
                    : Column(
                        key: const ValueKey<String>('skip'),
                        children: <Widget>[
                          AppButton(
                            label: 'Skip this one',
                            type: AppButtonType.outlined,
                            onPressed: chosen ? null : () => _choose(null),
                          ),
                          if (_index == 0) ...<Widget>[
                            const SizedBox(height: Space.xs),
                            Text(
                              'not knowing should not need a guess',
                              style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What an option card is showing: [chosen] is the beat between the tap and
/// the reveal; [gone] is an irrelevant option folding away after a miss.
enum _OptionState { idle, chosen, correct, wrong, muted, gone }

class _QuizOptionCard extends StatefulWidget {
  const _QuizOptionCard({
    required this.option,
    required this.type,
    required this.state,
    required this.onTap,
    super.key,
  });

  final DictionaryWord option;
  final QuizQuestionType type;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  State<_QuizOptionCard> createState() => _QuizOptionCardState();
}

class _QuizOptionCardState extends State<_QuizOptionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final _OptionState state = widget.state;

    final Color bg = switch (state) {
      _OptionState.correct => c.primaryContainer,
      _ => c.surfaceContainer,
    };
    final Color border = switch (state) {
      _OptionState.chosen || _OptionState.correct => c.primary,
      _OptionState.wrong => c.danger,
      _OptionState.muted || _OptionState.gone => c.divider,
      _OptionState.idle => c.outline,
    };
    final Color fg = switch (state) {
      _OptionState.correct => c.onPrimaryContainer,
      _OptionState.wrong => c.danger,
      _OptionState.muted || _OptionState.gone => c.onSurfaceMuted,
      _ => c.onSurface,
    };
    final IconData? glyph = switch (state) {
      _OptionState.correct => Icons.check_rounded,
      _OptionState.wrong => Icons.close_rounded,
      _ => null,
    };
    final bool emphasised = state == _OptionState.chosen ||
        state == _OptionState.correct ||
        state == _OptionState.wrong;

    // A right answer settles in one `fast` beat; a wrong one takes the
    // longer `containerTransform`, because that is where the learning is.
    final Duration reveal = Motion.of(
      context,
      state == _OptionState.wrong || state == _OptionState.gone
          ? Motion.containerTransform
          : Motion.fast,
    );
    final Curve curve = Motion.curveOf(context, Motion.decelerate);

    final String text = widget.type == QuizQuestionType.wordToDefinition
        ? widget.option.definitionShort
        : widget.option.headword;

    final bool gone = state == _OptionState.gone;
    // A folding option keeps drawing, fading, while its slot closes over it.
    return AnimatedSize(
      duration: reveal,
      curve: curve,
      alignment: Alignment.topCenter,
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: gone ? 0 : 1,
        child: AnimatedOpacity(
          duration: reveal,
          curve: curve,
          opacity: gone ? 0 : 1,
          child: Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: GestureDetector(
                onTap: widget.onTap,
                onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                behavior: HitTestBehavior.opaque,
                // The finger's own feedback: down at once, `instant`, linear.
                child: AnimatedScale(
                  scale: _pressed ? 0.98 : 1,
                  duration: Motion.instant,
                  curve: Curves.linear,
                  child: AnimatedContainer(
                    duration: reveal,
                    curve: curve,
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.lg,
                      vertical: Space.md,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: Radii.cardR,
                      border: Border.all(
                        color: border,
                        width: emphasised ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: reveal,
                            curve: curve,
                            style: MullType.body
                                .copyWith(color: fg)
                                .weight(widget.type != QuizQuestionType.wordToDefinition ? 600 : 400),
                            child: Text(text),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: reveal,
                          switchInCurve: curve,
                          child: glyph == null
                              ? const SizedBox(width: 0, height: 20)
                              : Padding(
                                  key: ValueKey<IconData>(glyph),
                                  padding: const EdgeInsets.only(left: Space.sm),
                                  child: Icon(glyph, color: fg, size: 20),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ),
      ),
    );
  }
}

class _AnswerDetailCard extends ConsumerWidget {
  const _AnswerDetailCard({
    required this.word,
    required this.onOpenEntry,
  });

  final DictionaryWord word;
  final VoidCallback onOpenEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final Set<String> bookmarked = ref.watch(bookmarksProvider).value ?? const <String>{};
    final bool isBookmarked = bookmarked.contains(word.wordKey);

    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: Radii.cardR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                word.headword,
                style: MullType.title.copyWith(color: c.onSurface, fontWeight: FontWeight.w600),
              ),
              if (word.ipa != null) ...<Widget>[
                const SizedBox(width: Space.sm),
                Text(word.ipa!, style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
              ],
              const SizedBox(width: Space.sm),
              Text(
                word.pos,
                style: MullType.note.copyWith(color: c.onSurfaceVariant, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            word.definitionShort,
            style: MullType.body.copyWith(color: c.onSurface),
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: onOpenEntry,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open the entry'),
              ),
              const SizedBox(width: Space.sm),
              TextButton.icon(
                onPressed: () => ref.read(userRepositoryProvider).toggleBookmark(word.wordKey),
                icon: Icon(
                  isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 16,
                ),
                label: Text(isBookmarked ? 'Bookmarked' : 'Bookmark'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuizResultView extends ConsumerStatefulWidget {
  const _QuizResultView({
    required this.shelfTitle,
    required this.total,
    required this.correct,
    required this.wrong,
    required this.skipped,
    required this.durationMinutes,
    required this.missed,
    required this.correctWords,
    required this.onRetake,
  });

  final String shelfTitle;
  final int total;
  final int correct;
  final int wrong;
  final int skipped;
  final int durationMinutes;
  final List<({DictionaryWord word, bool skipped})> missed;
  final List<DictionaryWord> correctWords;
  final VoidCallback onRetake;

  @override
  ConsumerState<_QuizResultView> createState() => _QuizResultViewState();
}

class _QuizResultViewState extends ConsumerState<_QuizResultView> {
  bool _correctExpanded = false;
  bool _saving = false;
  String? _savedSlug;

  static const List<String> _wordsNumbers = <String>[
    'Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
  ];

  String _formatScore(int correct, int total) {
    final String cWord = correct >= 0 && correct < _wordsNumbers.length
        ? _wordsNumbers[correct]
        : '$correct';
    final String tWord = total >= 0 && total < _wordsNumbers.length
        ? _wordsNumbers[total].toLowerCase()
        : '$total';
    return '$cWord of $tWord correct.';
  }

  /// One new shelf per result, so a second tap opens it rather than doubling it.
  Future<void> _saveMissedToShelf() async {
    if (_saving || widget.missed.isEmpty) return;
    final String? saved = _savedSlug;
    if (saved != null) {
      unawaited(context.push(Routes.collection(saved)));
      return;
    }
    setState(() => _saving = true);
    try {
      final UserRepository userRepo = ref.read(userRepositoryProvider);
      final String name = '${widget.shelfTitle} · missed';
      final String slug = await userRepo.createCollection(name);
      await userRepo.addAllToCollection(
        slug,
        widget.missed.map((({DictionaryWord word, bool skipped}) m) => m.word.wordKey),
      );
      if (!mounted) return;
      setState(() => _savedSlug = slug);
      AppSnackbar.info(context, '${plural(widget.missed.length, 'word')} put on $name');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.screen, 0),
              child: Row(
                children: <Widget>[
                  AppIconButton(
                    icon: Icons.close_rounded,
                    semanticLabel: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: Space.sm),
                  Text(
                    widget.shelfTitle,
                    style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Space.screen),
                children: <Widget>[
                  Text(
                    _formatScore(widget.correct, widget.total),
                    style: MullType.display.copyWith(color: c.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.total} questions · ${widget.wrong} wrong · ${widget.skipped} skipped · ${widget.durationMinutes} min',
                    style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                  ),
                  const SizedBox(height: Space.section),

                  // WHAT YOU MISSED
                  if (widget.missed.isNotEmpty) ...<Widget>[
                    Text(
                      'WHAT YOU MISSED',
                      style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'each one opens its entry · all ${widget.missed.length} are now in Words I got wrong',
                      style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                    ),
                    const SizedBox(height: Space.sm),
                    for (final ({DictionaryWord word, bool skipped}) item in widget.missed) ...<Widget>[
                      InkWell(
                        onTap: () => showWordSheet(context, wordKey: item.word.wordKey),
                        borderRadius: Radii.cardR,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                          decoration: BoxDecoration(
                            color: c.surfaceContainer,
                            borderRadius: Radii.cardR,
                            border: Border.all(color: c.outline),
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Text(
                                          item.word.headword,
                                          style: MullType.titleMedium.copyWith(
                                            color: c.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: Space.xs),
                                        Text(
                                          '(${item.word.pos})',
                                          style: MullType.note.copyWith(
                                            color: c.onSurfaceVariant,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                        if (item.skipped) ...<Widget>[
                                          const SizedBox(width: Space.sm),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: c.surfaceContainerHigh,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'skipped',
                                              style: MullType.monoLabel.copyWith(fontSize: 10, color: c.onSurfaceMuted),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.word.definitionShort,
                                      style: MullType.body.copyWith(color: c.onSurfaceVariant),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: c.onSurfaceMuted),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                    ],
                    const SizedBox(height: Space.md),
                  ],

                  // WHAT YOU GOT RIGHT (collapsed by default)
                  if (widget.correctWords.isNotEmpty) ...<Widget>[
                    InkWell(
                      onTap: () => setState(() => _correctExpanded = !_correctExpanded),
                      borderRadius: Radii.cardR,
                      child: Container(
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
                                  'Correct · ${widget.correctWords.length}',
                                  style: MullType.titleMedium.copyWith(color: c.onSurface),
                                ),
                                Icon(
                                  _correctExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                  color: c.onSurfaceVariant,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'tap to read through them',
                              style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                            ),
                            if (_correctExpanded) ...<Widget>[
                              const SizedBox(height: Space.md),
                              for (final DictionaryWord word in widget.correctWords) ...<Widget>[
                                InkWell(
                                  onTap: () => showWordSheet(context, wordKey: word.wordKey),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: <Widget>[
                                        Text(
                                          word.headword,
                                          style: MullType.body.copyWith(color: c.onSurface, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(width: Space.xs),
                                        Text(
                                          '(${word.pos})',
                                          style: MullType.note.copyWith(color: c.onSurfaceMuted, fontStyle: FontStyle.italic),
                                        ),
                                        const SizedBox(width: Space.sm),
                                        Expanded(
                                          child: Text(
                                            word.definitionShort,
                                            style: MullType.body.copyWith(color: c.onSurfaceVariant),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                  ],

                  if (widget.missed.isEmpty)
                    Text(
                      'Nothing to add to a shelf this time.',
                      style: MullType.body.copyWith(color: c.onSurfaceVariant),
                    ),
                ],
              ),
            ),

            // Bottom action buttons
            Padding(
              padding: const EdgeInsets.all(Space.screen),
              child: Column(
                children: <Widget>[
                  if (widget.missed.isNotEmpty)
                    AppButton(
                      label: _savedSlug == null
                          ? 'Put these ${widget.missed.length} on a shelf'
                          : 'Open the new shelf',
                      fullWidth: true,
                      onPressed: _saving ? null : _saveMissedToShelf,
                    ),
                  const SizedBox(height: Space.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: AppButton(
                          label: 'Take it again',
                          type: AppButtonType.outlined,
                          onPressed: widget.onRetake,
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: AppButton(
                          label: 'Back to shelf',
                          type: AppButtonType.secondary,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
