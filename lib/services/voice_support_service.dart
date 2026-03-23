import 'package:url_launcher/url_launcher.dart';

class VoiceSupportService {
  // Your Twilio phone number
  static const String supportNumber = '+15077282325';

  static Future<void> callSupport() async {
    final Uri callUri = Uri(
      scheme: 'tel',
      path: supportNumber,
    );

    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    }
  }
} 