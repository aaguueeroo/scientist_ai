import 'package:flutter_test/flutter_test.dart';
import 'package:scientist_ai/core/conversation_query_key.dart';

void main() {
  test('conversationQueryKey collapses newlines and runs of space', () {
    expect(
      conversationQueryKey('  CRISPR\n\nCas9  delivery   '),
      'CRISPR Cas9 delivery',
    );
  });
}
