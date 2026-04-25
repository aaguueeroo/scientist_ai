import 'package:flutter/material.dart' hide Material;
import 'package:flutter/services.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/experiment_plan.dart';
import '../../../../ui/app_surface.dart';
import '../../widgets/material_tile.dart' show MaterialTableHeader, PlanMaterialsDensity, planMaterialsDensityForWidth;
import 'inline_editable_text.dart';

class EditablePlanMaterialsList extends StatelessWidget {
  const EditablePlanMaterialsList({
    super.key,
    required this.materials,
    required this.onMaterialChanged,
    required this.onMaterialRemoved,
    required this.onAddMaterial,
  });

  final List<Material> materials;
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
            children: <Widget>[
              if (density != PlanMaterialsDensity.stacked)
                MaterialTableHeader(density: density),
              ...List<Widget>.generate(materials.length, (int index) {
                return EditableMaterialTile(
                  material: materials[index],
                  density: density,
                  onChanged: (Material next) =>
                      onMaterialChanged(index, next),
                  onRemove: () => onMaterialRemoved(index),
                );
              }),
              AddMaterialTile(onPressed: onAddMaterial),
            ],
          ),
        );
      },
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
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color:
              _isHovered ? scheme.primaryContainer : Colors.transparent,
        ),
        child: Stack(
          children: <Widget>[
            _buildBody(context),
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
    );
  }

  Widget _buildBody(BuildContext context) {
    if (widget.density == PlanMaterialsDensity.stacked) {
      return _EditableMaterialStacked(
        material: widget.material,
        onChanged: widget.onChanged,
      );
    }
    if (widget.density == PlanMaterialsDensity.compact) {
      return _EditableMaterialCompact(
        material: widget.material,
        onChanged: widget.onChanged,
      );
    }
    return _EditableMaterialFull(
      material: widget.material,
      onChanged: widget.onChanged,
    );
  }
}

class _EditableMaterialFull extends StatelessWidget {
  const _EditableMaterialFull({
    required this.material,
    required this.onChanged,
  });

  final Material material;
  final ValueChanged<Material> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double lineTotal = material.amount * material.price;
    final TextStyle numericStyle = context.scientist.numericBody;
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
                  style: textTheme.titleMedium,
                  maxLines: 2,
                  hintText: 'Material name',
                  onSubmitted: (String text) =>
                      onChanged(material.copyWith(title: text)),
                ),
                const SizedBox(height: kSpace4),
                InlineEditableText(
                  value: material.description,
                  expandHorizontally: true,
                  style: textTheme.bodySmall,
                  maxLines: null,
                  minLines: 1,
                  hintText: 'Description',
                  placeholderWhenEmpty: 'Add description',
                  onSubmitted: (String text) =>
                      onChanged(material.copyWith(description: text)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: InlineEditableText(
              value: material.catalogNumber,
              expandHorizontally: true,
              style: context.scientist.bodyTertiaryMonospace,
              maxLines: 1,
              hintText: 'Catalog #',
              placeholderWhenEmpty: 'Catalog #',
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
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: kSpace24),
              child: Text(
                '\$${lineTotal.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: numericStyle.copyWith(fontWeight: FontWeight.w600),
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
  });

  final Material material;
  final ValueChanged<Material> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double lineTotal = material.amount * material.price;
    final TextStyle numericStyle = context.scientist.numericBody;
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
                  style: textTheme.titleMedium,
                  maxLines: 2,
                  hintText: 'Material name',
                  onSubmitted: (String text) =>
                      onChanged(material.copyWith(title: text)),
                ),
                const SizedBox(height: kSpace4),
                InlineEditableText(
                  value: material.description,
                  expandHorizontally: true,
                  style: textTheme.bodySmall,
                  maxLines: null,
                  minLines: 1,
                  hintText: 'Description',
                  placeholderWhenEmpty: 'Add description',
                  onSubmitted: (String text) =>
                      onChanged(material.copyWith(description: text)),
                ),
                const SizedBox(height: kSpace4),
                InlineEditableText(
                  value: material.catalogNumber,
                  expandHorizontally: true,
                  style: context.scientist.bodyTertiaryMonospace
                      .copyWith(fontSize: 13),
                  maxLines: 1,
                  hintText: 'Catalog #',
                  placeholderWhenEmpty: 'Catalog #',
                  onSubmitted: (String text) =>
                      onChanged(material.copyWith(catalogNumber: text)),
                ),
                const SizedBox(height: kSpace4),
                Row(
                  children: <Widget>[
                    Text('\$', style: textTheme.labelSmall),
                    _PriceField(
                      material: material,
                      onChanged: onChanged,
                      style: textTheme.labelSmall ?? numericStyle,
                      align: TextAlign.left,
                    ),
                    Text(' each', style: textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _AmountField(
              material: material,
              onChanged: onChanged,
              style: numericStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: kSpace24),
              child: Text(
                '\$${lineTotal.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: numericStyle.copyWith(fontWeight: FontWeight.w600),
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
  });

  final Material material;
  final ValueChanged<Material> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double lineTotal = material.amount * material.price;
    final TextStyle numericStyle = context.scientist.numericBody;
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
              style: textTheme.titleMedium,
              maxLines: 2,
              hintText: 'Material name',
              onSubmitted: (String text) =>
                  onChanged(material.copyWith(title: text)),
            ),
          ),
          const SizedBox(height: kSpace4),
          InlineEditableText(
            value: material.description,
            expandHorizontally: true,
            style: textTheme.bodySmall,
            maxLines: null,
            minLines: 1,
            hintText: 'Description',
            placeholderWhenEmpty: 'Add description',
            onSubmitted: (String text) =>
                onChanged(material.copyWith(description: text)),
          ),
          const SizedBox(height: kSpace4),
          InlineEditableText(
            value: material.catalogNumber,
            expandHorizontally: true,
            style: context.scientist.bodyTertiaryMonospace
                .copyWith(fontSize: 13),
            maxLines: 1,
            hintText: 'Catalog #',
            placeholderWhenEmpty: 'Catalog #',
            onSubmitted: (String text) =>
                onChanged(material.copyWith(catalogNumber: text)),
          ),
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
                    ),
                    Text(
                      ' x \$',
                      style: numericStyle.copyWith(
                        color: context.appColorScheme.onSurfaceVariant,
                      ),
                    ),
                    _PriceField(
                      material: material,
                      onChanged: onChanged,
                      style: numericStyle.copyWith(
                        color: context.appColorScheme.onSurfaceVariant,
                      ),
                      align: TextAlign.left,
                    ),
                  ],
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

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.material,
    required this.onChanged,
    required this.style,
    this.align = TextAlign.right,
  });

  final Material material;
  final ValueChanged<Material> onChanged;
  final TextStyle style;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return InlineEditableText(
      value: material.amount.toString(),
      expandHorizontally: true,
      style: style,
      textAlign: align,
      maxLines: 1,
      hintText: '0',
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      onSubmitted: (String text) {
        final int? parsed = int.tryParse(text.trim());
        if (parsed != null && parsed >= 0) {
          onChanged(material.copyWith(amount: parsed));
        }
      },
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.material,
    required this.onChanged,
    required this.style,
    this.align = TextAlign.right,
  });

  final Material material;
  final ValueChanged<Material> onChanged;
  final TextStyle style;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return InlineEditableText(
      value: material.price.toStringAsFixed(2),
      expandHorizontally: true,
      style: style,
      textAlign: align,
      maxLines: 1,
      hintText: '0.00',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      onSubmitted: (String text) {
        final double? parsed = double.tryParse(text.trim());
        if (parsed != null && parsed >= 0) {
          onChanged(material.copyWith(price: parsed));
        }
      },
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
