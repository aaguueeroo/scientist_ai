import 'package:flutter/material.dart';
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
  final FocusNode _focusNode = FocusNode();

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
    final bool isQueryEmpty = _queryController.text.trim().isEmpty;
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
                                onChanged: (_) => setState(() {}),
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
                              const SizedBox(height: kSpace16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 150),
                                  opacity: isQueryEmpty ? 0.6 : 1,
                                  child: FilledButton.icon(
                                    onPressed: isQueryEmpty
                                        ? null
                                        : () async {
                                            await controller.submitQuestion(
                                              _queryController.text,
                                            );
                                            if (!context.mounted) {
                                              return;
                                            }
                                            context.go(kRouteLiterature);
                                          },
                                    icon: const Icon(
                                      Icons.arrow_forward,
                                      size: 16,
                                    ),
                                    label: const Text('Ask Marie'),
                                  ),
                                ),
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
