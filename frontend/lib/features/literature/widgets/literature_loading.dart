import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';

class LiteratureLoading extends StatelessWidget {
  const LiteratureLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: kSpaceS),
      itemBuilder: (BuildContext context, int index) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(kSpaceM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(height: 14, width: 260, color: Colors.black12),
                const SizedBox(height: kSpaceS),
                Container(height: 12, width: 180, color: Colors.black12),
                const SizedBox(height: kSpaceS),
                Container(height: 12, width: double.infinity, color: Colors.black12),
                const SizedBox(height: kSpaceXs),
                Container(height: 12, width: 320, color: Colors.black12),
              ],
            ),
          ),
        );
      },
    );
  }
}
