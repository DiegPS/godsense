import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/persistence/derivation_key_builder.dart';

void main() {
  test('builds stable keys from canonical parameters and ordered parents', () {
    const builder = DerivationKeyBuilder();
    final first = builder.build(
      producer: 'reconciler',
      producerVersion: '2',
      orderedParentIds: ['observation-1', 'event-2'],
      parameters: {'champion': 'Akali', 'zone': 'river'},
    );
    final same = builder.build(
      producer: 'reconciler',
      producerVersion: '2',
      orderedParentIds: ['observation-1', 'event-2'],
      parameters: {'zone': 'river', 'champion': 'Akali'},
    );
    final reorderedParents = builder.build(
      producer: 'reconciler',
      producerVersion: '2',
      orderedParentIds: ['event-2', 'observation-1'],
      parameters: {'champion': 'Akali', 'zone': 'river'},
    );

    expect(first, same);
    expect(first, isNot(reorderedParents));
  });
}
