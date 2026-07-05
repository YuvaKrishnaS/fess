import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportLinks {
  SupportLinks._();

  static const String supportEmail = 'fess.in@proton.me';

  static Future<bool> openReportProblem() async {
    final info = await _deviceInfoLine();
    return _launchMail(
      subject: 'Fess - Problem Report',
      body: 'Describe the issue you faced:\n\n\n\n---\n$info',
    );
  }

  static Future<bool> openContactUs() async {
    final info = await _deviceInfoLine();
    return _launchMail(
      subject: 'Fess - Support Request',
      body: 'Hi Fess team,\n\n\n\n---\n$info',
    );
  }

  static Future<String> _deviceInfoLine() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      return 'App version: ${pkg.version} (${pkg.buildNumber})\nPlatform: ${defaultTargetPlatform.name}';
    } catch (_) {
      return 'App version: unknown';
    }
  }

  static Future<bool> _launchMail({
    required String subject,
    required String body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}