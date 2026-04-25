import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import 'app_surface.dart';

class MetricBlock extends StatelessWidget {
  const MetricBlock({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: textTheme.labelSmall,
        ),
        const SizedBox(height: kSpace8),
        Text(
          value,
          style: textTheme.headlineLarge,
        ),
      ],
    );
  }
}

class MetricGroup extends StatelessWidget {
  const MetricGroup({
    super.key,
    required this.metrics,
  });

  final List<MetricBlock> metrics;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(kSpace24),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isNarrow = constraints.maxWidth < 480;
          if (isNarrow) {
            final List<Widget> stacked = <Widget>[];
            for (int i = 0; i < metrics.length; i++) {
              if (i > 0) {
                stacked.add(const SizedBox(height: kSpace24));
              }
              stacked.add(metrics[i]);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: stacked,
            );
          }
          final List<Widget> row = <Widget>[];
          for (int i = 0; i < metrics.length; i++) {
            if (i > 0) {
              row.add(const SizedBox(width: kSpace40));
            }
            row.add(Expanded(child: metrics[i]));
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: row,
          );
        },
      ),
    );
  }
}
