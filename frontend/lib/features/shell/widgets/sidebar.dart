import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/scientist_controller.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_routes.dart';
import 'past_conversation_tile.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(kSpaceM),
        child: Consumer<ScientistController>(
          builder: (
            BuildContext context,
            ScientistController controller,
            Widget? child,
          ) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Scientist AI',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: kSpaceM),
                FilledButton.icon(
                  onPressed: () {
                    controller.reset();
                    Navigator.pushReplacementNamed(context, kRouteHome);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Question'),
                ),
                const SizedBox(height: kSpaceL),
                Text(
                  'Past conversations',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: kSpaceS),
                Expanded(
                  child: ListView.builder(
                    itemCount: controller.pastConversations.length,
                    itemBuilder: (BuildContext context, int index) {
                      return PastConversationTile(
                        title: controller.pastConversations[index],
                      );
                    },
                  ),
                ),
                const SizedBox(height: kSpaceS),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, kRouteCorrections);
                  },
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Correction Store'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
