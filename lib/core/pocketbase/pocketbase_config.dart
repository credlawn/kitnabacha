class PocketBaseConfig {
  static String get url =>
    const String.fromEnvironment('POCKETBASE_URL', defaultValue: 'http://localhost:8090');
}
