import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let storageSecurityChannelName =
    "com.ministeriopessoal.ministerioPessoal/storage_security"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    protectSensitiveLocalStorage()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "StorageSecurityPlugin") {
      let channel = FlutterMethodChannel(
        name: Self.storageSecurityChannelName,
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "protectStorage":
          let protectedCount = self?.protectSensitiveLocalStorage() ?? 0
          result(["protectedCount": protectedCount])
        case "excludePathFromBackup":
          guard let args = call.arguments as? [String: Any],
                let path = args["path"] as? String,
                !path.isEmpty else {
            result(
              FlutterError(
                code: "INVALID_ARGS",
                message: "Caminho obrigatório para exclusão de backup iOS.",
                details: nil
              )
            )
            return
          }
          let ok = self?.applyProtectionAndExcludeFromBackup(at: URL(fileURLWithPath: path)) ?? false
          result(ok)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  /// Aplica NSFileProtectionCompleteUntilFirstUserAuthentication e isExcludedFromBackup = true no banco SQLite
  /// (incluindo WAL/SHM), diretórios de anexos, mídias e backups locais do dispositivo
  /// para evitar vazamento em iCloud Backup / iTunes não criptografado (FA-SEC-06).
  @discardableResult
  private func protectSensitiveLocalStorage() -> Int {
    let fm = FileManager.default
    guard let docsUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
      return 0
    }

    let sensitiveTargets: [URL] = [
      docsUrl.appendingPathComponent("ministerio_pessoal.sqlite"),
      docsUrl.appendingPathComponent("ministerio_pessoal.sqlite-wal"),
      docsUrl.appendingPathComponent("ministerio_pessoal.sqlite-shm"),
      docsUrl.appendingPathComponent("ministerio_pessoal.sqlite.pre_enc.bak"),
      docsUrl.appendingPathComponent("voice_notes"),
      docsUrl.appendingPathComponent("ticuna_audio"),
      docsUrl.appendingPathComponent("knowledge_vault"),
      docsUrl.appendingPathComponent("person_photos"),
      docsUrl.appendingPathComponent("backups"),
      docsUrl.appendingPathComponent("safety_staging"),
      docsUrl.appendingPathComponent("safety_audio_backup"),
      docsUrl.appendingPathComponent("mbtiles"),
    ]

    var protectedCount = 0
    for target in sensitiveTargets {
      if fm.fileExists(atPath: target.path) {
        if applyProtectionAndExcludeFromBackup(at: target) {
          protectedCount += 1
        }
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: target.path, isDirectory: &isDir), isDir.boolValue,
           let enumerator = fm.enumerator(
             at: target,
             includingPropertiesForKeys: nil,
             options: [.skipsHiddenFiles]
           ) {
          for case let childUrl as URL in enumerator {
            if applyProtectionAndExcludeFromBackup(at: childUrl) {
              protectedCount += 1
            }
          }
        }
      }
    }
    return protectedCount
  }

  @discardableResult
  private func applyProtectionAndExcludeFromBackup(at url: URL) -> Bool {
    var target = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    do {
      try target.setResourceValues(values)
    } catch {
      return false
    }
    do {
      try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
        ofItemAtPath: target.path
      )
    } catch {
      // Alguns diretórios/arquivos podem rejeitar atributo se o dispositivo ainda
      // estiver em transição; isExcludedFromBackup já foi aplicado acima.
    }
    return true
  }
}
