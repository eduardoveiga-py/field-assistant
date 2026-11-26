import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'web_key_persistence.dart';

extension type _IdbKeyRecord._(JSObject _) implements JSObject {
  external factory _IdbKeyRecord({
    String mode,
    web.CryptoKey? kek,
    String? iv,
    String? ciphertext,
    String? envelopeJson,
  });

  external String? get mode;
  external web.CryptoKey? get kek;
  external String? get iv;
  external String? get ciphertext;
  external String? get envelopeJson;
}

/// Persistência segura no navegador via IndexedDB + WebCrypto (`extractable: false`).
/// Nunca grava a frase mnemônica de 24 palavras; armazena apenas o `CryptoKey` não-extraível
/// encapsulando os 32 bytes da chave derivada AES-GCM (ou envelope protegido por PIN PBKDF2).
class BrowserWebKeyPersistenceAdapter implements WebKeyPersistenceAdapter {
  static const String _dbName = 'field_assistant_e2ee_keystore';
  static const int _dbVersion = 1;
  static const String _storeName = 'keys';

  final WebPinKeyWrapper pinWrapper;

  const BrowserWebKeyPersistenceAdapter({
    this.pinWrapper = const WebPinKeyWrapper(),
  });

  web.SubtleCrypto _requireSubtle() {
    if (!web.window.isSecureContext) {
      throw StateError(
        'Persistência E2EE na Web exige HTTPS ou localhost (contexto seguro).',
      );
    }
    return web.window.crypto.subtle;
  }

  Future<web.IDBDatabase> _openDb() {
    final completer = Completer<web.IDBDatabase>();
    final req = web.window.indexedDB.open(_dbName, _dbVersion);

    req.onupgradeneeded = ((web.IDBVersionChangeEvent _) {
      final db = req.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    }).toJS;

    req.onsuccess = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.complete(req.result as web.IDBDatabase);
      }
    }).toJS;

    req.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Falha ao abrir IndexedDB E2EE: ${req.error?.message ?? "erro desconhecido"}',
          ),
        );
      }
    }).toJS;

    return completer.future;
  }

  Future<_IdbKeyRecord?> _getRecord(String storageKey) async {
    final db = await _openDb();
    try {
      final tx = db.transaction(_storeName.toJS, 'readonly');
      final store = tx.objectStore(_storeName);
      final req = store.get(storageKey.toJS);
      final completer = Completer<_IdbKeyRecord?>();

      req.onsuccess = ((web.Event _) {
        if (!completer.isCompleted) {
          final res = req.result;
          completer.complete(res as _IdbKeyRecord?);
        }
      }).toJS;

      req.onerror = ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError(
              'Falha ao ler IndexedDB E2EE: ${req.error?.message ?? "erro"}',
            ),
          );
        }
      }).toJS;

      return await completer.future;
    } finally {
      db.close();
    }
  }

  Future<void> _putRecord(String storageKey, _IdbKeyRecord record) async {
    final db = await _openDb();
    try {
      final completer = Completer<void>();
      final tx = db.transaction(_storeName.toJS, 'readwrite');
      tx.oncomplete = ((web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }).toJS;
      tx.onerror = ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError(
              'Falha ao gravar IndexedDB E2EE: ${tx.error?.message ?? "erro"}',
            ),
          );
        }
      }).toJS;
      tx.objectStore(_storeName).put(record, storageKey.toJS);
      await completer.future;
    } finally {
      db.close();
    }
  }

  Uint8List _aadBytes(String owner, String storageKey) => Uint8List.fromList(
    utf8.encode(
      jsonEncode(['field-assistant', 'web-keystore', 1, owner, storageKey]),
    ),
  );

  Uint8List _randomIv12() {
    final rng = Random.secure();
    return Uint8List.fromList(List<int>.generate(12, (_) => rng.nextInt(256)));
  }

  @override
  Future<bool> hasStoredEntry(String storageKey) async {
    final rec = await _getRecord(storageKey);
    return rec != null;
  }

  @override
  Future<bool> isPinLocked(String storageKey) async {
    final rec = await _getRecord(storageKey);
    return rec != null && rec.mode == 'pin';
  }

  @override
  Future<Uint8List?> readKey(String storageKey, String owner) async {
    final rec = await _getRecord(storageKey);
    if (rec == null) return null;
    final mode = rec.mode;
    if (mode == 'pin') {
      throw const WebPinLockedException();
    }
    if (mode != 'persistent' ||
        rec.kek == null ||
        rec.iv == null ||
        rec.ciphertext == null) {
      throw const FormatException('Registro E2EE no navegador corrompido.');
    }

    final subtle = _requireSubtle();
    try {
      final ivBytes = Uint8List.fromList(base64Decode(rec.iv!));
      final ctBytes = Uint8List.fromList(base64Decode(rec.ciphertext!));
      final aad = _aadBytes(owner, storageKey);
      final alg = <String, Object?>{
        'name': 'AES-GCM',
        'iv': ivBytes,
        'additionalData': aad,
      }.jsify()!;

      final plainAny = await subtle.decrypt(alg, rec.kek!, ctBytes.toJS).toDart;
      final buf = plainAny! as JSArrayBuffer;
      final out = buf.toDart.asUint8List();
      if (out.length != 32) {
        throw const FormatException(
          'Chave E2EE restaurada no navegador com tamanho inválido.',
        );
      }
      return Uint8List.fromList(out);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException(
        'Falha ao descriptografar chave E2EE neste navegador: $e',
      );
    }
  }

  @override
  Future<void> writePersistentKey(
    String storageKey,
    String owner,
    Uint8List keyBytes,
  ) async {
    if (keyBytes.length != 32) {
      throw ArgumentError.value(keyBytes.length, 'keyBytes', 'Esperado 32B.');
    }
    final subtle = _requireSubtle();
    final genAlg = <String, Object?>{'name': 'AES-GCM', 'length': 256}.jsify()!;
    final usages = ['encrypt'.toJS, 'decrypt'.toJS].toJS;
    final kekAny = await subtle.generateKey(genAlg, false, usages).toDart;
    final kek = kekAny! as web.CryptoKey;

    final iv = _randomIv12();
    final aad = _aadBytes(owner, storageKey);
    final encAlg = <String, Object?>{
      'name': 'AES-GCM',
      'iv': iv,
      'additionalData': aad,
    }.jsify()!;

    final cipherAny = await subtle.encrypt(encAlg, kek, keyBytes.toJS).toDart;
    final cipherBuf = cipherAny! as JSArrayBuffer;
    final cipherBytes = cipherBuf.toDart.asUint8List();

    await _putRecord(
      storageKey,
      _IdbKeyRecord(
        mode: 'persistent',
        kek: kek,
        iv: base64Encode(iv),
        ciphertext: base64Encode(cipherBytes),
      ),
    );
  }

  @override
  Future<void> writePinProtectedKey(
    String storageKey,
    String owner,
    Uint8List keyBytes,
    String pin,
  ) async {
    final envelope = await pinWrapper.wrap(
      owner: owner,
      storageKey: storageKey,
      keyBytes: keyBytes,
      pin: pin,
    );
    await _putRecord(
      storageKey,
      _IdbKeyRecord(mode: 'pin', envelopeJson: jsonEncode(envelope)),
    );
  }

  @override
  Future<Uint8List> unlockWithPin(
    String storageKey,
    String owner,
    String pin,
  ) async {
    final rec = await _getRecord(storageKey);
    if (rec == null) {
      throw StateError('Nenhuma chave E2EE salva neste navegador.');
    }
    if (rec.mode != 'pin') {
      final key = await readKey(storageKey, owner);
      if (key == null) {
        throw StateError('Nenhuma chave E2EE encontrada neste navegador.');
      }
      return key;
    }
    if (rec.envelopeJson == null) {
      throw const FormatException('Envelope de PIN Web ausente ou corrompido.');
    }
    final decoded = jsonDecode(rec.envelopeJson!);
    if (decoded is! Map) {
      throw const FormatException('Envelope de PIN Web inválido.');
    }
    return pinWrapper.unwrap(
      owner: owner,
      storageKey: storageKey,
      envelope: Map<String, dynamic>.from(decoded),
      pin: pin,
    );
  }

  @override
  Future<void> copyEntry({
    required String fromStorageKey,
    required String fromOwner,
    required String toStorageKey,
    required String toOwner,
  }) async {
    final rec = await _getRecord(fromStorageKey);
    if (rec == null) return;
    if (rec.mode == 'persistent') {
      final key = await readKey(fromStorageKey, fromOwner);
      if (key != null) {
        await writePersistentKey(toStorageKey, toOwner, key);
      }
    } else if (rec.mode == 'pin' && rec.envelopeJson != null) {
      await _putRecord(
        toStorageKey,
        _IdbKeyRecord(mode: 'pin', envelopeJson: rec.envelopeJson),
      );
    }
  }

  @override
  Future<void> deleteKey(String storageKey) async {
    final db = await _openDb();
    try {
      final completer = Completer<void>();
      final tx = db.transaction(_storeName.toJS, 'readwrite');
      tx.oncomplete = ((web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }).toJS;
      tx.onerror = ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError(
              'Falha ao apagar chave E2EE do IndexedDB: ${tx.error?.message ?? "erro"}',
            ),
          );
        }
      }).toJS;
      tx.objectStore(_storeName).delete(storageKey.toJS);
      await completer.future;
    } finally {
      db.close();
    }
  }
}

WebKeyPersistenceAdapter createPlatformWebKeyPersistence({
  WebKeyPersistenceAdapter? override,
}) {
  return override ?? const BrowserWebKeyPersistenceAdapter();
}
