import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';

const String kBlackboardPromptAsset = 'lib/assets/marie-query-blackboard.png';

/// Marie at the blackboard with the research question on the board (scrollable).
class BlackboardPromptView extends StatelessWidget {
  const BlackboardPromptView({super.key, required this.query});

  final String? query;

  @override
  Widget build(BuildContext context) {
    if (query == null || query!.isEmpty) {
      return Center(
        child: Text(
          'No question recorded for this conversation.',
          style: context.scientist.bodySecondary,
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 560),
        child: Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            Image.asset(
              kBlackboardPromptAsset,
              fit: BoxFit.contain,
            ),
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              bottom: 0,
              child: FractionallySizedBox(
                widthFactor: 0.52,
                heightFactor: 0.40,
                alignment: const Alignment(-0.72, -0.62),
                child: Padding(
                  padding: const EdgeInsets.all(kSpace16),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      scrollbarTheme: const ScrollbarThemeData(
                        thickness: WidgetStatePropertyAll<double>(6),
                        radius: Radius.circular(3),
                        thumbVisibility: WidgetStatePropertyAll<bool>(true),
                        trackVisibility: WidgetStatePropertyAll<bool>(true),
                        thumbColor: WidgetStatePropertyAll<Color>(
                          Color(0xB3EEEEE8),
                        ),
                        trackColor: WidgetStatePropertyAll<Color>(
                          Color(0x33FFFFFF),
                        ),
                        crossAxisMargin: 2,
                        mainAxisMargin: 4,
                      ),
                    ),
                    child: _BlackboardQueryScroll(query: query!),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlackboardQueryScroll extends StatefulWidget {
  const _BlackboardQueryScroll({required this.query});

  final String query;

  @override
  State<_BlackboardQueryScroll> createState() => _BlackboardQueryScrollState();
}

class _BlackboardQueryScrollState extends State<_BlackboardQueryScroll> {
  late final ScrollController _scrollController;

  static const TextStyle _kQueryTextStyle = TextStyle(
    color: Color(0xDDEEEEE8),
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.3,
  );

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
                minWidth: constraints.maxWidth,
              ),
              child: Center(
                child: Text(
                  widget.query,
                  textAlign: TextAlign.center,
                  style: _kQueryTextStyle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
