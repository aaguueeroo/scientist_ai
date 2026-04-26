import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/scientist_controller.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../core/theme/theme_context.dart';
import '../plan/widgets/workspace_step_header.dart';

const List<String> _kQuerySuggestions = <String>[
  'Does cold exposure improve insulin sensitivity in metabolically healthy adults?',
  'How does chronic sleep restriction affect memory consolidation in young adults?',
  'Summarize recent findings on exerkines and cardiovascular disease outcomes.',
];

const double _kHomePromptComposerShadowBlur = 12;
const double _kHomePromptComposerShadowBlurFocused = 20;
const double _kHomePromptComposerShadowOffsetY = 2;
const double _kHomePromptComposerShadowAlpha = 0.45;
const double _kHomePromptComposerGlowAlpha = 0.14;
const double _kHomePromptComposerBorderWidth = 1;
const double _kHomePromptComposerBorderWidthFocused = 2;
const double _kHomePromptComposerBorderAlpha = 0.38;
const double _kHomePromptComposerDividerAlpha = 0.22;
const double _kHomePromptComposerSurfaceTintAlpha = 0.05;
const double _kHomePromptComposerHintAlpha = 0.72;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _queryController = TextEditingController();
  late final FocusNode _focusNode;

  void _onPromptFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey != LogicalKeyboardKey.enter) {
          return KeyEventResult.ignored;
        }
        if (HardwareKeyboard.instance.isShiftPressed) {
          return KeyEventResult.ignored;
        }
        final String q = _queryController.text.trim();
        if (q.isEmpty) {
          return KeyEventResult.handled;
        }
        _submitPlan();
        return KeyEventResult.handled;
      },
    );
    _focusNode.addListener(_onPromptFocusChanged);
  }

  Future<void> _submitPlan() async {
    if (!mounted) {
      return;
    }
    final ScientistController controller = context.read<ScientistController>();
    await controller.submitQuestion(_queryController.text);
    if (!mounted) {
      return;
    }
    context.go(kRouteLiterature);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onPromptFocusChanged);
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _applySuggestion(String text) {
    setState(() {
      _queryController.text = text;
      _queryController.selection = TextSelection.collapsed(offset: text.length);
    });
    _submitPlan();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace40,
        vertical: kSpace32,
      ),
      child: Consumer<ScientistController>(
        builder:
            (
              BuildContext context,
              ScientistController controller,
              Widget? child,
            ) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  WorkspaceStepHeader(
                    stepIndex: 0,
                    stepLabels: kWorkspaceStepLabels,
                    stepEnabled: workspaceStepEnabled(
                      currentQuery: controller.currentQuery,
                      isLoadingPlan: controller.isLoadingPlan,
                      experimentPlan: controller.experimentPlan,
                      planError: controller.planError,
                      planFetchQc: controller.planFetchQc,
                    ),
                    onSelect: (int i) => navigateToWorkspaceStep(context, i),
                  ),
                  const SizedBox(height: kSpace32),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: kHomeMaxWidth,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 380,
                                  ),
                                  child: Image.asset(
                                    'lib/assets/marie-query-home.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Text(
                                'Hi! What are we investigating today?',
                                style: textTheme.headlineMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: kSpace8),
                              Text(
                                'Tell me your research question — I\'ll review the literature and draft an experiment plan for you.',
                                style: context.scientist.bodySecondary,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: kSpace32),
                              Text(
                                'Research question',
                                style: textTheme.labelMedium?.copyWith(
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: kSpace8),
                              _HomePromptComposer(
                                controller: _queryController,
                                focusNode: _focusNode,
                                isFocused: _focusNode.hasFocus,
                                textTheme: textTheme,
                                colorScheme: Theme.of(context).colorScheme,
                              ),
                              const SizedBox(height: kSpace12),
                              Text(
                                'Not sure where to start? Try one of these',
                                style: textTheme.labelSmall,
                              ),
                              const SizedBox(height: kSpace8),
                              Wrap(
                                spacing: kSpace8,
                                runSpacing: kSpace8,
                                children: <Widget>[
                                  for (final String suggestion
                                      in _kQuerySuggestions)
                                    ActionChip(
                                      label: Text(
                                        suggestion,
                                        style: textTheme.bodyMedium,
                                      ),
                                      onPressed: () =>
                                          _applySuggestion(suggestion),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
      ),
    );
  }
}

class _HomePromptComposer extends StatelessWidget {
  const _HomePromptComposer({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.textTheme,
    required this.colorScheme,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(kRadius);
    final Color borderColor = isFocused
        ? AppColors.accent
        : AppColors.border.withValues(alpha: _kHomePromptComposerBorderAlpha);
    final double borderWidth = isFocused
        ? _kHomePromptComposerBorderWidthFocused
        : _kHomePromptComposerBorderWidth;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppColors.accent.withValues(
            alpha: _kHomePromptComposerSurfaceTintAlpha,
          ),
          colorScheme.surface,
        ),
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (isFocused ? AppColors.accent : Colors.black).withValues(
              alpha: isFocused
                  ? _kHomePromptComposerGlowAlpha
                  : _kHomePromptComposerShadowAlpha,
            ),
            blurRadius: isFocused
                ? _kHomePromptComposerShadowBlurFocused
                : _kHomePromptComposerShadowBlur,
            offset: const Offset(0, _kHomePromptComposerShadowOffsetY),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 3,
              maxLines: 6,
              cursorColor: AppColors.accent,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
                height: 1.45,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.transparent,
                hintText:
                    'e.g. Does intermittent fasting improve markers of mitochondrial biogenesis in sedentary adults?',
                hintStyle: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(
                    alpha: _kHomePromptComposerHintAlpha,
                  ),
                  height: 1.45,
                ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(
                  kSpace24,
                  kSpace16,
                  kSpace24,
                  kSpace12,
                ),
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: kSpace16),
              color: AppColors.border.withValues(
                alpha: _kHomePromptComposerDividerAlpha,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kSpace16,
                vertical: kSpace8,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.keyboard_return,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: kSpace8),
                  Expanded(
                    child: Text(
                      'Enter to continue • Shift+Enter for new line',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
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
