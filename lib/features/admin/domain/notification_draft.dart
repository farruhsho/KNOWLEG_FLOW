/// Push broadcasts composed in the CMS — ARCHITECTURE.md §9.4
/// (`adminSendNotification`, permission `send_notifications`).
///
/// Pure Dart so validation and the callable payload are unit-tested. The
/// callable validates everything again (the server is the source of truth for
/// recipients, the daily limit and what is actually sent).
library;

import 'dart:convert';

import 'exam_question.dart' show readDateTolerant;
import 'localized_text.dart' show readLocalized;

/// Longest title, in Unicode code points. A push title longer than this is
/// cut by Android and iOS on the lock screen.
const int kNotificationTitleMax = 65;

/// Longest body, in Unicode code points (what an expanded notification shows
/// without truncation).
const int kNotificationBodyMax = 240;

/// Broadcasts per day the server allows (§9.4: "не больше 3 рассылок в
/// сутки"); the callable answers `LIMIT_REACHED` / `RATE_LIMITED` beyond it.
const int kNotificationsPerDay = 3;

/// Both languages are required: recipients get the text in their
/// `preferred_language`.
const List<String> kNotificationLanguages = ['ru', 'ky'];

/// Firestore document id shape accepted for a group audience.
final RegExp _groupIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// Length as the server and Firestore rules count it (code points, trimmed).
int notificationTextLength(String text) => text.trim().runes.length;

enum NotificationAudienceKind {
  all('all'),
  language('language'),
  region('region'),
  group('group');

  const NotificationAudienceKind(this.wire);

  /// Value of `audience.kind` in the callable payload.
  final String wire;

  /// Whether `audience.value` is required.
  bool get needsValue => this != NotificationAudienceKind.all;

  static NotificationAudienceKind? fromWire(Object? value) {
    for (final k in values) {
      if (k.wire == value) return k;
    }
    return null;
  }
}

enum NotificationIssue {
  titleRuRequired,
  titleKyRequired,
  bodyRuRequired,
  bodyKyRequired,
  titleRuTooLong,
  titleKyTooLong,
  bodyRuTooLong,
  bodyKyTooLong,
  audienceValueRequired,
  audienceLanguageInvalid,
  audienceRegionUnknown,
  audienceGroupInvalid,
}

/// `audience: {kind, value?}`. For `region` the value is the canonical
/// oblast stored in `users/{uid}.region.oblast` (the `oblast` field of
/// `assets/data/kg_regions.json`, also the server's leaderboard `region_id`);
/// for `group` it is the group document id; for `language` `ru` or `ky`.
class NotificationAudience {
  final NotificationAudienceKind kind;
  final String? value;

  const NotificationAudience(this.kind, [this.value]);

  static const NotificationAudience everyone = NotificationAudience(NotificationAudienceKind.all);

  String? get _trimmed {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Validates the audience. [knownRegions] are the canonical oblast values;
  /// when `null` the region is only checked for presence.
  List<NotificationIssue> validate({Set<String>? knownRegions}) {
    final v = _trimmed;
    if (!kind.needsValue) return const [];
    if (v == null) return const [NotificationIssue.audienceValueRequired];
    switch (kind) {
      case NotificationAudienceKind.all:
        return const [];
      case NotificationAudienceKind.language:
        return kNotificationLanguages.contains(v)
            ? const []
            : const [NotificationIssue.audienceLanguageInvalid];
      case NotificationAudienceKind.region:
        return (knownRegions == null || knownRegions.contains(v))
            ? const []
            : const [NotificationIssue.audienceRegionUnknown];
      case NotificationAudienceKind.group:
        return _groupIdPattern.hasMatch(v)
            ? const []
            : const [NotificationIssue.audienceGroupInvalid];
    }
  }

  /// `{kind}` for everyone, `{kind, value}` otherwise.
  Map<String, dynamic> toWire() => {
        'kind': kind.wire,
        if (kind.needsValue && _trimmed != null) 'value': _trimmed,
      };

  /// Tolerant reader for history documents.
  static NotificationAudience? fromWire(Object? raw) {
    if (raw is! Map) return null;
    final kind = NotificationAudienceKind.fromWire(raw['kind']);
    if (kind == null) return null;
    final v = raw['value'];
    return NotificationAudience(kind, v?.toString());
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationAudience && other.kind == kind && other._trimmed == _trimmed;

  @override
  int get hashCode => Object.hash(kind, _trimmed);
}

/// What the composer would send.
class NotificationDraft {
  final Map<String, String> title;
  final Map<String, String> body;
  final NotificationAudience audience;

  const NotificationDraft({
    required this.title,
    required this.body,
    this.audience = NotificationAudience.everyone,
  });

  String _t(Map<String, String> m, String lang) => (m[lang] ?? '').trim();

  List<NotificationIssue> validate({Set<String>? knownRegions}) {
    final issues = <NotificationIssue>[];
    void check(String text, int max, NotificationIssue required, NotificationIssue tooLong) {
      final n = notificationTextLength(text);
      if (n == 0) {
        issues.add(required);
      } else if (n > max) {
        issues.add(tooLong);
      }
    }

    check(_t(title, 'ru'), kNotificationTitleMax, NotificationIssue.titleRuRequired,
        NotificationIssue.titleRuTooLong);
    check(_t(title, 'ky'), kNotificationTitleMax, NotificationIssue.titleKyRequired,
        NotificationIssue.titleKyTooLong);
    check(_t(body, 'ru'), kNotificationBodyMax, NotificationIssue.bodyRuRequired,
        NotificationIssue.bodyRuTooLong);
    check(_t(body, 'ky'), kNotificationBodyMax, NotificationIssue.bodyKyRequired,
        NotificationIssue.bodyKyTooLong);
    issues.addAll(audience.validate(knownRegions: knownRegions));
    return issues;
  }

  /// `adminSendNotification` input (§9.4): `{title: {ru, ky}, body: {ru, ky},
  /// audience: {kind, value?}, dryRun}`. Texts are trimmed; nothing else is
  /// sent.
  Map<String, dynamic> toCallable({required bool dryRun}) => {
        'title': {for (final l in kNotificationLanguages) l: _t(title, l)},
        'body': {for (final l in kNotificationLanguages) l: _t(body, l)},
        'audience': audience.toWire(),
        'dryRun': dryRun,
      };

  /// Identity of the exact payload: a reach check is only valid for the very
  /// same text and audience.
  String get signature => jsonEncode(toCallable(dryRun: false));
}

int _int(Object? v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v.trim()) ?? 0 : (v is List ? v.length : 0));

String? _sn(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// `adminSendNotification` output: `{recipients, sent, failed, notificationId}`.
class NotificationSendResult {
  final int recipients;
  final int sent;
  final int failed;
  final String? notificationId;

  const NotificationSendResult({
    required this.recipients,
    this.sent = 0,
    this.failed = 0,
    this.notificationId,
  });

  factory NotificationSendResult.fromMap(Map<String, dynamic> m) => NotificationSendResult(
        recipients: _int(m['recipients']),
        sent: _int(m['sent']),
        failed: _int(m['failed']),
        notificationId: _sn(m['notificationId'] ?? m['notification_id']),
      );
}

/// `notifications/{id}` — history written by the callable. The document
/// schema is not fixed beyond §9.4, so fields are read tolerantly
/// (snake_case first, as everywhere in Firestore).
class NotificationRecord {
  final String id;
  final Map<String, String> title;
  final Map<String, String> body;
  final NotificationAudience? audience;
  final int recipients;
  final int sent;
  final int failed;
  final String? status;
  final String? createdBy;
  final DateTime? createdAt;

  const NotificationRecord({
    required this.id,
    this.title = const {},
    this.body = const {},
    this.audience,
    this.recipients = 0,
    this.sent = 0,
    this.failed = 0,
    this.status,
    this.createdBy,
    this.createdAt,
  });

  factory NotificationRecord.fromMap(String id, Map<String, dynamic> d) => NotificationRecord(
        id: id,
        title: readLocalized(d['title']),
        body: readLocalized(d['body']),
        audience: NotificationAudience.fromWire(d['audience']),
        recipients: _int(d['recipients'] ?? d['recipients_count']),
        sent: _int(d['sent'] ?? d['sent_count'] ?? d['success_count']),
        failed: _int(d['failed'] ?? d['failed_count'] ?? d['failure_count']),
        status: _sn(d['status']),
        createdBy: _sn(d['created_by'] ?? d['sent_by'] ?? d['actor_uid']),
        createdAt: readDateTolerant(d['created_at'] ?? d['sent_at'] ?? d['at']),
      );
}

/// Calendar day in Bishkek (UTC+6, no DST) as `yyyy-mm-dd`.
String bishkekDay(DateTime t) {
  final b = t.toUtc().add(const Duration(hours: 6));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${b.year}-${two(b.month)}-${two(b.day)}';
}

/// Broadcasts in [history] sent on the Bishkek day of [now] — an estimate for
/// the composer; the server enforces the real limit.
int notificationsSentToday(Iterable<NotificationRecord> history, DateTime now) {
  final today = bishkekDay(now);
  return history.where((r) => r.createdAt != null && bishkekDay(r.createdAt!) == today).length;
}
