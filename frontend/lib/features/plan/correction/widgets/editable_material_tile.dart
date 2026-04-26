import 'package:flutter/material.dart' hide Material;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/experiment_plan.dart';
import '../../../../ui/app_surface.dart';
import '../../../../ui/plan_source_badges.dart';
import '../../review/models/material_field.dart';
import '../../review/models/removed_draft_slot.dart';
import '../../review/plan_review_controller.dart';
import '../../widgets/material_tile.dart' show MaterialTableHeader, PlanMaterialsDensity, planMaterialsDensityForWidth;
import 'edit_highlight.dart';
import 'inline_editable_text.dart';

class EditablePlanMaterialsList extends StatelessWidget {
  const EditablePlanMaterialsList({
    super.key,
    required this.materials,
    required this.removedSlots,
    required this.onMaterialChanged,
    required this.onMaterialRemoved,
    required this.onAddMaterial,
  });

  final List<Material> materials;
  final List<RemovedMaterialSlot> removedSlots;
  final void Function(int index, Material material) onMaterialChanged;
  final ValueChanged<int> onMaterialRemoved;
  final VoidCallback onAddMaterial;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final PlanMaterialsDensity density =
            planMaterialsDensityForWidth(constraints.maxWidth);
        return AppSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: _buildRows(context, density),
          ),
        );
      },
    );
  }

  List<Widget> _buildRows(BuildContext context, PlanMaterialsDensity density) {
    final Map<String?, List<Material>> tombstonesByAnchor =
        <String?, List<Material>>{};
    for (final RemovedMaterialSlot slot in removedSlots) {
      tombstonesByAnchor
          .putIfAbsent(slot.afterDraftMaterialId, () => <Material>[])
          .add(slot.material);
    }
    final List<Widget> rows = <Widget>[];
    if (density != PlanMaterialsDensity.stacked) {
      rows.add(MaterialTableHeader(density: density));
    }
    for (final Material removed
        in tombstonesByAnchor[null] ?? const <Material>[]) {
      rows.add(_wrapTombstone(removed));
    }
    for (int index = 0; index < materials.length; index++) {
      final Material material = materials[index];
      rows.add(EditableMaterialTile(
        material: material,
        density: density,
        onChanged: (Material next) => onMaterialChanged(index, next),
        onRemove: () => onMaterialRemoved(index),
      ));
      final List<Material> following =
          tombstonesByAnchor[material.id] ?? const <Material>[];
      for (final Material removed in following) {
        rows.add(_wrapTombstone(removed));
      }
    }
    rows.add(AddMaterialTile(onPressed: onAddMaterial));
    return rows;
  }

  Widget _wrapTombstone(Material removed) {
    final String title = removed.title.trim().isEmpty
        ? 'Untitled material'
        : removed.title.trim();
    final String detail = <String>[
      if (removed.description.trim().isNotEmpty) removed.description.trim(),
      if (removed.amount > 0)
        '${removed.amount} × \$${removed.price.toStringAsFixed(2)}',
    ].join('  •  ');
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace12,
        vertical: kSpace4,
      ),
      child: RemovedDraftSlot(
        removedLabel: 'Material',
        title: title,
        detail: detail.isEmpty ? null : detail,
      ),
    );
  }
}

class EditableMaterialTile extends StatefulWidget {
  const EditableMaterialTile({
    super.key,
    required this.material,
    required this.density,
    required this.onChanged,
    required this.onRemove,
  });

  final Material material;
  final PlanMaterialsDensity density;
  final ValueChanged<Material> onChanged;
  final VoidCallback onRemove;

  @override
  State<EditableMaterialTile> createState() => _EditableMaterialTileState();
}

class _EditableMaterialTileState extends State<EditableMaterialTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final bool isInserted =
        controller.isMaterialInsertedInDraft(widget.material.id);
    final Set<MaterialField> changedFields =
        controller.draftChangedMaterialFields(widget.material.id);
    final EditChangeKind kind = isInserted
        ? EditChangeKind.inserted
        : (changedFields.isEmpty
            ? EditChangeKind.unchanged
            : EditChangeKind.edited);
    final Set<MaterialField> highlightFields = isInserted
        ? const <MaterialField>{
            MaterialField.title,
            MaterialField.catalogNumber,
            MaterialField.description,
            MaterialField.amount,
            MaterialField.price,
          }
        : changedFields;
    return EditedContainerHighlight(
      kind: kind,
      padding: kind == EditChangeKind.unchanged
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(
              horizontal: kSpace4,
              vertical: kSpace4,
            ),
      child: MouseRegion(
        onEnter: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _isHovered = true);
            }
          });
        },
        onExit: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _isHovered = false);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _isHovered && kind == EditChangeKind.unchanged
                ? scheme.primaryContainer
                : Colors.transparent,
          ),
          child: Stack(
            children: <Widget>[
              _buildBody(context, highlightFields),
              Positioned(
                top: kSpace8,
                right: kSpace8,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _isHovered ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_isHovered,
                    child: _MaterialDeleteButton(onPressed: widget.onRemove),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Set<MaterialField> changedFields) {
    if (widget.density == PlanMaterialsDensity.stacked) {
      return _EditableMaterialStacked(
        material: widget.material,
        onChanged: widget.onChanged,
        changedFields: changedFields,
      );
    }
    if (widget.density == PlanMaterialsDensity.compact) {
      return _EditableMaterialCompact(
        material: widget.material,
        onChanged: widget.onChanged,
        changedFields: changedFields,
      );
    }
    return _EditableMaterialFull(
      material: widget.material,
      onChanged: widget.onChanged,
      changedFields: changedFields,
    );
  }
}

class _EditableMaterialFull extends StatelessWidget {
  const _EditableMaterialFull({
    required this.material,
    required this.onChanged,
    required this.changedFields,
  });

  final Material material;
  final ValueChanged<Material> onChanged;
  final Set<MaterialField> changedFields;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double lineTotal = material.amount * material.price;
    final TextStyle numericStyle = context.scientist.numericBody;
    final bool isLineTotalChanged =
        changedFields.contains(MaterialField.amount) ||
            changedFields.contains(MaterialField.price);
    return Padding(
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
                InlineEditableText(
                  value: material.title,
                  expandHorizontally: true,
                  style: editedTextStyle(
                    textTheme.titleMedium,
                    isChanged: changedFields.contains(MaterialField.title),
                  ),
                  maxLines: 2,
                  hintText: 'Material name',
                  onLiveChanged: (String text) =>
                      onChanged(material.copyWith(title: text)),
                  onSubmitted: (String text) =>
                      onChanged(material.copyWith(title: text)),
                ),
                const SizedBox(height: kSpace4),
                InlineEditableText(
                  value: material.description,
                  expandHorizontally: true,
                  style: editedTextStyle(
                    textTheme.bodySmall,
                    isChanged:
                        changedFields.contains(MaterialField.description),
                  ),
                  maxLines: null,
                  minLines: 1,
                  hintText: 'Description',
                  placeholderWhenEmpty: 'Add description',
                  onLiveChanged: (String text) =>
                      onChanged(material.copyWith(description: text)),
                  onSubmitted: (String text) =>
                      onChanged(material.copyWith(description: text)),
                ),
                if (material.sourceRefs.isNotEmpty) ...<Widget>[
                  const SizedBox(height: kSpace8),
                  PlanSourceBadges(refs: material.sourceRefs),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: InlineEditableText(
              value: material.catalogNumber,
              expandHorizontally: true,
              style: editedTextStyle(
                context.scientist.bodyTertiaryMonospace,
                isChanged:
                    changedFields.contains(MaterialField.catalogNumber),
              ),
              maxLines: 1,
              hintText: 'Catalog #',
              placeholderWhenEmpty: 'Catalog #',
              onLiveChanged: (String text) =>
                  onChanged(material.copyWith(catalogNumber: text)),
              onSubmitted: (String text) =>
                  onChanged(material.copyWith(catalogNumber: text)),
            ),
          ),
          Expanded(
            flex: 2,
            child: _AmountField(
              material: material,
              onChanged: onChanged,
              style: numericStyle,
              isChanged: changedFields.contains(MaterialField.amount),
            ),
          ),
          Expanded(
            flex: 2,
            child: _PriceField(
              material: material,
              onChanged: onChanged,
              style: numericStyle.copyWith(
                color: context.appColorScheme.onSurfaceVariant,
              ),
              isChanged: changedFields.contains(MaterialField.price),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: kSpace24),
              child: Text(
                '\$${lineTotal.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: editedTextStyle(
                  numericStyle.copyWith(fontWeight: FontWeight.w600),
                  isChanged: isLineTotalChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableMaterialCompact extends StatelessWidget {
  const _EditableMaterialCompact({
    required this.material,
    required this.onChanged,
    required this.changedFields,
  });

  final Material material;
  final ValueChanged<Material> onChanged;
  final Set<MaterialField> changedFields;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double lineTotal = material.amount * material.price;
    final TextStyle numericStyle = context.scientist.numericBody;
    final bool isLineTotalChanged =
        changedFields.contains(MaterialField.amount) ||
            changedFields.contains(MaterialField.price);
    return Padding(
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
                InlineEditableText(
                  value: material.title,
                  expandHorizontally: true,
                  style: editedTextStyle(
                    textTheme.titleMedium,
                    isChanged: changedFields.contains(MaterialField.title),
                  ),
                  maxLines: 2,
                  hintText: 'Material name',
                  onLiveChanged: (String text) =>
                      onChanged(material.copyWith(title: text)),
                  onSubmitted: (String text) =>
                      onChanged(material.copyWith(title: text)),
                ),
                const SizedBox(height: kSpace4),
                InlineEditableText(
                  value: material.description,
                  expandHorizontally: true,
                  style: editedTextStyle(
                    textTheme.bodySmall,
                    isChanged:
                        changedFields.contains(MaterialField.description),
                  ),
                  maxLines: null,
                  minLines: 1,
                  hintText: 'Description',
                  placeholderWhenEmpty: 'Add description',
                  onLiveChanged: (String text) =>
                      onChanged(material.copyWith(description: text)),
                  onSubmitted: (String text) =>
                      onChanged(material.copyWith(description: text)),
                ),
                const SizedBox(height: kSpace4),
                InlineEditableText(
                  value: material.catalogNumber,
                  expandHorizontally: true,
                  style: editedTextStyle(
                    context.scientist.bodyTertiaryMonospace
                        .copyWith(fontSize: 13),
                    isChanged:
                        changedFields.contains(MaterialField.catalogNumber),
                  ),
                  maxLines: 1,
                  hintText: 'Catalog #',
                  placeholderWhenEmpty: 'Catalog #',
                  onLiveChanged: (String text) =>
                      onChanged(material.copyWith(catalogNumber: text)),
                  onSubmitted: (String text) =>
                      onChanged(material.copyWith(catalogNumber: text)),
                ),
                const SizedBox(height: kSpace4),
                Row(
                  children: <Widget>[
                    Text('\$', style: textTheme.labelSmall),
                    Expanded(
                      child: _PriceField(
                        material: material,
                        onChanged: onChanged,
                        style: textTheme.labelSmall ?? numericStyle,
                        align: TextAlign.left,
                        isChanged:
                            changedFields.contains(MaterialField.price),
                      ),
                    ),
                    Text(' each', style: textTheme.labelSmall),
                  ],
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
            child: _AmountField(
              material: material,
              onChanged: onChanged,
              style: numericStyle,
              isChanged: changedFields.contains(MaterialField.amount),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: kSpace24),
              child: Text(
                '\$${lineTotal.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: editedTextStyle(
                  numericStyle.copyWith(fontWeight: FontWeight.w600),
                  isChanged: isLineTotalChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableMaterialStacked extends StatelessWidget {
  const _EditableMaterialStacked({
    required this.material,
    required this.onChanged,
    required this.changedFields,
  });

  final Material material;
  final ValueChanged<Material> onChanged;
  final Set<MaterialField> changedFields;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double lineTotal = material.amount * material.price;
    final TextStyle numericStyle = context.scientist.numericBody;
    final bool isLineTotalChanged =
        changedFields.contains(MaterialField.amount) ||
            changedFields.contains(MaterialField.price);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace16,
        vertical: kSpace12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: kSpace24),
            child: InlineEditableText(
              value: material.title,
              expandHorizontally: true,
              style: editedTextStyle(
                textTheme.titleMedium,
                isChanged: changedFields.contains(MaterialField.title),
              ),
              maxLines: 2,
              hintText: 'Material name',
              onLiveChanged: (String text) =>
                  onChanged(material.copyWith(title: text)),
              onSubmitted: (String text) =>
                  onChanged(material.copyWith(title: text)),
            ),
          ),
          const SizedBox(height: kSpace4),
          InlineEditableText(
            value: material.description,
            expandHorizontally: true,
            style: editedTextStyle(
              textTheme.bodySmall,
              isChanged: changedFields.contains(MaterialField.description),
            ),
            maxLines: null,
            minLines: 1,
            hintText: 'Description',
            placeholderWhenEmpty: 'Add description',
            onLiveChanged: (String text) =>
                onChanged(material.copyWith(description: text)),
            onSubmitted: (String text) =>
                onChanged(material.copyWith(description: text)),
          ),
          const SizedBox(height: kSpace4),
          InlineEditableText(
            value: material.catalogNumber,
            expandHorizontally: true,
            style: editedTextStyle(
              context.scientist.bodyTertiaryMonospace.copyWith(fontSize: 13),
              isChanged: changedFields.contains(MaterialField.catalogNumber),
            ),
            maxLines: 1,
            hintText: 'Catalog #',
            placeholderWhenEmpty: 'Catalog #',
            onLiveChanged: (String text) =>
                onChanged(material.copyWith(catalogNumber: text)),
            onSubmitted: (String text) =>
                onChanged(material.copyWith(catalogNumber: text)),
          ),
          if (material.sourceRefs.isNotEmpty) ...<Widget>[
            const SizedBox(height: kSpace8),
            PlanSourceBadges(refs: material.sourceRefs),
          ],
          const SizedBox(height: kSpace8),
          Row(
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    _AmountField(
                      material: material,
                      onChanged: onChanged,
                      style: numericStyle.copyWith(
                        color: context.appColorScheme.onSurfaceVariant,
                      ),
                      align: TextAlign.left,
                      isChanged:
                          changedFields.contains(MaterialField.amount),
                    ),
                    Text(
                      ' x \$',
                      style: numericStyle.copyWith(
                        color: context.appColorScheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: _PriceField(
                        material: material,
                        onChanged: onChanged,
                        style: numericStyle.copyWith(
                          color: context.appColorScheme.onSurfaceVariant,
                        ),
                        align: TextAlign.left,
                        isChanged:
                            changedFields.contains(MaterialField.price),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${lineTotal.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: editedTextStyle(
                  numericStyle.copyWith(fontWeight: FontWeight.w600),
                  isChanged: isLineTotalChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperInlineField extends StatelessWidget {
  const _StepperInlineField({
    required this.decrementTooltip,
    required this.incrementTooltip,
    required this.canDecrement,
    required this.onDecrement,
    required this.onIncrement,
    required this.child,
  });

  final String decrementTooltip;
  final String incrementTooltip;
  final bool canDecrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    return Row(
      children: <Widget>[
        Tooltip(
          message: decrementTooltip,
          child: IconButton(
            onPressed: canDecrement ? onDecrement : null,
            icon: Icon(
              Icons.remove_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(kSpace4),
              minimumSize: const Size(28, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        Expanded(child: child),
        Tooltip(
          message: incrementTooltip,
          child: IconButton(
            onPressed: onIncrement,
            icon: Icon(
              Icons.add_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(kSpace4),
              minimumSize: const Size(28, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.material,
    required this.onChanged,
    required this.style,
    this.align = TextAlign.right,
    this.isChanged = false,
  });

  final Material material;
  final ValueChanged<Material> onChanged;
  final TextStyle style;
  final TextAlign align;
  final bool isChanged;

  @override
  Widget build(BuildContext context) {
    return _StepperInlineField(
      decrementTooltip: 'Decrease amount',
      incrementTooltip: 'Increase amount',
      canDecrement: material.amount > 0,
      onDecrement: () {
        onChanged(
          material.copyWith(
            amount: material.amount - kMaterialAmountStep,
          ),
        );
      },
      onIncrement: () {
        onChanged(
          material.copyWith(
            amount: material.amount + kMaterialAmountStep,
          ),
        );
      },
      child: InlineEditableText(
        value: material.amount.toString(),
        expandHorizontally: true,
        style: editedTextStyle(style, isChanged: isChanged),
        textAlign: align,
        maxLines: 1,
        hintText: '0',
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        onLiveChanged: (String text) {
          final int? parsed = int.tryParse(text.trim());
          if (parsed != null && parsed >= 0) {
            onChanged(material.copyWith(amount: parsed));
          }
        },
        onSubmitted: (String text) {
          final int? parsed = int.tryParse(text.trim());
          if (parsed != null && parsed >= 0) {
            onChanged(material.copyWith(amount: parsed));
          }
        },
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.material,
    required this.onChanged,
    required this.style,
    this.align = TextAlign.right,
    this.isChanged = false,
  });

  final Material material;
  final ValueChanged<Material> onChanged;
  final TextStyle style;
  final TextAlign align;
  final bool isChanged;

  static double _round2(double v) {
    return double.parse(v.toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    final bool canDecrementPrice = material.price > 0;
    return _StepperInlineField(
      decrementTooltip: 'Decrease price by \$$kMaterialPriceStep',
      incrementTooltip: 'Increase price by \$$kMaterialPriceStep',
      canDecrement: canDecrementPrice,
      onDecrement: () {
        final double next = _round2(
          (material.price - kMaterialPriceStep).clamp(0, double.infinity),
        );
        onChanged(material.copyWith(price: next));
      },
      onIncrement: () {
        onChanged(
          material.copyWith(
            price: _round2(material.price + kMaterialPriceStep),
          ),
        );
      },
      child: InlineEditableText(
        value: material.price.toStringAsFixed(2),
        expandHorizontally: true,
        style: editedTextStyle(style, isChanged: isChanged),
        textAlign: align,
        maxLines: 1,
        hintText: '0.00',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        onLiveChanged: (String text) {
          final double? parsed = double.tryParse(text.trim());
          if (parsed != null && parsed >= 0) {
            onChanged(material.copyWith(price: parsed));
          }
        },
        onSubmitted: (String text) {
          final double? parsed = double.tryParse(text.trim());
          if (parsed != null && parsed >= 0) {
            onChanged(material.copyWith(price: parsed));
          }
        },
      ),
    );
  }
}

class _MaterialDeleteButton extends StatefulWidget {
  const _MaterialDeleteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_MaterialDeleteButton> createState() => _MaterialDeleteButtonState();
}

class _MaterialDeleteButtonState extends State<_MaterialDeleteButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    return Tooltip(
      message: 'Remove material',
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(kSpace4),
            decoration: BoxDecoration(
              color: _isHovered
                  ? scheme.error.withValues(alpha: 0.16)
                  : scheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(kRadius - 2),
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 16,
              color: _isHovered ? scheme.error : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class AddMaterialTile extends StatefulWidget {
  const AddMaterialTile({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<AddMaterialTile> createState() => _AddMaterialTileState();
}

class _AddMaterialTileState extends State<AddMaterialTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelMedium;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace16,
            vertical: kSpace12,
          ),
          decoration: BoxDecoration(
            color:
                _isHovered ? scheme.primaryContainer : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.add,
                size: 16,
                color: _isHovered ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: kSpace8),
              Text(
                'Add material',
                style: labelStyle?.copyWith(
                  color: _isHovered
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
