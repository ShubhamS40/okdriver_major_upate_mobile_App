class ApiConfig {
  // Base URL for all API calls
  // Change this IP address to update all API endpoints at once
  static const String baseUrl = 'http://localhost:5000';

  // API Endpoints
  static const String healthCheck = '/';

  // Driver Authentication Endpoints
  static const String sendOtp = '/api/driver/send-otp';
  static const String verifyOtp = '/api/driver/verify-otp';
  static const String driverRegister = '/api/drivers/register';
  static const String driverLogout = '/api/driver/auth/logout';
  static const String getCurrentDriver = '/api/driver/auth/current';

  // Company Authentication Endpoints
  static const String companyLogin = '/api/company/login';
  static const String companyRegister = '/api/company/register';

  // Admin Endpoints
  static const String adminLogin = '/api/admin/auth/login';
  static const String adminRegister = '/api/admin/auth/register';

  // Helper method to get full URL
  static String getUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }

  // Helper method to get health check URL
  static String get healthCheckUrl => getUrl(healthCheck);

  // Helper method to get send OTP URL
  static String get sendOtpUrl => getUrl(sendOtp);

  // Helper method to get verify OTP URL
  static String get verifyOtpUrl => getUrl(verifyOtp);

  // Helper method to get driver register URL
  static String get driverRegisterUrl => getUrl(driverRegister);

  // Helper method to get driver logout URL
  static String get driverLogoutUrl => getUrl(driverLogout);

  // Helper method to get current driver URL
  static String get currentDriverUrl => getUrl(getCurrentDriver);
}
