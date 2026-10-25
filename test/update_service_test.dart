import 'package:aurora_calculadora_farmaceutica/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Utiliza diretamente o repositório oficial público', () {
    expect(updateRepository, 'fabriciomatosqa/Aurora-calculadorafarmaceutica');
  });

  test('Consulta uma Release pública maior que a versão instalada', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://api.github.com/repos/'
        'fabriciomatosqa/Aurora-calculadorafarmaceutica/releases/latest',
      );
      return http.Response(jsonEncode({
        'tag_name': 'v0.5.0',
        'html_url': 'https://github.com/fabriciomatosqa/Aurora-calculadorafarmaceutica/releases/tag/v0.5.0',
        'body': 'Correções Android',
        'assets': [
          {
            'name': 'aurora-calculadora-farmaceutica-v0.5.0-android.apk',
            'browser_download_url': 'https://github.com/fabriciomatosqa/Aurora-calculadorafarmaceutica/releases/download/v0.5.0/aurora-calculadora-farmaceutica-v0.5.0-android.apk',
            'digest': 'sha256:${List.filled(64, 'a').join()}',
            'size': 14000000,
          },
        ],
      }), 200);
    });
    final service = UpdateService(
      client: client,
      installedVersionOverride: '0.4.0',
    );
    addTearDown(service.dispose);
    final release = await service.latestAvailable();
    expect(release?.version, '0.5.0');
    expect(release?.apkUrl, isNotNull);
    expect(release?.digest, List.filled(64, 'a').join());
  });

  test('Não oferece versão mais antiga ou igual', () async {
    final client = MockClient((request) async => http.Response(jsonEncode({
      'tag_name': 'v0.4.0',
      'html_url': 'https://github.com/fabriciomatosqa/Aurora-calculadorafarmaceutica/releases/tag/v0.4.0',
      'assets': <Object>[],
    }), 200));
    final service = UpdateService(
      client: client,
      installedVersionOverride: '0.5.0',
    );
    addTearDown(service.dispose);
    expect(await service.latestAvailable(), isNull);
  });

  test('Sem Release público informa o motivo ao usuário', () async {
    final client = MockClient((request) async => http.Response('{"message":"Not Found"}', 404));
    final service = UpdateService(
      client: client,
      installedVersionOverride: '0.4.0',
    );
    addTearDown(service.dispose);
    expect(() => service.latestAvailable(),
        throwsA(isA<UpdateException>()));
  });

  test('Compara versões numericamente e ignora prefixo v', () {
    expect(compareVersions('v0.2.0', '0.1.0'), greaterThan(0));
    expect(compareVersions('1.10.0', '1.9.9'), greaterThan(0));
    expect(compareVersions('1.0.0', '1.0.0'), 0);
    expect(compareVersions('1.0.0', '2.0.0'), lessThan(0));
    expect(() => compareVersions('malicious', '1.0.0'),
      throwsA(isA<UpdateException>()));
  });

  test('Interpreta release e APK oficial com checksum', () {
    final release = parseRelease({
      'tag_name': 'v0.3.0',
      'html_url': 'https://github.com/fabriciomatosqa/Aurora-calculadorafarmaceutica/releases/tag/v0.3.0',
      'body': 'Mudanças',
      'assets': [
        {
          'name': 'aurora-calculadora-farmaceutica-v0.3.0-android.apk',
          'browser_download_url': 'https://github.com/fabriciomatosqa/Aurora-calculadorafarmaceutica/releases/download/v0.3.0/aurora-calculadora-farmaceutica-v0.3.0-android.apk',
          'size': 20000000,
          'digest': 'sha256:${List<String>.filled(64, 'a').join()}',
        },
      ],
    });
    expect(release.version, '0.3.0');
    expect(release.apkUrl, isNotNull);
    expect(release.digest, List<String>.filled(64, 'a').join());
    expect(release.size, 20000000);
  });

  test('Rejeita endpoints não HTTPS ou fora do GitHub', () {
    expect(() => parseRelease({
      'tag_name': 'v1.0.0',
      'html_url': 'http://github.com/evil',
      'assets': <Object>[],
    }), throwsA(isA<UpdateException>()));
  });

  test('Release sem APK é reconhecido como indisponível para Android', () {
    final release = parseRelease({
      'tag_name': 'v1.1.0',
      'html_url': 'https://github.com/owner/repo/releases/tag/v1.1.0',
      'assets': <Object>[],
    });
    expect(release.apkUrl, isNull);
  });
}
