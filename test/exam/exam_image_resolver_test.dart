import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/exam/presentation/widgets/exam_image_resolver.dart';

void main() {
  group('CachingExamImageUrlResolver (contract D3)', () {
    late List<String> lookups;
    late bool fail;
    late CachingExamImageUrlResolver resolve;

    setUp(() {
      lookups = [];
      fail = false;
      resolve = CachingExamImageUrlResolver((path) async {
        lookups.add(path);
        if (fail) throw StateError('storage/retry-limit-exceeded');
        return 'https://firebasestorage.example/$path?token=t';
      });
    });

    test('resolves a Storage path once and caches the URL in memory', () async {
      expect(await resolve('exam_media/q1/fig.png'),
          'https://firebasestorage.example/exam_media/q1/fig.png?token=t');
      expect(await resolve('exam_media/q1/fig.png'),
          'https://firebasestorage.example/exam_media/q1/fig.png?token=t');
      expect(await resolve('/exam_media/q1/fig.png'),
          'https://firebasestorage.example/exam_media/q1/fig.png?token=t',
          reason: 'a leading slash is the same object');
      expect(lookups, ['exam_media/q1/fig.png']);
      expect(resolve.cachedCount, 1);
    });

    test('http(s) URLs pass through without a Storage lookup', () async {
      expect(await resolve('https://cdn.example/a.png'), 'https://cdn.example/a.png');
      expect(await resolve('  '), isNull);
      expect(lookups, isEmpty);
    });

    test('a failed lookup is not cached, so a retry asks Storage again', () async {
      fail = true;
      await expectLater(resolve('exam_media/q2/x.png'), throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(resolve.cachedCount, 0);
      fail = false;
      expect(await resolve('exam_media/q2/x.png'),
          'https://firebasestorage.example/exam_media/q2/x.png?token=t');
      expect(lookups, ['exam_media/q2/x.png', 'exam_media/q2/x.png']);
    });
  });
}
