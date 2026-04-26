import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/experiment_plan.dart';
import '../../../../ui/app_surface.dart';
import '../../../../ui/plan_source_badges.dart';
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
    final ColorScheme scheme = context.appColorScheme;
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final Color? changeAccent =
        controller.reviewContainerAccentForMaterial(material.id);
    final Widget body = switch (density) {
      PlanMaterialsDensity.full => _ReviewMaterialFull(material: material),
      PlanMaterialsDensity.compact =>
        _ReviewMaterialCompact(material: material),
      PlanMaterialsDensity.stacked =>
        _ReviewMaterialStacked(material: material),
    };
    if (changeAccent == null) {
      return body;
    }
    return Container(
      decoration: BoxDecoration(
        color: _reviewMaterialRowColor(
          scheme: scheme,
          changeAccent: changeAccent,
        ),
        borderRadius: BorderRadius.circular(kRadius - 2),
      ),
      child: body,
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
                SelectablePlanText(
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
                if (material.sourceRefs.isNotEmpty) ...<Widget>[
                  const SizedBox(height: kSpace8),
                  PlanSourceBadges(refs: material.sourceRefs),
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
            child: _TouchedLineTotal(
              materialId: material.id,
              text: '\$${lineTotal.toStringAsFixed(2)}',
              base: numericStyle,
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
                SelectablePlanText(
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
                _TouchedEachPrice(
                  material: material,
                  style: textTheme.labelSmall ?? const TextStyle(),
                ),
                if (material.sourceRefs.isNotEmpty) ...<Widget>[
                  const SizedBox(height: kSpace8),
                  PlanSourceBadges(refs: material.sourceRefs),
                ],
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
            child: _TouchedLineTotal(
              materialId: material.id,
              text: '\$${lineTotal.toStringAsFixed(2)}',
              base: numericStyle,
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
          SelectablePlanText(
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
          if (material.sourceRefs.isNotEmpty) ...<Widget>[
            const SizedBox(height: kSpace8),
            PlanSourceBadges(refs: material.sourceRefs),
          ],
          const SizedBox(height: kSpace8),
          Row(
            children: <Widget>[
              Expanded(
                child: _TouchedStackedUnitPrice(
                  material: material,
                  base: numericStyle,
                ),
              ),
              _TouchedLineTotal(
                materialId: material.id,
                text: '\$${lineTotal.toStringAsFixed(2)}',
                base: numericStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const double _kReviewMaterialRowChangeAlpha = 0.12;

Color _reviewMaterialRowColor({
  required ColorScheme scheme,
  required Color? changeAccent,
}) {
  final Color base = scheme.surface;
  if (changeAccent == null) {
    return base;
  }
  return Color.alphaBlend(
    changeAccent.withValues(alpha: _kReviewMaterialRowChangeAlpha),
    base,
  );
}

class _TouchedEachPrice extends StatelessWidget {
  const _TouchedEachPrice({
    required this.material,
    required this.style,
  });

  final Material material;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final PlanReviewController c = context.watch<PlanReviewController>();
    final bool isNew = !c.original.budget.materials
        .any((Material m) => m.id == material.id);
    final MaterialFieldTarget priceTarget = MaterialFieldTarget(
      materialId: material.id,
      field: MaterialField.price,
    );
    final String text = '\$${material.price.toStringAsFixed(2)} each';
    final bool touched = isNew || c.effectiveHasFieldEdit(priceTarget);
    if (!touched) {
      return Text(text, style: style);
    }
    final Color? accent = isNew
        ? c.effectiveColorForTarget(
            MaterialFieldTarget(
              materialId: material.id,
              field: MaterialField.title,
            ),
          )
        : c.effectiveColorForTarget(priceTarget);
    return Text(
      text,
      style: style.copyWith(
        fontWeight: FontWeight.w700,
        backgroundColor: accent?.withValues(alpha: 0.2),
      ),
    );
  }
}

class _TouchedStackedUnitPrice extends StatelessWidget {
  const _TouchedStackedUnitPrice({
    required this.material,
    required this.base,
  });

  final Material material;
  final TextStyle base;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final String text =
        '${material.amount} x \$${material.price.toStringAsFixed(2)}';
    final bool isNew = !controller.original.budget.materials
        .any((Material m) => m.id == material.id);
    final MaterialFieldTarget amountTarget = MaterialFieldTarget(
      materialId: material.id,
      field: MaterialField.amount,
    );
    final MaterialFieldTarget priceTarget = MaterialFieldTarget(
      materialId: material.id,
      field: MaterialField.price,
    );
    final bool touched = isNew ||
        controller.effectiveHasFieldEdit(amountTarget) ||
        controller.effectiveHasFieldEdit(priceTarget);
    final TextStyle plain = base.copyWith(
      color: scheme.onSurfaceVariant,
    );
    if (!touched) {
      return Text(text, style: plain);
    }
    final Color? accent = isNew
        ? controller.effectiveColorForTarget(
            MaterialFieldTarget(
              materialId: material.id,
              field: MaterialField.title,
            ),
          )
        : (controller.effectiveColorForTarget(amountTarget) ??
            controller.effectiveColorForTarget(priceTarget));
    return Text(
      text,
      style: plain.copyWith(
        fontWeight: FontWeight.w700,
        backgroundColor: accent?.withValues(alpha: 0.2),
      ),
    );
  }
}

class _TouchedLineTotal extends StatelessWidget {
  const _TouchedLineTotal({
    required this.materialId,
    required this.text,
    required this.base,
  });

  final String materialId;
  final String text;
  final TextStyle base;

  @override
  Widget build(BuildContext context) {
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final bool isNew = !controller.original.budget.materials
        .any((Material m) => m.id == materialId);
    final MaterialFieldTarget amountTarget = MaterialFieldTarget(
      materialId: materialId,
      field: MaterialField.amount,
    );
    final MaterialFieldTarget priceTarget = MaterialFieldTarget(
      materialId: materialId,
      field: MaterialField.price,
    );
    final bool touched = isNew ||
        controller.effectiveHasFieldEdit(amountTarget) ||
        controller.effectiveHasFieldEdit(priceTarget);
    final TextStyle withWeight = base.copyWith(fontWeight: FontWeight.w600);
    if (!touched) {
      return Text(
        text,
        textAlign: TextAlign.right,
        style: withWeight,
      );
    }
    final Color? accent = isNew
        ? controller.effectiveColorForTarget(
            MaterialFieldTarget(
              materialId: materialId,
              field: MaterialField.title,
            ),
          )
        : (controller.effectiveColorForTarget(amountTarget) ??
            controller.effectiveColorForTarget(priceTarget));
    return Text(
      text,
      textAlign: TextAlign.right,
      style: withWeight.copyWith(
        fontWeight: FontWeight.w700,
        backgroundColor: accent?.withValues(alpha: 0.2),
      ),
    );
  }
}
