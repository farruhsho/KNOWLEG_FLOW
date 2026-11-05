import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/social/domain/social_codes.dart';
import 'package:knowledge_flow/features/social/domain/social_failure.dart';
import 'package:knowledge_flow/features/social/presentation/social_messages.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

FirebaseFunctionsException _callable(String code, [String? reason]) => FirebaseFunctionsException(
      message: 'x',
      code: code,
      details: reason == null ? null : {'reason': reason},
    );

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final ky = lookupAppLocalizations(const Locale('ky'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('backend reason → failure kind (ARCHITECTURE §9)', () {
    test('every phase-3 reason is mapped', () {
      const expected = {
        'CODE_INVALID': SocialFailureKind.codeInvalid,
        'CODE_EXPIRED': SocialFailureKind.codeExpired,
        'CODE_EXHAUSTED': SocialFailureKind.codeExhausted,
        'ALREADY_REDEEMED': SocialFailureKind.alreadyRedeemed,
        'RATE_LIMITED': SocialFailureKind.rateLimited,
        'REFERRAL_NOT_ALLOWED': SocialFailureKind.referralNotAllowed,
        'LIMIT_REACHED': SocialFailureKind.limitReached,
        'NOT_GROUP_OWNER': SocialFailureKind.notGroupOwner,
        'USER_BANNED': SocialFailureKind.banned,
        'VALIDATION_FAILED': SocialFailureKind.validation,
      };
      expected.forEach((reason, kind) {
        expect(SocialFailure.from(_callable('failed-precondition', reason)).kind, kind, reason: reason);
      });
    });

    test('the reason wins over the HttpsError code', () {
      expect(SocialFailure.from(_callable('resource-exhausted', 'LIMIT_REACHED')).kind,
          SocialFailureKind.limitReached);
      expect(SocialFailure.from(_callable('already-exists', 'CODE_INVALID')).kind, SocialFailureKind.codeInvalid);
    });

    test('without a reason the code decides', () {
      expect(SocialFailure.from(_callable('unavailable')).kind, SocialFailureKind.offline);
      expect(SocialFailure.from(_callable('resource-exhausted')).kind, SocialFailureKind.rateLimited);
      expect(SocialFailure.from(_callable('already-exists')).kind, SocialFailureKind.alreadyRedeemed);
      expect(SocialFailure.from(_callable('unauthenticated')).kind, SocialFailureKind.notSignedIn);
      expect(SocialFailure.from(_callable('internal', 'SOMETHING_NEW')).kind, SocialFailureKind.unknown);
      expect(SocialFailure.from(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')).kind,
          SocialFailureKind.permissionDenied);
      expect(SocialFailure.from(StateError('boom')).kind, SocialFailureKind.unknown);
    });
  });

  group('referral messages', () {
    String msg(String reason, [AppLocalizations? l]) =>
        (l ?? ru).socialErrorMessage(_callable('failed-precondition', reason), SocialAction.referral);

    test('CODE_INVALID / REFERRAL_NOT_ALLOWED / already referred are distinct and clear', () {
      expect(msg('CODE_INVALID'), 'Такого кода нет. Проверьте его и попробуйте ещё раз.');
      expect(msg('REFERRAL_NOT_ALLOWED'), contains('только в новом аккаунте'));
      expect(msg('ALREADY_REDEEMED'), contains('уже вводили код друга'));
      expect({msg('CODE_INVALID'), msg('REFERRAL_NOT_ALLOWED'), msg('ALREADY_REDEEMED')}, hasLength(3));
    });

    test('Kyrgyz and English have their own text', () {
      expect(msg('ALREADY_REDEEMED', ky), contains('бир гана жолу'));
      expect(msg('REFERRAL_NOT_ALLOWED', en), contains('new account'));
    });

    test('own code is caught on the client', () {
      expect(ru.socialFailureKindMessage(SocialFailureKind.ownCode, SocialAction.referral),
          'Это ваш собственный код. Введите код друга.');
    });
  });

  group('promo messages', () {
    String msg(String reason) => ru.socialErrorMessage(_callable('failed-precondition', reason), SocialAction.promo);

    test('each promo reason has its own message', () {
      expect(msg('CODE_INVALID'), contains('Такого кода нет'));
      expect(msg('CODE_EXPIRED'), 'Срок действия промокода истёк.');
      expect(msg('CODE_EXHAUSTED'), contains('все активации'));
      expect(msg('ALREADY_REDEEMED'), 'Вы уже использовали этот промокод.');
      expect(msg('RATE_LIMITED'), contains('Попробуйте завтра'));
    });

    test('ALREADY_REDEEMED depends on the action', () {
      final e = _callable('already-exists', 'ALREADY_REDEEMED');
      expect(ru.socialErrorMessage(e, SocialAction.promo), contains('промокод'));
      expect(ru.socialErrorMessage(e, SocialAction.referral), contains('код друга'));
      expect(ru.socialErrorMessage(e, SocialAction.groupJoin), contains('группе'));
      expect(ru.socialErrorMessage(e, SocialAction.friendAdd), contains('друг'));
    });

    test('LIMIT_REACHED names the limit that applies', () {
      final e = _callable('resource-exhausted', 'LIMIT_REACHED');
      expect(ru.socialErrorMessage(e, SocialAction.friendAdd), contains('50'));
      expect(ru.socialErrorMessage(e, SocialAction.groupJoin), contains('5 групп'));
    });

    test('never shows the raw error', () {
      for (final kind in SocialFailureKind.values) {
        for (final action in SocialAction.values) {
          final text = ru.socialFailureKindMessage(kind, action);
          expect(text, isNotEmpty);
          expect(text, isNot(contains('Exception')));
          expect(text, isNot(contains('_')));
        }
      }
    });
  });

  group('details.why / details.what (ARCHITECTURE §9.7)', () {
    FirebaseFunctionsException withDetails(String code, Map<String, Object> details) =>
        FirebaseFunctionsException(message: 'x', code: code, details: details);
    SocialFailureKind kindOf(String code, Map<String, Object> details) =>
        SocialFailure.from(withDetails(code, details)).kind;

    test('why is read before the reason', () {
      expect(kindOf('invalid-argument', {'reason': 'VALIDATION_FAILED', 'why': 'self', 'field': 'code'}),
          SocialFailureKind.ownCode);
      expect(kindOf('failed-precondition', {'reason': 'REFERRAL_NOT_ALLOWED', 'why': 'own_code'}),
          SocialFailureKind.ownCode);
      expect(kindOf('failed-precondition', {'reason': 'REFERRAL_NOT_ALLOWED', 'why': 'already_referred'}),
          SocialFailureKind.alreadyRedeemed);
      expect(kindOf('failed-precondition', {'reason': 'VALIDATION_FAILED', 'why': 'owner_has_members'}),
          SocialFailureKind.ownerHasMembers);
      expect(kindOf('failed-precondition', {'reason': 'VALIDATION_FAILED', 'why': 'removed_from_group'}),
          SocialFailureKind.removedFromGroup);
      expect(kindOf('failed-precondition', {'reason': 'VALIDATION_FAILED', 'why': 'profile_missing'}),
          SocialFailureKind.profileMissing);
    });

    test('a why with nothing more specific falls back to the reason', () {
      expect(kindOf('failed-precondition', {'reason': 'REFERRAL_NOT_ALLOWED', 'why': 'has_exams'}),
          SocialFailureKind.referralNotAllowed);
      expect(kindOf('failed-precondition', {'reason': 'REFERRAL_NOT_ALLOWED', 'why': 'has_purchases'}),
          SocialFailureKind.referralNotAllowed);
      expect(kindOf('invalid-argument', {'reason': 'VALIDATION_FAILED', 'why': 'something_new'}),
          SocialFailureKind.validation);
    });

    test('friendAdd with my own code: "this is your code", not the generic validation text', () {
      final e = withDetails('invalid-argument', {'reason': 'VALIDATION_FAILED', 'why': 'self', 'field': 'code'});
      expect(ru.socialErrorMessage(e, SocialAction.friendAdd), 'Это ваш собственный код. Введите код друга.');
      expect(en.socialErrorMessage(e, SocialAction.friendAdd), contains('your own code'));
    });

    test('referralApply: own code and already referred have their own messages', () {
      String msg(String why, [AppLocalizations? l]) => (l ?? ru).socialErrorMessage(
          withDetails('failed-precondition', {'reason': 'REFERRAL_NOT_ALLOWED', 'why': why}), SocialAction.referral);
      expect(msg('own_code'), 'Это ваш собственный код. Введите код друга.');
      expect(msg('already_referred'), 'Вы уже вводили код друга. Это можно сделать только один раз.');
      expect(msg('already_referred', ky), contains('бир гана жолу'));
      expect(msg('has_exams'), contains('только в новом аккаунте'));
    });

    test('groups: owner cannot leave, removed member, profile not ready', () {
      String msg(String why, SocialAction action, [AppLocalizations? l]) => (l ?? ru).socialErrorMessage(
          withDetails('failed-precondition', {'reason': 'VALIDATION_FAILED', 'why': why}), action);
      expect(msg('owner_has_members', SocialAction.other), ru.socialGroupOwnerCannotLeave);
      expect(msg('removed_from_group', SocialAction.groupJoin), contains('исключил вас из этой группы'));
      expect(msg('removed_from_group', SocialAction.groupJoin, ky), contains('чыгарып салган'));
      expect(msg('removed_from_group', SocialAction.groupJoin, en), contains('removed you from this group'));
      expect(msg('profile_missing', SocialAction.groupCreate), contains('через минуту'));
      expect(msg('profile_missing', SocialAction.friendAdd, en), contains('in a minute'));
    });

    test('LIMIT_REACHED: a full group is not "at most 5 groups"', () {
      String msg(String what, SocialAction action, [AppLocalizations? l]) => (l ?? ru).socialErrorMessage(
          withDetails('resource-exhausted', {'reason': 'LIMIT_REACHED', 'what': what, 'limit': 5}), action);
      expect(kindOf('resource-exhausted', {'reason': 'LIMIT_REACHED', 'what': 'group_members', 'limit': 500}),
          SocialFailureKind.groupFull);
      expect(msg('group_members', SocialAction.groupJoin), contains('500 участников'));
      expect(msg('group_members', SocialAction.groupJoin), isNot(contains('5 групп')));
      expect(msg('group_members', SocialAction.groupJoin, ky), contains('500'));
      expect(msg('group_members', SocialAction.groupJoin, en), contains('500 members'));
      expect(msg('memberships', SocialAction.groupJoin), 'Достигнут лимит: не больше 5 групп.');
      expect(msg('memberships', SocialAction.groupCreate), 'Достигнут лимит: не больше 5 групп.');
      expect(msg('owned_groups', SocialAction.groupCreate), 'Достигнут лимит: не больше 5 групп.');
      expect(msg('friends', SocialAction.friendAdd), contains('50'));
    });

    test('what only narrows LIMIT_REACHED', () {
      expect(kindOf('invalid-argument', {'reason': 'VALIDATION_FAILED', 'what': 'group_members'}),
          SocialFailureKind.validation);
    });

    test('RATE_LIMITED on friend/group codes: "too many attempts, try tomorrow", nothing about promo codes', () {
      final e = withDetails('resource-exhausted', {'reason': 'RATE_LIMITED', 'what': 'code_attempts'});
      for (final action in [SocialAction.friendAdd, SocialAction.groupJoin]) {
        expect(ru.socialErrorMessage(e, action), 'Слишком много попыток за сегодня. Попробуйте завтра.');
        expect(ky.socialErrorMessage(e, action), contains('Эртең'));
        expect(en.socialErrorMessage(e, action), 'Too many attempts today. Try again tomorrow.');
        for (final l in [ru, ky, en]) {
          expect(l.socialErrorMessage(e, action).toLowerCase(), isNot(contains('промокод')));
          expect(l.socialErrorMessage(e, action).toLowerCase(), isNot(contains('promo')));
        }
      }
    });

    test('the new texts are translated, not copied from Russian', () {
      for (final kind in [
        SocialFailureKind.groupFull,
        SocialFailureKind.removedFromGroup,
        SocialFailureKind.profileMissing,
        SocialFailureKind.ownerHasMembers,
      ]) {
        final texts = {
          for (final l in [ru, ky, en]) l.socialFailureKindMessage(kind, SocialAction.groupJoin),
        };
        expect(texts, hasLength(3), reason: '$kind');
      }
      expect({ru.socialGroupNameLength, ky.socialGroupNameLength, en.socialGroupNameLength}, hasLength(3));
      for (final l in [ru, ky, en]) {
        expect(l.socialGroupNameLength, allOf(contains('2'), contains('60')));
      }
    });
  });

  group('codes', () {
    test('normalises case, separators and Cyrillic look-alikes', () {
      expect(SocialCodes.normalize(' k7m-2qx '), 'K7M2QX');
      // Typed on a Russian layout: А, В, С, Е, Н, Р, Т are Cyrillic here.
      expect(SocialCodes.normalize('АВС ЕНР Т'), 'ABCEHPT');
    });

    test('referral codes: 6 characters from the unambiguous alphabet', () {
      expect(SocialCodes.isReferralCode('K7M2QX'), isTrue);
      expect(SocialCodes.isReferralCode('K7M2Q'), isFalse);
      expect(SocialCodes.isReferralCode('K7M2QO'), isFalse, reason: 'no O');
      expect(SocialCodes.isReferralCode('K7M2Q1'), isFalse, reason: 'no 1');
    });

    test('promo codes: 4–20 of A-Z0-9', () {
      expect(SocialCodes.isPromoCode('ORT2026'), isTrue);
      expect(SocialCodes.isPromoCode('ABC'), isFalse);
      expect(SocialCodes.isPromoCode('A' * 21), isFalse);
      expect(SocialCodes.isPromoCode('ORT-2026'), isFalse);
    });
  });
}
