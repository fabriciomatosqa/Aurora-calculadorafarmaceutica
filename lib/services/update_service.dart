import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Canal oficial de distribuição embutido no aplicativo.
/// O código-fonte permanece privado; somente APKs assinados são públicos.
/// Nenhuma configuração, login ou token é solicitado a quem usa o AURORA.
const officialUpdateRepository =
    'fabriciomatosqa/aurora-calculadora-farmaceutica-updates';

Uri officialReleaseEndpoint() => Uri.https(
      'api.github.com',
      '/repos/$officialUpdateRepository/releases/latest',
    );

class AppRelease {
  const AppRelease({
    required this.version,
    required this.description,
    required this.pageUrl,
    required this.apkUrl,
    required this.sha256Url,
    this.digest,
    this.size = 0,
  });

  final String version;
  final String description;
  final Uri pageUrl;
  final Uri? apkUrl;
  final Uri? sha256Url;
  final String? digest;
  final int size;
}

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Numeric semantic comparison; supports version tags v1.2.3 and build suffixes.
/// Malformed remote versions fail closed rather than offering unknown software.
int compareVersions(String a, String b) {
  List<int> parts(String value) {
    final match = RegExp(r'^v?(\d+(?:\.\d+){0,3})(?:\+\d+)?$')
        .firstMatch(value.trim());
    if (match == null) throw const UpdateException('Versão remota inválida.');
    return match.group(1)!.split('.').map(int.parse).toList();
  }

  final left = parts(a);
  final right = parts(b);
  for (var i = 0; i < 4; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

Uri _secureUrl(String raw, {bool githubAsset = false}) {
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'https' ||
      (githubAsset && uri.host != 'github.com')) {
    throw const UpdateException('Link de atualização inseguro ou inválido.');
  }
  return uri;
}

AppRelease parseRelease(Map<String, dynamic> json) {
  final tag = json['tag_name'];
  final page = json['html_url'];
  final assets = json['assets'];
  if (tag is! String || page is! String || assets is! List) {
    throw const UpdateException('Resposta de atualização incompleta.');
  }
  compareVersions(tag, tag); // validate version early
  final apkName = 'aurora-calculadora-farmaceutica-${tag.replaceFirst(RegExp(r'^v'), 'v')}-android.apk';
  Map<String, dynamic>? apk;
  Map<String, dynamic>? checksum;
  for (final item in assets) {
    if (item is! Map<String, dynamic>) continue;
    if (item['name'] == apkName) apk = item;
    if (item['name'] == '$apkName.sha256') checksum = item;
  }
  Uri? assetUrl(Map<String, dynamic>? asset) {
    if (asset == null) return null;
    final url = asset['browser_download_url'];
    if (url is! String) throw const UpdateException('Asset sem link de download.');
    return _secureUrl(url, githubAsset: true);
  }
  final sha = apk?['digest'];
  return AppRelease(
    version: tag.replaceFirst(RegExp(r'^v'), ''),
    description: (json['body'] as String?) ?? '',
    pageUrl: _secureUrl(page, githubAsset: true),
    apkUrl: assetUrl(apk),
    sha256Url: assetUrl(checksum),
    digest: sha is String && RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(sha)
        ? sha.substring(7).toLowerCase() : null,
    size: apk?['size'] is int ? apk!['size'] as int : 0,
  );
}

class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _maxApkBytes = 150 * 1024 * 1024;
  static const _timeout = Duration(seconds: 20);

  void dispose() => _client.close();

  Future<String> installedVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  Future<AppRelease?> latestAvailable() async {
    final current = await installedVersion();
    final uri = officialReleaseEndpoint();
    final response = await _client.get(uri, headers: {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'AURORA-Calculadora-Farmaceutica',
    }).timeout(_timeout);

    if (response.statusCode == 404) {
      throw const UpdateException(
        'O canal oficial de atualizações ainda não disponibiliza um '
        'Release público. Tente novamente mais tarde.',
      );
    }
    if (response.statusCode != 200) {
      throw UpdateException('GitHub indisponível (HTTP ${response.statusCode}).');
    }
    final parsed = jsonDecode(response.body);
    if (parsed is! Map<String, dynamic>) {
      throw const UpdateException('Dados de versão inválidos.');
    }
    final release = parseRelease(parsed);
    if (compareVersions(release.version, current) <= 0) return null;
    if (release.apkUrl == null) {
      throw const UpdateException('Release não contém APK Android compatível.');
    }
    return release;
  }

  /// Download is verified against GitHub's asset SHA-256 or a .sha256 asset.
  /// Never invoke Android's package installer for an unverified download.
  Future<File> downloadVerifiedApk(AppRelease release,
      {void Function(int received, int total)? onProgress}) async {
    if (!Platform.isAndroid) {
      throw const UpdateException('Instalação por APK disponível apenas no Android.');
    }
    final url = release.apkUrl;
    if (url == null) {
      throw const UpdateException('A versão não contém APK compatível.');
    }
    String? expectedSha = release.digest;
    if (expectedSha == null) {
      final checksumUrl = release.sha256Url;
      if (checksumUrl == null) {
        throw const UpdateException('Release sem checksum SHA-256. Download bloqueado.');
      }
      final checksum = await _client.get(checksumUrl).timeout(_timeout);
      if (checksum.statusCode != 200) {
        throw const UpdateException('Não foi possível obter o checksum SHA-256.');
      }
      final value = checksum.body.trim().split(RegExp(r'\s+')).first.toLowerCase();
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
        throw const UpdateException('Checksum inválido.');
      }
      expectedSha = value;
    }
    if (release.size > _maxApkBytes) {
      throw const UpdateException('APK ultrapassa o limite de segurança.');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/aurora-update-${release.version}.apk');
    final request = http.Request('GET', url);
    final response = await _client.send(request).timeout(_timeout);
    if (response.statusCode != 200) {
      throw UpdateException('Falha no download (HTTP ${response.statusCode}).');
    }
    final sink = file.openWrite();
    var received = 0;
    var sinkClosed = false;
    try {
      await for (final chunk in response.stream.timeout(_timeout)) {
        received += chunk.length;
        if (received > _maxApkBytes) {
          throw const UpdateException('Download maior que o permitido.');
        }
        sink.add(chunk);
        onProgress?.call(received, release.size);
      }
      await sink.flush();
      await sink.close();
      sinkClosed = true;
      final checksum = await sha256.bind(file.openRead()).first;
      if (checksum.toString().toLowerCase() != expectedSha) {
        throw const UpdateException('Verificação SHA-256 falhou. APK descartado.');
      }
      return file;
    } catch (_) {
      if (!sinkClosed) await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<void> requestInstallation(File apk) async {
    if (!Platform.isAndroid) {
      throw const UpdateException('O iOS não permite instalar um APK.');
    }
    final result = await OpenFilex.open(
      apk.path, type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw UpdateException(
        'O instalador não foi aberto: ${result.message}. '
        'Verifique a autorização para instalar apps desta origem.',
      );
    }
  }
}
