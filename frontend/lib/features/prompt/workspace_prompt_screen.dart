import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/scientist_controller.dart';
import '../../core/app_constants.dart';
import '../conversation/widgets/blackboard_prompt_view.dart';
import '../plan/widgets/workspace_step_header.dart';

/// Workspace "Prompt" step: blackboard + scrollable question (not the new-question composer).
class WorkspacePromptScreen extends StatelessWidget {
  const WorkspacePromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kSpace40,
        kSpace32,
        kSpace40,
        kSpace40,
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
                child: BlackboardPromptView(query: controller.currentQuery),
              ),
            ],
          );
        },
      ),
    );
  }
}
