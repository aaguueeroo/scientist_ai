import 'package:flutter/material.dart' hide Material, Step;

import '../correction/editable_plan_view.dart';

/// Thin wrapper over the existing [EditablePlanView]. The wrapper exists
/// so the scaffold can address an "editing" body symmetrically to the
/// read-only / pending bodies. The inline editing primitives stay in
/// `correction/widgets/` and now read from [PlanReviewController].
class EditableReviewBody extends StatelessWidget {
  const EditableReviewBody({super.key, this.query});

  final String? query;

  @override
  Widget build(BuildContext context) {
    return EditablePlanView(query: query);
  }
}
