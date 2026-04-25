import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../ui/app_surface.dart';
import '../../../ui/skeleton_bar.dart';

class LiteratureLoading extends StatelessWidget {
  const LiteratureLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : kSpace12),
          child: AppSurface(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SkeletonBar(height: 32, width: 32, radius: 6),
                const SizedBox(width: kSpace16),
                Expanded(
                  child: SkeletonBlock(
                    children: const <Widget>[
                      SkeletonBar(height: 14, width: 280),
                      SkeletonBar(height: 12, width: 180),
                      SkeletonBar(height: 12),
                      SkeletonBar(height: 12, width: 320),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
