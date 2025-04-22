import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Service for managing server connection settings
class ServerConnectionService {
  // Singleton instance
  static final ServerConnectionService _instance = ServerConnectionService._internal();
  factory ServerConnectionService() => _instance;
  ServerConnectionService._internal();

  // Default server values
  String _serverIp = AppConfig.serverIpConfigurations['default']!;
  int _serverPort = AppConfig.serverPort;

  // Getters
  String get serverIp => _serverIp;
  int get serverPort => _serverPort;
  String get baseUrl => 'http://$_serverIp:$_serverPort';

  /// Initialize the service with the best settings for the current environment
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if there's a saved IP address
      final savedIp = prefs.getString('server_ip');
      if (savedIp != null && savedIp.isNotEmpty) {
        _serverIp = savedIp;
        print('Using saved server IP: $_serverIp');
      } else {
        // Auto-detect environment and set best IP
        _detectEnvironment();
        print('Auto-detected server IP: $_serverIp');
        
        // Save for future use
        await prefs.setString('server_ip', _serverIp);
      }
      
      // Check server port
      final savedPort = prefs.getInt('server_port');
      if (savedPort != null && savedPort > 0) {
        _serverPort = savedPort;
      }
      
    } catch (e) {
      print('Error initializing ServerConnectionService: $e');
      // Fallback to defaults if there's an error
    }
  }

  /// Auto-detect the current environment and set the appropriate IP
  void _detectEnvironment() {
    // Running on Android Emulator
    if (!kIsWeb && Platform.isAndroid && _isEmulator()) {
      _serverIp = AppConfig.serverIpConfigurations['emulator']!;
    } 
    // Running on iOS Simulator
    else if (!kIsWeb && Platform.isIOS && _isSimulator()) {
      _serverIp = AppConfig.serverIpConfigurations['simulator']!;
    }
    // Other environments use the default
  }

  /// Check if running on an Android emulator (basic detection)
  bool _isEmulator() {
    try {
      // Common emulator manufacturer names
      final emulatorBrands = ['google', 'genymotion', 'android sdk built for'];
      final deviceModel = Platform.operatingSystemVersion.toLowerCase();
      
      return emulatorBrands.any((brand) => deviceModel.contains(brand));
    } catch (e) {
      return false;
    }
  }

  /// Check if running on an iOS simulator (basic detection)
  bool _isSimulator() {
    try {
      if (Platform.isIOS) {
        // This is a simplistic check, might need refinement
        if (Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
            Platform.environment.containsKey('SIMULATOR_HOST_HOME')) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Update the server IP address
  Future<void> updateServerIp(String newIp) async {
    try {
      if (newIp.isNotEmpty) {
        _serverIp = newIp;
        
        // Save to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('server_ip', newIp);
        
        print('Server IP updated to: $newIp');
      }
    } catch (e) {
      print('Error updating server IP: $e');
    }
  }

  /// Update the server port
  Future<void> updateServerPort(int newPort) async {
    try {
      if (newPort > 0) {
        _serverPort = newPort;
        
        // Save to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('server_port', newPort);
        
        print('Server port updated to: $newPort');
      }
    } catch (e) {
      print('Error updating server port: $e');
    }
  }

  /// Verify connection to the server
  Future<bool> verifyConnection() async {
    try {
      final response = await HttpClient().getUrl(Uri.parse('$baseUrl/status'))
        .then((request) => request.close())
        .timeout(const Duration(seconds: 5));
        
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print('Server connection failed: $e');
      return false;
    }
  }
}