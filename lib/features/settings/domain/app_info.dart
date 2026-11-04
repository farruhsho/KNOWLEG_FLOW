/// Legal documents. Placeholders on the project's Firebase Hosting domain —
/// the owner must publish real pages at these addresses before release.
abstract final class LegalLinks {
  static const String privacyPolicy = 'https://knowleg-33f36.web.app/privacy';
  static const String termsOfService = 'https://knowleg-33f36.web.app/terms';
}

/// Build information shown in Settings.
///
/// The version comes from the build (`--dart-define=APP_VERSION=1.2.3+45`,
/// e.g. from CI using pubspec's version); the default mirrors pubspec.yaml.
abstract final class AppBuildInfo {
  static const String version =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0+1');
}
