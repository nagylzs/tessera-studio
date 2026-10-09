import 'package:url_launcher/url_launcher.dart';

/// Opens a web link in the user's browser — the only network traffic
/// the app starts, and only on the user's tap. Registered in get_it;
/// tests register a fake.
abstract interface class LinkOpener {
  /// Whether a browser took [uri].
  Future<bool> open(Uri uri);
}

/// `url_launcher`, outside the app (the browser keeps its own history
/// and sign-ins, and the app stays as it was).
final class PlatformLinkOpener implements LinkOpener {
  const PlatformLinkOpener();

  @override
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
