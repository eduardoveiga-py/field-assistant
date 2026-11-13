import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/sync/native_auth_callback.dart';

void main() {
  test('somente destino esperado com dados de autenticação é aceito, uma vez', () {
    final callback = NativeAuthCallback();
    expect(callback.claim(Uri.parse('https://auth/callback?code=abc')), isFalse);
    expect(callback.claim(Uri.parse('ministeriopessoal://auth/other?code=abc')), isFalse);
    expect(callback.claim(Uri.parse('ministeriopessoal://auth/callback')), isFalse);
    final uri = Uri.parse('ministeriopessoal://auth/callback?code=abc');
    expect(callback.claim(uri), isTrue);
    expect(callback.claim(uri), isFalse);
    expect(callback.claim(Uri.parse('ministeriopessoal://auth/callback#error_code=otp_expired')), isTrue);
  });
}
