import 'package:webdev_proxy/webdev_proxy.dart';
import 'package:test/test.dart';

// Simple testing.
//
// Cannot do more real testing without a HttpRequest object.

void main() {
  group('respondFromBuild', () {
    test('null directory rejected', () {
      expect(() => respondFromBuild(null, null),
          throwsA(const TypeMatcher<ArgumentError>()));
    });

    test('empty string for directory rejected', () {
      expect(() => respondFromBuild(null, ''),
          throwsA(const TypeMatcher<ArgumentError>()));
    });

    test('relative directory rejected', () {
      expect(() => respondFromBuild(null, '../build'),
          throwsA(const TypeMatcher<ArgumentError>()));
    });
  });

  group('respondFromServe', () {
    test('null Uri rejected', () {
      expect(() => respondFromServe(null, null),
          throwsA(const TypeMatcher<ArgumentError>()));
    });
  });
}
