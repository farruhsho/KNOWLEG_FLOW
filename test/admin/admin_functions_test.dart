import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/backend/backend_contract.dart';
import 'package:knowledge_flow/features/admin/data/admin_functions.dart';
import 'package:knowledge_flow/features/admin/domain/callable_errors.dart';
import 'package:knowledge_flow/features/admin/domain/notification_draft.dart';
import 'package:knowledge_flow/features/admin/domain/promo_code.dart';

/// Records every callable invocation: name, client timeout and payload.
class _FakeFunctions implements FirebaseFunctions {
  final calls = <({String name, Duration? timeout, Object? data})>[];
  Object? response = const <String, dynamic>{};

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _FakeCallable(this, name, options?.timeout);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallable implements HttpsCallable {
  _FakeCallable(this._functions, this._name, this._timeout);
  final _FakeFunctions _functions;
  final String _name;
  final Duration? _timeout;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    _functions.calls.add((name: _name, timeout: _timeout, data: parameters));
    return _Result<T>(_functions.response as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Result<T> implements HttpsCallableResult<T> {
  _Result(this.data);

  @override
  final T data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _draft = NotificationDraft(
  title: {'ru': 'Заголовок', 'ky': 'Аталыш'},
  body: {'ru': 'Текст', 'ky': 'Текст'},
);

void main() {
  group('adminSendNotification (F4, §9.7)', () {
    test('the reach check and the send both wait up to 540 s', () async {
      final fns = _FakeFunctions()..response = {'recipients': 3, 'sent': 0, 'failed': 0};
      final api = AdminFunctions(fns);
      await api.sendNotification(_draft, dryRun: true);
      await api.sendNotification(_draft, dryRun: false);
      expect(fns.calls.map((c) => c.name), everyElement(BackendFunctions.adminSendNotification));
      expect(fns.calls.map((c) => c.timeout), [
        const Duration(seconds: 540),
        const Duration(seconds: 540),
      ]);
      expect(AdminFunctions.sendNotificationTimeout, const Duration(seconds: 540));
      expect([for (final c in fns.calls) (c.data as Map)['dryRun']], [true, false]);
    });
  });

  group('adminUpsertPromoCode (F3, §9.7)', () {
    const draft = PromoCodeDraft(code: 'summer', credits: 2);

    test('a create sends createOnly and returns the created flag', () async {
      final fns = _FakeFunctions()..response = {'ok': true, 'code': 'SUMMER', 'created': true};
      final created = await AdminFunctions(fns).upsertPromoCode(draft, createOnly: true);
      expect(created, isTrue);
      final call = fns.calls.single;
      expect(call.name, BackendFunctions.adminUpsertPromoCode);
      expect(call.data, {
        'code': 'SUMMER',
        'credits': 2,
        'active': true,
        'note': '',
        'createOnly': true,
      });
    });

    test('an edit omits createOnly; created false or missing is reported as such', () async {
      final fns = _FakeFunctions()..response = {'ok': true, 'code': 'SUMMER', 'created': false};
      expect(await AdminFunctions(fns).upsertPromoCode(draft), isFalse);
      expect((fns.calls.single.data as Map).containsKey('createOnly'), isFalse);

      fns.response = {'ok': true, 'code': 'SUMMER'};
      expect(await AdminFunctions(fns).upsertPromoCode(draft), isNull);
      fns.response = null;
      expect(await AdminFunctions(fns).upsertPromoCode(draft), isNull);
    });

    test('isPromoCodeExistsError: VALIDATION_FAILED with details.why exists only', () {
      FirebaseFunctionsException err(Object? details, {String code = 'invalid-argument'}) =>
          FirebaseFunctionsException(code: code, message: 'm', details: details);
      expect(isPromoCodeExistsError(err({'reason': 'VALIDATION_FAILED', 'why': 'exists'})), isTrue);
      expect(isPromoCodeExistsError(err({'reason': 'VALIDATION_FAILED', 'why': 'credits'})), isFalse);
      expect(isPromoCodeExistsError(err({'reason': 'VALIDATION_FAILED'})), isFalse);
      expect(isPromoCodeExistsError(err({'reason': 'FORBIDDEN_ROLE', 'why': 'exists'})), isFalse);
      expect(isPromoCodeExistsError(err(null)), isFalse);
      expect(isPromoCodeExistsError(StateError('exists')), isFalse);
    });
  });

  test('callableDetailsWhy reads details.why', () {
    expect(callableDetailsWhy({'reason': 'VALIDATION_FAILED', 'why': 'exists'}), 'exists');
    expect(callableDetailsWhy({'why': ''}), isNull);
    expect(callableDetailsWhy({'why': 3}), isNull);
    expect(callableDetailsWhy('exists'), isNull);
    expect(callableDetailsWhy(null), isNull);
  });
}
