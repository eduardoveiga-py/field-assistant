import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/sync/sync_privacy_policy.dart';

void main() {
  const requested = bool.fromEnvironment('FA_ENABLE_UNSAFE_LOCAL_TEST_SYNC');
  const accepted = bool.fromEnvironment('FA_ACK_TEST_DATA_MAY_BE_LOST');
  const expected = kDebugMode && !kIsWeb && requested && accepted;

  test('local test mode requires both explicit flags and native debug', () {
    expect(SyncPrivacyPolicy.localTestBuildEnabled, expected);
    expect(
      SyncPrivacyPolicy.canRunRemoteSync(
        verifiedLocalClientUrl: 'http://127.0.0.1:54321',
      ),
      expected,
    );
    expect(SyncPrivacyPolicy.canRunRemoteSync(), isFalse);
    expect(SyncPrivacyPolicy.mediaProtocolVerified, isFalse);
    expect(SyncPrivacyPolicy.isCloudSyncEnabled, isFalse);
  });

  test('only literal loopback endpoint is accepted', () {
    for (final url in [
      'http://127.0.0.1:54321',
      'http://127.0.0.1:54321/',
    ]) {
      expect(SyncPrivacyPolicy.isLocalTestEndpoint(url), isTrue);
      expect(
        SyncPrivacyPolicy.canRunRemoteSync(verifiedLocalClientUrl: url),
        expected,
      );
    }
    for (final url in [
      '',
      'http://localhost:54321',
      'http://127.0.0.2:54321',
      'http://127.0.0.1:54322',
      'https://127.0.0.1:54321',
      'http://127.0.0.1:54321/path',
      'http://127.0.0.1:54321?forward=remote',
      'http://127.0.0.1:54321/#fragment',
      'http://127.0.0.1:54321@host.example',
      'http://remote.example:54321',
      'http://[::1]:54321',
    ]) {
      expect(SyncPrivacyPolicy.isLocalTestEndpoint(url), isFalse, reason: url);
      expect(
        SyncPrivacyPolicy.canRunRemoteSync(verifiedLocalClientUrl: url),
        isFalse,
        reason: url,
      );
    }
  });
}
