import 'package:flutter_test/flutter_test.dart';

import 'package:scientist_ai/data/mappers/review_mapper.dart';
import 'package:scientist_ai/features/plan/review/models/change_target.dart';
import 'package:scientist_ai/features/plan/review/models/feedback_polarity.dart';
import 'package:scientist_ai/features/plan/review/models/review_section.dart';
import 'package:scientist_ai/features/review/models/review.dart';
import 'package:scientist_ai/models/experiment_plan.dart';

void main() {
  group('ReviewMapper.withServerId', () {
    test('CorrectionReview keeps fields, replaces id', () {
      final ExperimentPlan plan = ExperimentPlan(
        hypothesis: '',
        description: 'd',
        budget: const Budget(total: 1, materials: <Material>[]),
        timePlan: const TimePlan(
          totalDuration: Duration(seconds: 1),
          steps: <Step>[],
        ),
      );
      const ChangeTarget target = PlanDescriptionTarget();
      final CorrectionReview r = CorrectionReview(
        id: 'local',
        conversationId: 'c1',
        query: 'q',
        originalPlan: plan,
        createdAt: DateTime.utc(2026, 1, 2),
        target: target,
        before: 'a',
        after: 'b',
      );
      final Review out = ReviewMapper.withServerId(r, 'fb-1');
      expect(out, isA<CorrectionReview>());
      final CorrectionReview c = out as CorrectionReview;
      expect(c.id, 'fb-1');
      expect(c.conversationId, 'c1');
      expect(c.target, target);
      expect(c.before, 'a');
      expect(c.after, 'b');
    });

    test('FeedbackReview keeps section and polarity', () {
      final ExperimentPlan plan = ExperimentPlan(
        hypothesis: '',
        description: 'd',
        budget: const Budget(total: 1, materials: <Material>[]),
        timePlan: const TimePlan(
          totalDuration: Duration(seconds: 1),
          steps: <Step>[],
        ),
      );
      final FeedbackReview r = FeedbackReview(
        id: 'local',
        conversationId: 'c1',
        query: 'q',
        originalPlan: plan,
        createdAt: DateTime.utc(2026, 1, 2),
        section: ReviewSection.budget,
        polarity: FeedbackPolarity.like,
      );
      final Review out = ReviewMapper.withServerId(r, 'fb-2');
      expect(out, isA<FeedbackReview>());
      final FeedbackReview f = out as FeedbackReview;
      expect(f.id, 'fb-2');
      expect(f.section, ReviewSection.budget);
      expect(f.polarity, FeedbackPolarity.like);
    });
  });
}
