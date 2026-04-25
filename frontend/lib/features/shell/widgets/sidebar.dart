import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/scientist_controller.dart';
import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/app_routes.dart';
import 'past_conversation_tile.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: context.scientist.sidebarBackground,
      ),
      child: Consumer<ScientistController>(
        builder: (
          BuildContext context,
          ScientistController controller,
          Widget? child,
        ) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  kSpace24,
                  kSpace24,
                  kSpace24,
                  kSpace16,
                ),
                child: Text(
                  'Scientist AI',
                  style: textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSpace16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      controller.reset();
                      Navigator.pushReplacementNamed(context, kRouteHome);
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Question'),
                  ),
                ),
              ),
              const SizedBox(height: kSpace24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSpace24),
                child: Text(
                  'PAST CONVERSATIONS',
                  style: textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: kSpace8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpace8,
                    vertical: kSpace4,
                  ),
                  itemCount: controller.pastConversations.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String title = controller.pastConversations[index];
                    return PastConversationTile(
                      title: title,
                      isActive: controller.currentQuery == title,
                      onTap: () {
                        controller.openPastConversationReplay(title);
                        Navigator.pushNamed(
                          context,
                          kRoutePastConversation,
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  kSpace16,
                  kSpace16,
                  kSpace16,
                  kSpace24,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, kRouteCorrections);
                    },
                    icon: const Icon(Icons.inventory_2_outlined, size: 16),
                    label: const Text('Correction Store'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
