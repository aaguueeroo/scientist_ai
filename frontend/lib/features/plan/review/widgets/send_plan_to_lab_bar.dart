import 'package:flutter/material.dart' hide Material, Step;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../controllers/projects_controller.dart';
import '../../../../core/app_constants.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/app_toasts.dart';
import '../../../../core/id_generator.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../data/mock/mock_labs.dart';
import '../../../../features/shell/widgets/user_avatar.dart';
import '../../../../models/experiment_plan.dart';
import '../../../../models/project.dart';
import '../../../../ui/app_surface.dart';
import '../plan_review_controller.dart';

String _projectTitle(String? query, ExperimentPlan plan) {
  final String q = query?.trim() ?? '';
  if (q.isNotEmpty) {
    return q;
  }
  final String d = plan.description.trim();
  if (d.isEmpty) {
    return 'Experiment plan';
  }
  if (d.length <= 72) {
    return d;
  }
  return '${d.substring(0, 69)}…';
}

/// Bottom action to assign the current plan snapshot to a mock lab and add an
/// ongoing project.
class SendPlanToLabBar extends StatelessWidget {
  const SendPlanToLabBar({super.key, required this.query});

  final String? query;

  Future<void> _openLabPickerAndSend(BuildContext context) async {
    final PlanReviewController review = context.read<PlanReviewController>();
    final MockLab? chosen = await showDialog<MockLab>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _LabPickerDialog(labs: buildMockLabs());
      },
    );
    if (!context.mounted || chosen == null) {
      return;
    }
    final ProjectsController projects = context.read<ProjectsController>();
    final DateTime now = DateTime.now();
    final ExperimentPlan snapshot = deepCopyExperimentPlan(review.displayPlan);
    final Project project = Project(
      id: generateLocalId('project'),
      title: _projectTitle(query, snapshot),
      assignedScientistName: chosen.contactScientistName,
      assignedScientistAvatarUrl: chosen.contactScientistAvatarUrl,
      labName: chosen.name,
      startedAt: now,
      lastUpdatedAt: now,
      plan: snapshot,
    );
    projects.addProject(project);
    showAppToast(
      context,
      message:
          'Plan sent to ${chosen.name}. You can track it under Ongoing projects.',
      variant: AppToastVariant.success,
    );
    context.go('$kRoutePlan?projectId=${project.id}');
  }

  @override
  Widget build(BuildContext context) {
    final PlanReviewController review = context.watch<PlanReviewController>();
    final bool canSend = !review.isHistoricalView;
    return Padding(
      padding: const EdgeInsets.only(top: kSpace16),
      child: Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: canSend
              ? () {
                  _openLabPickerAndSend(context);
                }
              : null,
          icon: const Icon(Icons.science_outlined, size: 18),
          label: const Text('Send plan to a lab'),
        ),
      ),
    );
  }
}

class _LabPickerDialog extends StatefulWidget {
  const _LabPickerDialog({required this.labs});

  final List<MockLab> labs;

  @override
  State<_LabPickerDialog> createState() => _LabPickerDialogState();
}

class _LabPickerDialogState extends State<_LabPickerDialog> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double listMaxHeight = (MediaQuery.sizeOf(context).height * 0.42)
        .clamp(200.0, 360.0);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: kSpace24,
        vertical: kSpace32,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: AppSurface(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  kSpace24,
                  kSpace24,
                  kSpace24,
                  kSpace8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(kRadius),
                          ),
                          child: Icon(
                            Icons.science_outlined,
                            color: scheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: kSpace12),
                        Expanded(
                          child: Text(
                            'Assign to a lab',
                            style: textTheme.headlineSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpace12),
                    Text(
                      'The lab will receive this plan to edit and execute. '
                      'The project will show up in Ongoing projects.',
                      style: context.scientist.bodySecondary,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  kSpace16,
                  kSpace8,
                  kSpace16,
                  kSpace8,
                ),
                child: AppSurface(
                  color: scheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpace8,
                    vertical: kSpace8,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: listMaxHeight),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: widget.labs.length,
                      itemBuilder: (BuildContext context, int i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: kSpace8),
                          child: _LabOptionTile(
                            lab: widget.labs[i],
                            selected: i == _selectedIndex,
                            onTap: () => setState(() => _selectedIndex = i),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(kSpace16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: kSpace8),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(
                          widget.labs[_selectedIndex],
                        );
                      },
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Send to lab'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabOptionTile extends StatefulWidget {
  const _LabOptionTile({
    required this.lab,
    required this.selected,
    required this.onTap,
  });

  final MockLab lab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_LabOptionTile> createState() => _LabOptionTileState();
}

class _LabOptionTileState extends State<_LabOptionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool selected = widget.selected;
    final Color background = selected
        ? scheme.primaryContainer
        : (_hovered ? scheme.surface : Colors.transparent);
    final Color textColor = selected ? scheme.primary : scheme.onSurface;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace12,
            vertical: kSpace12,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(kRadius - 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              UserAvatar(
                name: widget.lab.contactScientistName,
                imageUrl: widget.lab.contactScientistAvatarUrl,
                size: 36,
              ),
              const SizedBox(width: kSpace12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.lab.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.lab.contactScientistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.scientist.bodyTertiary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: kSpace8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 20,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
