import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_transport.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_vault_verifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryVault implements RecoveryVaultTransport {
  Map<String, dynamic>? marker;
  int writes = 0;
  @override
  Future<Map<String, dynamic>?> fetch() async => marker;
  @override
  Future<bool> createIfAbsent(Map<String, dynamic> proposed) async {
    writes++;
    if (marker != null) return false;
    marker = Map<String, dynamic>.from(proposed);
    return true;
  }
}

void main() {
  test('cria uma vez e valida recuperação sem substituir marcador existente', () async {
    final phrase = RecoveryCrypto.createPhrase();
    final key = await RecoveryCrypto.keyFromPhrase(phrase);
    final wrong = await RecoveryCrypto.keyFromPhrase(RecoveryCrypto.createPhrase());
    final marker = await RecoveryVaultVerifier.create(root: key, owner: 'account');
    final id = marker['vaultId'] as String;
    final remote = MemoryVault();
    final setup = RecoveryVaultSetup(owner: 'account', transport: remote);
    await expectLater(setup.fetchVerified(key: key, expectedVaultId: id), throwsStateError);
    await expectLater(setup.createConfirmed(key: wrong, marker: marker, expectedVaultId: id), throwsA(anything));
    await expectLater(setup.createConfirmed(key: key, marker: marker, expectedVaultId: 'wrong'), throwsStateError);
    expect(remote.writes, 0);
    expect(await setup.createConfirmed(key: key, marker: marker, expectedVaultId: id), isTrue);
    final other = await RecoveryVaultVerifier.create(root: key, owner: 'account');
    expect(await setup.createConfirmed(key: key, marker: other, expectedVaultId: other['vaultId'] as String), isFalse);
    expect(await setup.fetchVerified(key: key, expectedVaultId: id), marker);
    await expectLater(setup.fetchVerified(key: key, expectedVaultId: 'wrong'), throwsStateError);
    await expectLater(setup.fetchVerified(key: wrong, expectedVaultId: id), throwsA(anything));
    expect(remote.marker, marker);
  });

  test('adaptador recusa rede sem sessão da conta esperada', () async {
    var requests = 0;
    final client = SupabaseClient('https://example.supabase.co', 'dummy-key', httpClient: MockClient((request) async {
      requests++;
      return http.Response('{}', 200);
    }));
    final transport = SupabaseRecoveryVaultTransport(client: client, owner: 'account');
    await expectLater(transport.fetch(), throwsStateError);
    await expectLater(transport.createIfAbsent({}), throwsStateError);
    expect(requests, 0);
    client.dispose();
  });
}
