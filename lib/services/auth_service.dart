import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../data/database_helper.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoggedIn => _currentUser != null;

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _dbHelper.authenticateUser(email, password);
      if (user != null) {
        _currentUser = user;
        await _saveUserSession(user);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register({
    required String nom,
    required String email,
    required String password,
    required UserRole role,
    int? groupeId,
    int? directorId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newUser = User(
        nom: nom,
        email: email,
        password: password,
        role: role,
        groupeId: groupeId,
        directorId: directorId,
      );
      
      final id = await _dbHelper.insertUser(newUser);
      if (id > 0) {
        _currentUser = newUser.copyWith(id: id);
        await _saveUserSession(_currentUser!);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Registration error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    notifyListeners();
  }

  Future<bool> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      
      if (userId != null) {
        final user = await _dbHelper.getUserById(userId);
        if (user != null) {
          _currentUser = user;
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('Session check error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> _saveUserSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', user.id!);
    await prefs.setString('user_email', user.email);
  }

  void updateCurrentUser(User user) {
    _currentUser = user;
    notifyListeners();
  }
}
