import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starblaster/services/iap_service.dart';

void main() {
  test('iOS maps to the single star product', () {
    final ids = StarStore.productIdsFor(TargetPlatform.iOS);
    expect(ids, <String>{'starblasterstar'});
    expect(ids.length, 1);
  });

  test('Android maps to coffee + chocolate', () {
    final ids = StarStore.productIdsFor(TargetPlatform.android);
    expect(ids, <String>{'starblastercoffee', 'starblasterchocolate'});
    expect(ids.length, 2);
  });

  test('star id has no dots or underscores', () {
    expect(StarStore.starId.contains('.'), isFalse);
    expect(StarStore.starId.contains('_'), isFalse);
  });
}
