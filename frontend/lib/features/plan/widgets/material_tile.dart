import 'package:flutter/material.dart' hide Material;
import 'package:flutter/services.dart';

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

double _materialLineTotal(Material material) {
  final int q = material.qty ?? material.amount;
  final double unit = material.unitCostUsd ?? material.price;
  return q * unit;
}

/// True when materials carry backend-shaped fields (vendor, units, unit cost).
bool planMaterialsUseBackendLayout(List<Material> materials) {
  return materials.any(
    (Material m) =>
        m.vendor != null || m.qtyUnit != null || m.unitCostUsd != null,
  );
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
    final bool be = planMaterialsUseBackendLayout(materials);
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
                MaterialTableHeader(
                  density: density,
                  useBackendLayout: be,
                ),
              ...List<Widget>.generate(materials.length, (int index) {
                return MaterialTile(
                  material: materials[index],
                  density: density,
                  useBackendLayout: be,
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
    this.useBackendLayout = false,
  });

  final PlanMaterialsDensity density;
  final bool useBackendLayout;

  @override
  Widget build(BuildContext context) {
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelSmall;
    if (useBackendLayout && density == PlanMaterialsDensity.full) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpace16,
          vertical: kSpace12,
        ),
        child: Row(
          children: <Widget>[
            Expanded(flex: 4, child: Text('REAGENT', style: labelStyle)),
            Expanded(flex: 2, child: Text('VENDOR', style: labelStyle)),
            Expanded(flex: 2, child: Text('SKU', style: labelStyle)),
            Expanded(
              flex: 2,
              child: Text('QTY', style: labelStyle, textAlign: TextAlign.right),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'UNIT',
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
            Expanded(
              flex: 1,
              child: Text(
                'QC',
                style: labelStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
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
    this.useBackendLayout = false,
  });

  final Material material;
  final PlanMaterialsDensity density;
  final bool useBackendLayout;

  @override
  Widget build(BuildContext context) {
    if (useBackendLayout && density == PlanMaterialsDensity.stacked) {
      return _MaterialTileBackendStacked(material: material);
    }
    if (useBackendLayout && density == PlanMaterialsDensity.compact) {
      return _MaterialTileBackendCompact(material: material);
    }
    if (useBackendLayout && density == PlanMaterialsDensity.full) {
      return _MaterialTileBackendFull(material: material);
    }
    if (density == PlanMaterialsDensity.stacked) {
      return _MaterialTileStacked(material: material);
    }
    if (density == PlanMaterialsDensity.compact) {
      return _MaterialTileCompact(material: material);
    }
    return _MaterialTileFull(material: material);
  }
}

class _VerificationCell extends StatelessWidget {
  const _VerificationCell({required this.material});

  final Material material;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final String? url = material.verificationUrl;
    if (material.verified == true && url != null && url.isNotEmpty) {
      return IconButton(
        tooltip: 'Copy verification link',
        icon: Icon(Icons.verified_outlined, color: scheme.primary, size: 20),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: url));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Verification link copied')),
            );
          }
        },
      );
    }
    if (material.verified == false) {
      return Tooltip(
        message: material.notes ?? 'Not verified',
        child: Icon(
          Icons.help_outline,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _MaterialTileBackendFull extends StatelessWidget {
  const _MaterialTileBackendFull({required this.material});

  final Material material;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle numericStyle = context.scientist.numericBody;
    final int q = material.qty ?? material.amount;
    final String? unit = material.qtyUnit;
    final double unitCost = material.unitCostUsd ?? material.price;
    final double line = _materialLineTotal(material);
    final String vendor = material.vendor ?? '—';
    final String sku = material.sku ?? material.catalogNumber;
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
                if ((material.notes ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: kSpace4),
                  Text(
                    material.notes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              vendor,
              style: textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              sku,
              style: context.scientist.bodyTertiaryMonospace,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              unit != null ? '$q $unit' : '$q',
              textAlign: TextAlign.right,
              style: numericStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '\$${unitCost.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: numericStyle.copyWith(
                color: context.appColorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '\$${line.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: numericStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.topCenter,
              child: _VerificationCell(material: material),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialTileBackendCompact extends StatelessWidget {
  const _MaterialTileBackendCompact({required this.material});

  final Material material;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double line = _materialLineTotal(material);
    final TextStyle numericStyle = context.scientist.numericBody;
    final int q = material.qty ?? material.amount;
    final String? unit = material.qtyUnit;
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
                if ((material.vendor ?? '').isNotEmpty)
                  Text(
                    material.vendor!,
                    style: textTheme.bodySmall,
                  ),
                if ((material.sku ?? material.catalogNumber).isNotEmpty)
                  Text(
                    material.sku ?? material.catalogNumber,
                    style: context.scientist.bodyTertiaryMonospace
                        .copyWith(fontSize: 13),
                  ),
                const SizedBox(height: kSpace4),
                _VerificationCell(material: material),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              unit != null ? '$q $unit' : '$q',
              textAlign: TextAlign.right,
              style: numericStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '\$${line.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: numericStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialTileBackendStacked extends StatelessWidget {
  const _MaterialTileBackendStacked({required this.material});

  final Material material;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double line = _materialLineTotal(material);
    final TextStyle numericStyle = context.scientist.numericBody;
    final int q = material.qty ?? material.amount;
    final String? unit = material.qtyUnit;
    final double unitCost = material.unitCostUsd ?? material.price;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace16,
        vertical: kSpace12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(material.title, style: textTheme.titleMedium),
          if ((material.vendor ?? '').isNotEmpty)
            Text(material.vendor!, style: textTheme.bodySmall),
          if ((material.sku ?? material.catalogNumber).isNotEmpty)
            Text(
              material.sku ?? material.catalogNumber,
              style: context.scientist.bodyTertiaryMonospace
                  .copyWith(fontSize: 13),
            ),
          if ((material.notes ?? '').isNotEmpty)
            Text(
              material.notes!,
              style: textTheme.bodySmall,
            ),
          const SizedBox(height: kSpace8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  unit != null
                      ? '$q $unit × \$${unitCost.toStringAsFixed(2)}'
                      : '$q × \$${unitCost.toStringAsFixed(2)}',
                  style: context.scientist.numericBody.copyWith(
                    color: context.appColorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '\$${line.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: numericStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _VerificationCell(material: material),
          ),
        ],
      ),
    );
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
