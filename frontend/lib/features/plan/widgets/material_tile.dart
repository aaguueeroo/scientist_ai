import 'package:flutter/material.dart' hide Material, Step;

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/experiment_plan.dart';
import '../../../ui/app_surface.dart';

/// Layout mode for the materials list based on available width.
enum PlanMaterialsDensity {
  /// All columns: name, catalog, amount, unit price, line total.
  full,

  /// Name (with catalog under), quantity, line total.
  compact,

  /// Stacked card: one column, details and totals wrap naturally.
  stacked,
}

PlanMaterialsDensity planMaterialsDensityForWidth(double width) {
  if (width >= kPlanMaterialsLayoutFullMinWidth) {
    return PlanMaterialsDensity.full;
  }
  if (width >= kPlanMaterialsLayoutCompactMinWidth) {
    return PlanMaterialsDensity.compact;
  }
  return PlanMaterialsDensity.stacked;
}

/// Materials table that picks [PlanMaterialsDensity] from the surrounding width.
class PlanMaterialsList extends StatelessWidget {
  const PlanMaterialsList({
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
              ...List<Widget>.generate(materials.length, (int index) {
                return MaterialTile(
                  material: materials[index],
                  density: density,
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class MaterialTableHeader extends StatelessWidget {
  const MaterialTableHeader({
    super.key,
    this.density = PlanMaterialsDensity.full,
  });

  final PlanMaterialsDensity density;

  @override
  Widget build(BuildContext context) {
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelSmall;
    if (density == PlanMaterialsDensity.compact) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpace16,
          vertical: kSpace12,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 4,
              child: Text('ITEM', style: labelStyle),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'QTY',
                style: labelStyle,
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'TOTAL',
                style: labelStyle,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace16,
        vertical: kSpace12,
      ),
      child: Row(
        children: <Widget>[
          Expanded(flex: 5, child: Text('NAME', style: labelStyle)),
          Expanded(
            flex: 3,
            child: Text('CATALOG', style: labelStyle),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'AMOUNT',
              style: labelStyle,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'PRICE',
              style: labelStyle,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'TOTAL',
              style: labelStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class MaterialTile extends StatelessWidget {
  const MaterialTile({
    super.key,
    required this.material,
    this.density = PlanMaterialsDensity.full,
  });

  final Material material;
  final PlanMaterialsDensity density;

  @override
  Widget build(BuildContext context) {
    if (density == PlanMaterialsDensity.stacked) {
      return _MaterialTileStacked(material: material);
    }
    if (density == PlanMaterialsDensity.compact) {
      return _MaterialTileCompact(material: material);
    }
    return _MaterialTileFull(material: material);
  }
}

class _MaterialTileFull extends StatelessWidget {
  const _MaterialTileFull({required this.material});

  final Material material;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double lineTotal = material.amount * material.price;
    final TextStyle numericStyle = context.scientist.numericBody;
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
                Text(material.title, style: textTheme.titleMedium),
                if (material.description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: kSpace4),
                  Text(
                    material.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              material.catalogNumber,
              style: context.scientist.bodyTertiaryMonospace,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              material.amount.toString(),
              textAlign: TextAlign.right,
              style: numericStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '\$${material.price.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: numericStyle.copyWith(
                color: context.appColorScheme.onSurfaceVariant,
              ),
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

class _MaterialTileCompact extends StatelessWidget {
  const _MaterialTileCompact({required this.material});

  final Material material;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double lineTotal = material.amount * material.price;
    final TextStyle numericStyle = context.scientist.numericBody;
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
                Text(material.title, style: textTheme.titleMedium),
                if (material.description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: kSpace4),
                  Text(
                    material.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
                if (material.catalogNumber.isNotEmpty) ...<Widget>[
                  const SizedBox(height: kSpace4),
                  Text(
                    material.catalogNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.scientist.bodyTertiaryMonospace
                        .copyWith(fontSize: 13),
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
            child: Text(
              material.amount.toString(),
              textAlign: TextAlign.right,
              style: numericStyle,
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

class _MaterialTileStacked extends StatelessWidget {
  const _MaterialTileStacked({required this.material});

  final Material material;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double lineTotal = material.amount * material.price;
    final TextStyle numericStyle = context.scientist.numericBody;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace16,
        vertical: kSpace12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(material.title, style: textTheme.titleMedium),
          if (material.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: kSpace4),
            Text(
              material.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
          ],
          if (material.catalogNumber.isNotEmpty) ...<Widget>[
            const SizedBox(height: kSpace4),
            Text(
              material.catalogNumber,
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
                  style: context.scientist.numericBody.copyWith(
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
