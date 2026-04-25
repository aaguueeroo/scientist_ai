import 'package:flutter/material.dart' hide Material, Step;

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/experiment_plan.dart';

class StepTile extends StatefulWidget {
  const StepTile({
    super.key,
    required this.step,
  });

  final Step step;

  @override
  State<StepTile> createState() => _StepTileState();
}

class _StepTileState extends State<StepTile> {
  bool _isExpanded = false;
  bool _isHovered = false;

  String _formatDuration(Duration value) {
    if (value.inDays > 0 && value.inHours % 24 == 0) {
      return '${value.inDays} days';
    }
    if (value.inDays > 0) {
      return '${value.inDays} d ${value.inHours.remainder(24)} h';
    }
    return '${value.inHours} hours';
  }

  String _shortDescription(String description) {
    final String trimmed = description.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final List<String> sentences = trimmed.split(RegExp(r'(?<=[.!?])\s+'));
    return sentences.first;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    final String shortText = _shortDescription(widget.step.description);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(kSpace16),
          decoration: BoxDecoration(
            color: _isHovered ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(kRadius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _StepNumberBadge(number: widget.step.number),
              const SizedBox(width: kSpace16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(widget.step.name, style: textTheme.titleMedium),
                    if (shortText.isNotEmpty) ...<Widget>[
                      const SizedBox(height: kSpace4),
                      Text(
                        shortText,
                        maxLines: _isExpanded ? null : 2,
                        overflow: _isExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: context.scientist.bodySecondary,
                      ),
                    ],
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      alignment: Alignment.topLeft,
                      child: _isExpanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: kSpace12),
                              child: Text(
                                widget.step.description,
                                style: textTheme.bodyMedium,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: kSpace16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    _formatDuration(widget.step.duration),
                    style: context.scientist.numericBody.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: kSpace4),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 150),
                    turns: _isExpanded ? 0.5 : 0,
                    child: Icon(
                      Icons.expand_more,
                      size: 18,
                      color: context.scientist.onSurfaceFaint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepNumberBadge extends StatelessWidget {
  const _StepNumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(kRadius - 2),
      ),
      child: Text(
        number.toString(),
        style: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
        ),
      ),
    );
  }
}
