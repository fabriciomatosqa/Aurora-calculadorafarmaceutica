package br.com.aurora.aurora_calculadora_farmaceutica

import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

/** Fail-closed APK identity verification before the Android installer opens.
 * The package manager always performs its own definitive signature checks.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aurora/android_update")
            .setMethodCallHandler { call, result ->
                if (call.method != "validateApk") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val path = call.argument<String>("path")
                        ?: throw IllegalArgumentException("Caminho do APK ausente.")
                    val versionCode = call.argument<Int>("versionCode")
                        ?: throw IllegalArgumentException("Versão do APK ausente.")
                    val packageName = call.argument<String>("packageName")
                        ?: throw IllegalArgumentException("Identificador do APK ausente.")
                    verifyArchive(path, versionCode.toLong(), packageName)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INCOMPATIBLE_APK",
                        e.message ?: "O APK não é compatível com a instalação atual.", null)
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun verifyArchive(path: String, expectedCode: Long, expectedPackage: String) {
        if (!File(path).isFile) throw IllegalArgumentException("O arquivo APK não existe.")
        val pm = packageManager
        val flags = if (Build.VERSION.SDK_INT >= 28)
            PackageManager.GET_SIGNING_CERTIFICATES
        else
            PackageManager.GET_SIGNATURES

        val archive = pm.getPackageArchiveInfo(path, flags)
            ?: throw IllegalArgumentException("O arquivo baixado não é um APK Android válido.")
        val installed = pm.getPackageInfo(packageName, flags)
        if (expectedPackage != packageName || archive.packageName != packageName) {
            throw IllegalArgumentException("O APK pertence a outro aplicativo.")
        }
        val archiveCode = if (Build.VERSION.SDK_INT >= 28)
            archive.longVersionCode else archive.versionCode.toLong()
        val installedCode = if (Build.VERSION.SDK_INT >= 28)
            installed.longVersionCode else installed.versionCode.toLong()
        if (archiveCode != expectedCode || archiveCode <= installedCode) {
            throw IllegalArgumentException("O APK não é uma versão mais recente e compatível.")
        }
        if (Build.VERSION.SDK_INT >= 24 &&
            (archive.applicationInfo?.minSdkVersion ?: Int.MAX_VALUE) > Build.VERSION.SDK_INT) {
            throw IllegalArgumentException("Esta versão exige uma versão mais recente do Android.")
        }

        val installedCerts = fingerprints(installed)
        val archiveCerts = fingerprints(archive)
        if (installedCerts.isEmpty() || installedCerts != archiveCerts) {
            throw IllegalArgumentException(
                "Assinatura incompatível com o aplicativo instalado. " +
                "Um APK assinado por outra chave não pode ser instalado por cima. " +
                "Não desinstale sem preservar os dados locais."
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun fingerprints(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= 28)
            info.signingInfo?.apkContentsSigners?.toList()
        else
            info.signatures?.toList()
        return signatures?.map {
            MessageDigest.getInstance("SHA-256")
                .digest(it.toByteArray())
                .joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
        }?.toSet() ?: emptySet()
    }
}
