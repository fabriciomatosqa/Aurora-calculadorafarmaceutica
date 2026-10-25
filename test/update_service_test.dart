import 'package:aurora_calculadora_farmaceutica/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('O canal oficial é fixo e dispensa configuração do usuário', () {
    expect(officialUpdateRepository,
        'fabriciomatosqa/aurora-calculadora-farmaceutica-updates');
    expect(
      officialReleaseEndpoint().toString(),
      'https://api.github.com/repos/'
      'fabriciomatosqa/aurora-calculadora-farmaceutica-updates/releases/latest',
    );
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

  test('Release sem APK pode apresentar novidades no iOS', () {
    final release = parseRelease({
      'tag_name': 'v1.1.0',
      'html_url': 'https://github.com/owner/repo/releases/tag/v1.1.0',
      'assets': <Object>[],
    });
    expect(release.apkUrl, isNull);
  });
}
