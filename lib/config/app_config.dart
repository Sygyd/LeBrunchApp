/// Configuration for different environments
/// 
/// This file contains configurations for running the app in different environments.
/// Modify these settings based on where you're running the app.

class AppConfig {
  /// Server IP Configuration
  /// 
  /// - Use 10.0.2.2 for Android emulator
  /// - Use localhost or 127.0.0.1 for iOS simulator
  /// - Use your computer's actual IP address when testing on physical devices
  /// - When running on a device connected to the same network as your Docker server,
  ///   use the IP address of the machine running Docker.
  static const serverIpConfigurations = {
    'emulator': '10.0.2.2',         // For Android emulator
    'simulator': 'localhost',       // For iOS simulator
    'default': '192.168.1.121',     // Current default, change as needed
    'docker': 'host.docker.internal' // For running inside Docker
  };
  
  /// Server port
  static const serverPort = 3000;
  
  /// Get server URL based on environment
  static String getServerUrl({String env = 'default'}) {
    final ip = serverIpConfigurations[env] ?? serverIpConfigurations['default']!;
    return 'http://$ip:$serverPort';
  }
  
  /// Change this to your current environment
  static const currentEnvironment = 'default';
  
  /// Get base URL for API calls
  static String get baseUrl => getServerUrl(env: currentEnvironment);
}