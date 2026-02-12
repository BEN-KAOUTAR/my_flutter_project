import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/user.dart';

class NotificationProvider with ChangeNotifier {
  int _unreadMessageCount = 0;
  int _unreadNotificationCount = 0;
  int _unreadReclamationsCount = 0;
  int _pendingPresenceValidationsCount = 0;
  int _unreadInscriptionRequestsCount = 0;
  int _unreadNotesCount = 0;
  int _pendingSeanceValidationsCount = 0;
  
  int get unreadMessageCount => _unreadMessageCount;
  int get unreadNotificationCount => _unreadNotificationCount;
  int get unreadReclamationsCount => _unreadReclamationsCount;
  int get pendingPresenceValidationsCount => _pendingPresenceValidationsCount;
  int get unreadInscriptionRequestsCount => _unreadInscriptionRequestsCount;
  int get unreadNotesCount => _unreadNotesCount;
  int get pendingSeanceValidationsCount => _pendingSeanceValidationsCount;
  
  int get totalCount => _unreadMessageCount + _unreadNotificationCount + 
                        _unreadReclamationsCount + _pendingPresenceValidationsCount +
                        _unreadInscriptionRequestsCount + _unreadNotesCount +
                        _pendingSeanceValidationsCount;

  Future<void> refreshCounts(User? user) async {
    if (user == null) {
      _resetCounts();
      return;
    }

    try {
      final db = DatabaseHelper.instance;
      
      _unreadMessageCount = await db.getTotalUnreadMessageCount(user.id!);
      _unreadNotificationCount = await db.getUnreadNotificationsCount(user.id!);
      
      if (user.role == UserRole.dp) {
        _unreadReclamationsCount = await db.getUnreadReclamationsCount(directorId: user.id);
        _pendingPresenceValidationsCount = await db.getPendingPresenceValidationsCount(directorId: user.id);
        _unreadInscriptionRequestsCount = await db.getPendingUserRequestsCount(user.id!);
        _unreadNotesCount = await db.getUnvalidatedNotesCount(directorId: user.id);
        
        final dynamicStats = await db.getGlobalStats(directorId: user.id);
        _pendingSeanceValidationsCount = dynamicStats['seancesEnAttente'] ?? 0;
      } else if (user.role == UserRole.stagiaire) {
        _unreadReclamationsCount = await db.getUnreadNotificationsCountByType(user.id!, 'RECLAMATION');
        _unreadNotesCount = await db.getUnreadNotificationsCountByType(user.id!, 'NOTE');
        _pendingPresenceValidationsCount = 0;
        _unreadInscriptionRequestsCount = 0;
      } else if (user.role == UserRole.formateur) {
        _unreadReclamationsCount = await db.getUnreadNotificationsCountByType(user.id!, 'RECLAMATION');
        _unreadNotesCount = 0;
        _pendingPresenceValidationsCount = 0;
        _unreadInscriptionRequestsCount = 0;
      } else {
        _unreadReclamationsCount = 0;
        _pendingPresenceValidationsCount = 0;
        _unreadInscriptionRequestsCount = 0;
        _unreadNotesCount = 0;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing notification counts: $e');
    }
  }

  Future<void> markPresencesAsSeen(User? user) async {
    try {
      await DatabaseHelper.instance.markPresencesAsSeen(directorId: user?.id);
      await refreshCounts(user);
    } catch (e) {
      debugPrint('Error marking presences as seen: $e');
    }
  }

  void _resetCounts() {
    _unreadMessageCount = 0;
    _unreadNotificationCount = 0;
    _unreadReclamationsCount = 0;
    _pendingPresenceValidationsCount = 0;
    _unreadInscriptionRequestsCount = 0;
    _unreadNotesCount = 0;
    _pendingSeanceValidationsCount = 0;
    notifyListeners();
  }
}
