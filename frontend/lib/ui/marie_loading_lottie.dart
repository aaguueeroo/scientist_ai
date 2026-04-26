import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../core/app_constants.dart';

/// Asset used by [MarieLoadingLottie] (literature + experiment plan). Swap the file and/or this path in one place.
const String kMarieLoadingLottieAsset = 'lib/assets/animations/Science.json';

const double kMarieLoadingLottieSize = 240;

class MarieLoadingLottie extends StatelessWidget {
  const MarieLoadingLottie({
    super.key,
    this.size,
  });

  final double? size;

  @override
  Widget build(BuildContext context) {
    final double boxSize = size ?? kMarieLoadingLottieSize;
    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Lottie.asset(
        kMarieLoadingLottieAsset,
        fit: BoxFit.contain,
        repeat: true,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          // ignore: avoid_print
          print('Marie loading Lottie: $error');
          return const _MarieLoadingLottieFallback();
        },
      ),
    );
  }
}

class _MarieLoadingLottieFallback extends StatelessWidget {
  const _MarieLoadingLottieFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: kSpace32 * 2,
        height: kSpace32 * 2,
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
