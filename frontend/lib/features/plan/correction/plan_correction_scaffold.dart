import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../../models/experiment_plan.dart';
import '../experiment_plan_view.dart';
import 'editable_plan_view.dart';
import 'plan_correction_controller.dart';
import 'widgets/correction_action_bar.dart';

class PlanCorrectionScaffold extends StatefulWidget {
  const PlanCorrectionScaffold({
    super.key,
    required this.plan,
    required this.onSavePlan,
    this.query,
  });

  final ExperimentPlan plan;
  final ValueChanged<ExperimentPlan> onSavePlan;
  final String? query;

  @override
  State<PlanCorrectionScaffold> createState() => _PlanCorrectionScaffoldState();
}

class _PlanCorrectionScaffoldState extends State<PlanCorrectionScaffold> {
  bool _isCorrecting = false;

  void _enterCorrectionMode() {
    setState(() => _isCorrecting = true);
  }

  void _exitCorrectionMode() {
    setState(() => _isCorrecting = false);
  }

  void _handleSave(ExperimentPlan corrected) {
    widget.onSavePlan(corrected);
    _exitCorrectionMode();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCorrecting) {
      return _CorrectionModeBody(
        source: widget.plan,
        query: widget.query,
        onSavePlan: _handleSave,
        onCancel: _exitCorrectionMode,
      );
    }
    return _ReadOnlyPlanBody(
      plan: widget.plan,
      query: widget.query,
      onEdit: _enterCorrectionMode,
    );
  }
}

class _ReadOnlyPlanBody extends StatelessWidget {
  const _ReadOnlyPlanBody({
    required this.plan,
    required this.query,
    required this.onEdit,
  });

  final ExperimentPlan plan;
  final String? query;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ExperimentPlanView(plan: plan, query: query),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: CorrectionEnterButton(onPressed: onEdit),
        ),
      ],
    );
  }
}

class _CorrectionModeBody extends StatelessWidget {
  const _CorrectionModeBody({
    required this.source,
    required this.query,
    required this.onSavePlan,
    required this.onCancel,
  });

  final ExperimentPlan source;
  final String? query;
  final ValueChanged<ExperimentPlan> onSavePlan;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PlanCorrectionController>(
      create: (_) => PlanCorrectionController(
        source: source,
        onSave: onSavePlan,
      ),
      builder: (BuildContext context, _) {
        final PlanCorrectionController controller =
            context.read<PlanCorrectionController>();
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: EditablePlanView(query: query),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: CorrectionActionBar(
                onSave: controller.save,
                onCancel: onCancel,
              ),
            ),
          ],
        );
      },
    );
  }
}
