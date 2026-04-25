import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/scientist_controller.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isQueryEmpty = _queryController.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.all(kSpaceXl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(kSpaceL),
              child: Consumer<ScientistController>(
                builder: (
                  BuildContext context,
                  ScientistController controller,
                  Widget? child,
                ) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'What do you want to investigate?',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: kSpaceM),
                      TextField(
                        controller: _queryController,
                        minLines: 6,
                        maxLines: 10,
                        onChanged: (_) {
                          setState(() {});
                        },
                        decoration: const InputDecoration(
                          hintText:
                              'Describe your research question, hypothesis, or '
                              'experimental objective...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: kSpaceM),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: isQueryEmpty
                              ? null
                              : () async {
                                  await controller.submitQuestion(
                                    _queryController.text,
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  Navigator.pushNamed(
                                    context,
                                    kRouteLiterature,
                                  );
                                },
                          child: const Text('Submit'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
