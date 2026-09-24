class ApiConfig {
  const ApiConfig._();

  // Android emulator -> your Windows host machine.
  // For a physical phone, replace 10.0.2.2 with your computer's LAN IP.
  static const String baseUrl = 'http://10.0.2.2:8000';

  static const String psgcBase = '$baseUrl/api/psgc';
}
