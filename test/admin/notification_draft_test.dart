import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/admin/domain/notification_draft.dart';

NotificationDraft _draft({
  String titleRu = 'Новый вариант',
  String titleKy = 'Жаңы вариант',
  String bodyRu = 'Пробный экзамен по математике уже доступен.',
  String bodyKy = 'Математика боюнча сынамык экзамен даяр.',
  NotificationAudience audience = NotificationAudience.everyone,
}) =>
    NotificationDraft(
      title: {'ru': titleRu, 'ky': titleKy},
      body: {'ru': bodyRu, 'ky': bodyKy},
      audience: audience,
    );

void main() {
  group('texts (§9.4: ru and ky required, length limits)', () {
    test('a complete draft is valid', () {
      expect(_draft().validate(), isEmpty);
    });

    test('both languages are required for title and body', () {
      expect(_draft(titleKy: '   ').validate(), [NotificationIssue.titleKyRequired]);
      expect(_draft(bodyRu: '').validate(), [NotificationIssue.bodyRuRequired]);
      expect(
        const NotificationDraft(title: {}, body: {}).validate(),
        containsAll([
          NotificationIssue.titleRuRequired,
          NotificationIssue.titleKyRequired,
          NotificationIssue.bodyRuRequired,
          NotificationIssue.bodyKyRequired,
        ]),
      );
    });

    test('limits are inclusive and counted in code points after trimming', () {
      final maxTitle = 'а' * kNotificationTitleMax;
      expect(_draft(titleRu: '  $maxTitle  ').validate(), isEmpty);
      expect(_draft(titleRu: '$maxTitleб').validate(), [NotificationIssue.titleRuTooLong]);
      expect(_draft(bodyKy: 'ө' * (kNotificationBodyMax + 1)).validate(),
          [NotificationIssue.bodyKyTooLong]);
      // An emoji is one code point but two UTF-16 units.
      final emojis = '😀' * kNotificationTitleMax;
      expect(emojis.length, 2 * kNotificationTitleMax);
      expect(notificationTextLength(emojis), kNotificationTitleMax);
      expect(_draft(titleKy: emojis).validate(), isEmpty);
    });

    test('limits match a push notification', () {
      expect(kNotificationTitleMax, 65);
      expect(kNotificationBodyMax, 240);
      expect(kNotificationsPerDay, 3);
    });
  });

  group('audience', () {
    const regions = {'Чуйская область', 'г. Бишкек'};

    test('everyone needs no value', () {
      expect(NotificationAudience.everyone.validate(), isEmpty);
      expect(NotificationAudience.everyone.toWire(), {'kind': 'all'});
      // A stray value is never sent for "all".
      expect(const NotificationAudience(NotificationAudienceKind.all, 'ru').toWire(), {'kind': 'all'});
    });

    test('language: ru or ky only', () {
      expect(const NotificationAudience(NotificationAudienceKind.language, 'ky').validate(), isEmpty);
      expect(const NotificationAudience(NotificationAudienceKind.language, 'en').validate(),
          [NotificationIssue.audienceLanguageInvalid]);
      expect(const NotificationAudience(NotificationAudienceKind.language).validate(),
          [NotificationIssue.audienceValueRequired]);
    });

    test('region: one of kg_regions.json oblasts', () {
      expect(
        const NotificationAudience(NotificationAudienceKind.region, 'Чуйская область')
            .validate(knownRegions: regions),
        isEmpty,
      );
      expect(
        const NotificationAudience(NotificationAudienceKind.region, 'Atlantis')
            .validate(knownRegions: regions),
        [NotificationIssue.audienceRegionUnknown],
      );
      expect(const NotificationAudience(NotificationAudienceKind.region, '  ').validate(),
          [NotificationIssue.audienceValueRequired]);
    });

    test('group: a document id', () {
      expect(const NotificationAudience(NotificationAudienceKind.group, 'g_123-ABC').validate(), isEmpty);
      for (final bad in ['groups/x', 'a b', 'x' * 129, 'группа']) {
        expect(const NotificationAudience(NotificationAudienceKind.group).validate(),
            [NotificationIssue.audienceValueRequired]);
        expect(NotificationAudience(NotificationAudienceKind.group, bad).validate(),
            [NotificationIssue.audienceGroupInvalid],
            reason: bad);
      }
    });

    test('wire shape {kind, value} with a trimmed value; equality ignores spaces', () {
      const a = NotificationAudience(NotificationAudienceKind.group, ' g1 ');
      expect(a.toWire(), {'kind': 'group', 'value': 'g1'});
      expect(a, const NotificationAudience(NotificationAudienceKind.group, 'g1'));
      expect(NotificationAudience.fromWire({'kind': 'region', 'value': 'Нарынская область'}),
          const NotificationAudience(NotificationAudienceKind.region, 'Нарынская область'));
      expect(NotificationAudience.fromWire({'kind': 'nope'}), isNull);
      expect(NotificationAudience.fromWire('all'), isNull);
    });

    test('draft validation includes the audience', () {
      expect(
        _draft(audience: const NotificationAudience(NotificationAudienceKind.language, 'kg')).validate(),
        [NotificationIssue.audienceLanguageInvalid],
      );
    });
  });

  group('adminSendNotification payload', () {
    test('exactly title, body, audience, dryRun — trimmed, only ru/ky', () {
      const d = NotificationDraft(
        title: {'ru': ' Привет ', 'ky': 'Салам', 'en': 'Hello'},
        body: {'ru': 'Текст', 'ky': ' Текст '},
        audience: NotificationAudience(NotificationAudienceKind.language, 'ky'),
      );
      expect(d.toCallable(dryRun: true), {
        'title': {'ru': 'Привет', 'ky': 'Салам'},
        'body': {'ru': 'Текст', 'ky': 'Текст'},
        'audience': {'kind': 'language', 'value': 'ky'},
        'dryRun': true,
      });
      expect(d.toCallable(dryRun: false)['dryRun'], isFalse);
    });

    test('a reach check is tied to the exact text and audience', () {
      final a = _draft();
      expect(_draft().signature, a.signature);
      expect(_draft(bodyRu: 'Другой текст').signature, isNot(a.signature));
      expect(
        _draft(audience: const NotificationAudience(NotificationAudienceKind.language, 'ru')).signature,
        isNot(a.signature),
      );
      // Whitespace that is trimmed away does not invalidate the check.
      expect(_draft(titleRu: ' Новый вариант ').signature, a.signature);
    });

    test('result and history are read tolerantly', () {
      final r = NotificationSendResult.fromMap(
          {'recipients': 120, 'sent': 118, 'failed': 2, 'notificationId': 'n1'});
      expect([r.recipients, r.sent, r.failed, r.notificationId], [120, 118, 2, 'n1']);
      final dry = NotificationSendResult.fromMap({'recipients': 7});
      expect([dry.recipients, dry.sent, dry.failed, dry.notificationId], [7, 0, 0, null]);

      final h = NotificationRecord.fromMap('n2', {
        'title': {'ru': 'Заголовок', 'kg': 'Аталышы'},
        'body': {'ru': 'Текст'},
        'audience': {'kind': 'all'},
        'recipients_count': 10,
        'sent_count': 9,
        'failed_count': 1,
        'created_by': 'admin1',
        'created_at': DateTime.utc(2026, 11, 4, 10),
      });
      expect(h.title, {'ru': 'Заголовок', 'ky': 'Аталышы'});
      expect([h.recipients, h.sent, h.failed], [10, 9, 1]);
      expect(h.audience, NotificationAudience.everyone);
      expect(h.createdBy, 'admin1');
    });
  });

  group('daily limit estimate (Bishkek day)', () {
    test('counts broadcasts of the current Bishkek calendar day', () {
      // 2026-11-04 18:30 UTC = 2026-11-05 00:30 in Bishkek.
      final now = DateTime.utc(2026, 11, 4, 18, 30);
      final history = [
        NotificationRecord(id: 'a', createdAt: DateTime.utc(2026, 11, 4, 18, 5)), // 00:05 on the 5th
        NotificationRecord(id: 'b', createdAt: DateTime.utc(2026, 11, 4, 17, 59)), // 23:59 on the 4th
        const NotificationRecord(id: 'c'),
      ];
      expect(bishkekDay(now), '2026-11-05');
      expect(notificationsSentToday(history, now), 1);
    });
  });
}
