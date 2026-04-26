import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/scientist_controller.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../core/theme/theme_context.dart';
import '../plan/widgets/workspace_step_header.dart';

const List<String> _kQuerySuggestions = <String>[
  'Does cold exposure improve insulin sensitivity in metabolically healthy adults?',
  'How does chronic sleep restriction affect memory consolidation in young adults?',
  'Summarize recent findings on exerkines and cardiovascular disease outcomes.',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _queryController = TextEditingController();
  late final FocusNode _focusNode;

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
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _applySuggestion(String text) {
    setState(() {
      _queryController.text = text;
      _queryController.selection = TextSelection.collapsed(offset: text.length);
    });
    _focusNode.requestFocus();
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
        builder: (
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
                    constraints: const BoxConstraints(maxWidth: kHomeMaxWidth),
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
                                'Tell me your hypothesis or research question — I\'ll review the literature and draft an experiment plan for you.',
                                style: context.scientist.bodySecondary,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: kSpace32),
                              TextField(
                                controller: _queryController,
                                focusNode: _focusNode,
                                minLines: 7,
                                maxLines: 12,
                                style: textTheme.bodyLarge,
                                decoration: const InputDecoration(
                                  hintText:
                                      'e.g. Does intermittent fasting improve markers of mitochondrial biogenesis in sedentary adults?',
                                ),
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
