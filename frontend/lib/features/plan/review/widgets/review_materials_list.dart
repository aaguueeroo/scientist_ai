import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/experiment_plan.dart';
import '../../../../ui/app_surface.dart';
import '../../../review/widgets/focus_highlight_container.dart';
import '../../widgets/material_tile.dart' show MaterialTableHeader, PlanMaterialsDensity, planMaterialsDensityForWidth;
import '../models/change_target.dart';
import '../models/material_field.dart';
import '../plan_review_controller.dart';
import 'selectable_plan_text.dart';
import 'suggestion_aware_text.dart';

/// Read-only materials list used by the review body. Reuses the existing
/// header / density logic from the materials feature, but tile content is
/// rerouted through suggestion-aware widgets.
class ReviewMaterialsList extends StatelessWidget {
  const ReviewMaterialsList({
    super.key,
    required this.materials,
  });

  final List<Material> materials;

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final PlanMaterialsDensity density = planMaterialsDensityForWidth(
          constraints.maxWidth,
        );
        return AppSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              if (density != PlanMaterialsDensity.stacked)
                MaterialTableHeader(density: density),
              for (final Material material in materials)
                FocusHighlightContainer(
                  target: MaterialFieldTarget(
                    materialId: material.id,
                    field: MaterialField.title,
                  ),
                  child: _ReviewMaterialTile(
                    material: material,
                    density: density,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewMaterialTile extends StatelessWidget {
  const _ReviewMaterialTile({
    required this.material,
    required this.density,
  });

  final Material material;
  final PlanMaterialsDensity density;

  @override
  Widget build(BuildContext context) {
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final bool isInsertedFromBaseline = !controller.original.budget.materials
        .any((Material m) => m.id == material.id);
    final Color? insertTint = isInsertedFromBaseline
        ? controller.colorForTarget(
            MaterialFieldTarget(
              materialId: material.id,
              field: MaterialField.title,
            ),
          )
        : null;
    return Container(
      decoration: BoxDecoration(
        border: insertTint != null
            ? Border(
                left: BorderSide(color: insertTint, width: 2),
              )
            : null,
      ),
      child: switch (density) {
        PlanMaterialsDensity.full => _ReviewMaterialFull(material: material),
        PlanMaterialsDensity.compact =>
          _ReviewMaterialCompact(material: material),
        PlanMaterialsDensity.stacked =>
          _ReviewMaterialStacked(material: material),
      },
    );
  }
}

class _ReviewMaterialFull extends StatelessWidget {
  const _ReviewMaterialFull({required this.material});

  final Material material;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle numericStyle = context.scientist.numericBody;
    final double lineTotal = material.amount * material.price;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace16,
        vertical: kSpace12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SuggestionAwareText(
                  target: MaterialFieldTarget(
                    materialId: material.id,
                    field: MaterialField.title,
                  ),
                  text: material.title,
                  style: textTheme.titleMedium,
                ),
                if (material.description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: kSpace4),
                  SelectablePlanText(
                    target: MaterialFieldTarget(
                      materialId: material.id,
                      field: MaterialField.description,
                    ),
                    text: material.description,
                    style: textTheme.bodySmall,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: SuggestionAwareText(
              target: MaterialFieldTarget(
                materialId: material.id,
                field: MaterialField.catalogNumber,
              ),
              text: material.catalogNumber,
              style: context.scientist.bodyTertiaryMonospace,
            ),
          ),
          Expanded(
            flex: 2,
            child: SuggestionAwareText(
              target: MaterialFieldTarget(
                materialId: material.id,
                field: MaterialField.amount,
              ),
              text: material.amount.toString(),
              style: numericStyle,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: SuggestionAwareText(
              target: MaterialFieldTarget(
                materialId: material.id,
                field: MaterialField.price,
              ),
              text: '\$${material.price.toStringAsFixed(2)}',
              style: numericStyle.copyWith(
                color: context.appColorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '\$${lineTotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: numericStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewMaterialCompact extends StatelessWidget {
  const _ReviewMaterialCompact({required this.material});

  final Material material;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle numericStyle = context.scientist.numericBody;
    final double lineTotal = material.amount * material.price;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace16,
        vertical: kSpace12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SuggestionAwareText(
                  target: MaterialFieldTarget(
                    materialId: material.id,
                    field: MaterialField.title,
                  ),
                  text: material.title,
                  style: textTheme.titleMedium,
                ),
                if (material.description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: kSpace4),
                  SelectablePlanText(
                    target: MaterialFieldTarget(
                      materialId: material.id,
                      field: MaterialField.description,
                    ),
                    text: material.description,
                    style: textTheme.bodySmall,
                    maxLines: 2,
                  ),
                ],
                if (material.catalogNumber.isNotEmpty) ...<Widget>[
                  const SizedBox(height: kSpace4),
                  SuggestionAwareText(
                    target: MaterialFieldTarget(
                      materialId: material.id,
                      field: MaterialField.catalogNumber,
                    ),
                    text: material.catalogNumber,
                    style: context.scientist.bodyTertiaryMonospace
                        .copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                Text(
                  '\$${material.price.toStringAsFixed(2)} each',
                  style: textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: SuggestionAwareText(
              target: MaterialFieldTarget(
                materialId: material.id,
                field: MaterialField.amount,
              ),
              text: material.amount.toString(),
              style: numericStyle,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '\$${lineTotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: numericStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewMaterialStacked extends StatelessWidget {
  const _ReviewMaterialStacked({required this.material});

  final Material material;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle numericStyle = context.scientist.numericBody;
    final double lineTotal = material.amount * material.price;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace16,
        vertical: kSpace12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SuggestionAwareText(
            target: MaterialFieldTarget(
              materialId: material.id,
              field: MaterialField.title,
            ),
            text: material.title,
            style: textTheme.titleMedium,
          ),
          if (material.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: kSpace4),
            SelectablePlanText(
              target: MaterialFieldTarget(
                materialId: material.id,
                field: MaterialField.description,
              ),
              text: material.description,
              style: textTheme.bodySmall,
              maxLines: 3,
            ),
          ],
          if (material.catalogNumber.isNotEmpty) ...<Widget>[
            const SizedBox(height: kSpace4),
            SuggestionAwareText(
              target: MaterialFieldTarget(
                materialId: material.id,
                field: MaterialField.catalogNumber,
              ),
              text: material.catalogNumber,
              style: context.scientist.bodyTertiaryMonospace
                  .copyWith(fontSize: 13),
            ),
          ],
          const SizedBox(height: kSpace8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${material.amount} x \$${material.price.toStringAsFixed(2)}',
                  style: numericStyle.copyWith(
                    color: context.appColorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '\$${lineTotal.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: numericStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
