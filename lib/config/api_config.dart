class ApiConfig {
  // When running on Android emulator, use 10.0.2.2 to reach host machine's localhost.
  // On physical device, set to your machine IP (e.g., 192.168.1.10) or expose via tunneling.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://20.204.177.196:5000',
  );
}
