import 'package:flutter/material.dart';

class LiteratureEmpty extends StatelessWidget {
  const LiteratureEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.help_outline, size: 54),
          SizedBox(height: 12),
          Text('No prior research found. You may be the first exploring this.'),
        ],
      ),
    );
  }
}
