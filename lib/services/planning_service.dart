import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/emploi.dart';

class PlanningService {
  static final DatabaseHelper _db = DatabaseHelper.instance;

  static Future<Emploi?> generateSmartSchedule(int groupeId, int semaineNum) async {
    try {
      final groupe = await _db.getGroupeById(groupeId);
      if (groupe == null) return null;

      final affectations = await _db.getAffectationsByGroupe(groupeId);
      if (affectations.isEmpty) return null;

      final modules = await _db.getAllModules();
      
      List<Creneau> creneaux = [];
      final jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
      final demiJournees = ['08:30 - 11:00', '11:00 - 13:00', '13:30 - 15:30', '15:30 - 18:30'];
      
      double getSlotDuration(String slot) {
        final parts = slot.split(' - ');
        final start = parts[0].split(':');
        final end = parts[1].split(':');
        final startMinutes = int.parse(start[0]) * 60 + int.parse(start[1]);
        final endMinutes = int.parse(end[0]) * 60 + int.parse(end[1]);
        return (endMinutes - startMinutes) / 60.0;
      }
      
      int affectationIndex = 0;
      double hoursAssignedToGroup = 0;
      const double maxHoursPerGroup = 30.0;
      const double maxHoursPerFormateur = 26.0;

      Map<int, double> inMemoryFormateurHours = {};

      for (var slotTime in demiJournees) {
        if (hoursAssignedToGroup >= maxHoursPerGroup) break;
        
        final slotDuration = getSlotDuration(slotTime);

        for (var jour in jours) {
          if (hoursAssignedToGroup >= maxHoursPerGroup) break;
          
          if (affectationIndex >= affectations.length) {
            affectationIndex = 0;
          }
          
          int attempts = 0;
          bool assigned = false;
          
          while(attempts < affectations.length) {
            final affectation = affectations[affectationIndex];
            final startHour = slotTime.split(' - ')[0];

            final isAvailable = await _db.checkFormateurAvailability(
              affectation.formateurId, 
              semaineNum, 
              jour, 
              startHour
            );

            if (isAvailable) {
              final existingHours = await _db.getFormateurWeeklyHours(affectation.formateurId, semaineNum);
              final newlyAssignedHours = inMemoryFormateurHours[affectation.formateurId] ?? 0.0;
              
              if ((existingHours + newlyAssignedHours + slotDuration) <= maxHoursPerFormateur) {
                final module = modules.firstWhere((m) => m.id == affectation.moduleId);
                final formateur = await _db.getUserById(affectation.formateurId);

                creneaux.add(Creneau(
                  jour: jour,
                  heureDebut: slotTime.split(' - ')[0],
                  heureFin: slotTime.split(' - ')[1],
                  moduleId: module.id!,
                  moduleName: module.nom,
                  formateurId: formateur?.id ?? 0,
                  formateurName: formateur?.nom ?? 'N/A',
                  salle: 'Salle ${100 + (groupeId % 10) * 10 + (creneaux.length % 5)}',
                  groupeName: groupe.nom,
                ));

                hoursAssignedToGroup += slotDuration;
                inMemoryFormateurHours[affectation.formateurId] = newlyAssignedHours + slotDuration;
                affectationIndex++; 
                assigned = true;
                break;
              }
            }
            
            affectationIndex = (affectationIndex + 1) % affectations.length;
            attempts++;
          }
        }
      }

      if (creneaux.isEmpty) return null;

      return Emploi(
        semaineNum: semaineNum,
        groupeId: groupeId,
        formateurId: affectations.first.formateurId, 
        creneaux: creneaux,
      );
    } catch (e) {
      debugPrint('Error generating schedule: $e');
      return null;
    }
  }
}

