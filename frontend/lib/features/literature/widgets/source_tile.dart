import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../models/literature_review.dart';

class SourceTile extends StatelessWidget {
  const SourceTile({
    super.key,
    required this.source,
  });

  final Source source;

  String _formatDate(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(kSpaceM),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.description_outlined),
            ),
            const SizedBox(width: kSpaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    source.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: kSpaceXs),
                  Text('${source.author} • ${_formatDate(source.dateOfPublication)}'),
                  const SizedBox(height: kSpaceS),
                  Text(
                    source.abstractText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: kSpaceS),
                  Text(
                    source.doi,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
