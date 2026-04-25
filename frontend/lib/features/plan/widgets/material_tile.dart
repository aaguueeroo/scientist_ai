import 'package:flutter/material.dart' hide Material, Step;

import '../../../core/app_constants.dart';
import '../../../models/experiment_plan.dart';

class MaterialTile extends StatelessWidget {
  const MaterialTile({
    super.key,
    required this.material,
  });

  final Material material;

  @override
  Widget build(BuildContext context) {
    final double lineTotal = material.amount * material.price;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(kSpaceM),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    material.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: kSpaceXs),
                  Text(
                    material.catalogNumber,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: kSpaceS),
                  Text(material.description),
                  const SizedBox(height: kSpaceS),
                  Text('${material.amount} × \$${material.price.toStringAsFixed(2)}'),
                ],
              ),
            ),
            const SizedBox(width: kSpaceM),
            Text(
              '\$${lineTotal.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
