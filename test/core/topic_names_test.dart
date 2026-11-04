import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/content/topic_names.dart';

void main() {
  final names = TopicNames.fromJson(
      jsonDecode(File('assets/data/topic_names.json').readAsStringSync())
          as Map<String, dynamic>);

  test('bundled asset resolves real topic ids in every language', () {
    expect(names.label('math', 'ru'), 'Математика');
    expect(names.label('math.arithmetic', 'en'), 'Arithmetic');
    expect(names.label('math.arithmetic.order_of_operations', 'ky'),
        'Амалдардын аткарылуу тартиби');
  });

  test('unknown child falls back to the nearest known parent', () {
    expect(names.label('math.arithmetic.not_in_catalog', 'ru'), 'Арифметика');
  });

  test('completely unknown id is humanized, never shown raw', () {
    expect(TopicNames.empty.label('physics.optics_lenses', 'ru'), 'Optics lenses');
    expect(TopicNames.empty.label('x', 'ru'), 'X');
  });
}
