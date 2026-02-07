import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../data/database_helper.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../models/emploi.dart';
import 'dart:convert';


class PresenceScreen extends StatefulWidget {
  const PresenceScreen({super.key});

  @override
  State<PresenceScreen> createState() => _PresenceScreenState();
}

class _PresenceScreenState extends State<PresenceScreen> {
  bool _isLoading = true;
  int _totalPresences = 0;
  int _totalAbsences = 0;
  int _totalRetards = 0;
  List<Map<String, dynamic>> _allPresences = [];
  List<Map<String, dynamic>> _filteredPresences = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<Map<String, dynamic>>> _presencesByDate = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadPresenceData();
  }

  Future<void> _loadPresenceData() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null) {
      try {
        final db = await DatabaseHelper.instance.database;
        
        final statsResult = await db.rawQuery('''
          SELECT 
            COUNT(CASE WHEN statut = 'PRESENT' THEN 1 END) as presences,
            COUNT(CASE WHEN statut = 'ABSENT' THEN 1 END) as absences,
            COUNT(CASE WHEN statut = 'RETARD' THEN 1 END) as retards
          FROM presences
          WHERE stagiaire_id = ? AND date(date) <= date(?) AND valide_par_dp = 1
        ''', [user.id, DateTime.now().toIso8601String().split('T')[0]]);

        if (statsResult.isNotEmpty) {
          _totalPresences = (statsResult.first['presences'] as int?) ?? 0;
          _totalAbsences = (statsResult.first['absences'] as int?) ?? 0;
          _totalRetards = (statsResult.first['retards'] as int?) ?? 0;
        }

        final historyResult = await db.rawQuery('''
          SELECT 
            p.date,
            p.statut,
            p.groupe_id,
            p.heure,
            g.nom as groupe_nom
          FROM presences p
          LEFT JOIN groupes g ON p.groupe_id = g.id
          WHERE p.stagiaire_id = ? AND date(p.date) <= date(?) AND p.valide_par_dp = 1
          ORDER BY p.date DESC, p.heure ASC
        ''', [user.id, DateTime.now().toIso8601String().split('T')[0]]);

        List<Map<String, dynamic>> enrichedHistory = [];
        Map<DateTime, List<Map<String, dynamic>>> presenceMap = {};
        
        for (var record in historyResult) {
          final presenceDate = DateTime.parse(record['date'] as String);
          final dateOnlyStr = record['date'] as String;
          final groupeId = record['groupe_id'] as int?;
          final recordedHeure = record['heure'] as String?;
          
          String? formateurName;
          String? moduleName;
          String? timeSlot = recordedHeure;
          
          if (groupeId != null) {
            final seances = await db.rawQuery('''
              SELECT 
                m.nom as module_nom,
                u.nom as formateur_nom
              FROM seances s
              JOIN affectations a ON s.affectation_id = a.id
              LEFT JOIN modules m ON a.module_id = m.id
              LEFT JOIN users u ON a.formateur_id = u.id
              WHERE a.groupe_id = ? AND s.date LIKE ?
              LIMIT 1
            ''', [groupeId, '$dateOnlyStr%']);

            if (seances.isNotEmpty) {
              formateurName = seances.first['formateur_nom'] as String?;
              moduleName = seances.first['module_nom'] as String?;
            } else {
              final days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
              final dayName = days[presenceDate.weekday - 1];
              
              final emploisResult = await db.query('emplois', where: 'groupe_id = ?', whereArgs: [groupeId], limit: 1);
              
              if (emploisResult.isNotEmpty) {
                try {
                   final employment = Emploi.fromMap(emploisResult.first);
                   Creneau? matchingCreneau;
                   
                   if (recordedHeure != null) {
                     matchingCreneau = employment.creneaux.where((c) => 
                       c.jour.toLowerCase() == dayName.toLowerCase() && 
                       '${c.heureDebut} - ${c.heureFin}' == recordedHeure
                     ).firstOrNull;
                   }

                   matchingCreneau ??= employment.creneaux.where((c) => 
                     c.jour.toLowerCase() == dayName.toLowerCase()
                   ).firstOrNull;
                   
                   if (matchingCreneau != null) {
                     moduleName = matchingCreneau.moduleName;
                     formateurName = matchingCreneau.formateurName;
                     timeSlot ??= '${matchingCreneau.heureDebut} - ${matchingCreneau.heureFin}';
                   }
                } catch (e) {
                   debugPrint('Error parsing emploi: $e');
                }
              }
            }
          }
          
          final enrichedRecord = {
            'date': record['date'],
            'statut': record['statut'],
            'groupe_nom': record['groupe_nom'],
            'module_nom': moduleName ?? 'Module',
            'formateur_nom': formateurName ?? 'Formateur',
            'time_slot': timeSlot ?? '--:--',
          };
          
          enrichedHistory.add(enrichedRecord);
          
          final dateKey = DateTime(presenceDate.year, presenceDate.month, presenceDate.day);
          if (!presenceMap.containsKey(dateKey)) {
            presenceMap[dateKey] = [];
          }
          presenceMap[dateKey]!.add(enrichedRecord);
        }

        if (mounted) {
          setState(() {
            _allPresences = enrichedHistory;
            _presencesByDate = presenceMap;
            _filterPresencesByDate();
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading presence data: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterPresencesByDate() {
    if (_selectedDay == null) {
      _filteredPresences = _allPresences;
    } else {
      final selectedDateKey = DateTime(
        _selectedDay!.year,
        _selectedDay!.month,
        _selectedDay!.day,
      );
      _filteredPresences = _presencesByDate[selectedDateKey] ?? [];
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Date inconnue';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateRelative(String? dateStr) {
    if (dateStr == null) return 'Date inconnue';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == today) {
        return "Aujourd'hui";
      } else if (dateOnly == yesterday) {
        return 'Hier';
      } else {
        return DateFormat('EEEE', 'fr_FR').format(date);
      }
    } catch (e) {
      return dateStr;
    }
  }

  String _getDayOfWeek(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE', 'fr_FR').format(date);
    } catch (e) {
      return '';
    }
  }

  Color _getStatusColor(String? status) {
    if (status == null) return AppTheme.textSecondary;
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return AppTheme.accentGreen;
      case 'ABSENT':
        return AppTheme.accentRed;
      case 'RETARD':
        return AppTheme.accentOrange;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getStatusIcon(String? status) {
    if (status == null) return Icons.help_outline_rounded;
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return Icons.check_circle_rounded;
      case 'ABSENT':
        return Icons.cancel_rounded;
      case 'RETARD':
        return Icons.access_time_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _getStatusLabel(String? status) {
    if (status == null) return 'Inconnu';
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return 'Présent';
      case 'ABSENT':
        return 'Absent';
      case 'RETARD':
        return 'Retard';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _loadPresenceData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildStatsRow(),
              const SizedBox(height: 32),
              _buildCalendar(),
              const SizedBox(height: 32),
              _buildHistorySection(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Consultez votre historique de présence',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Présences',
            '$_totalPresences',
            Icons.check_circle_outline_rounded,
            AppTheme.accentGreen,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Absences',
            '$_totalAbsences',
            Icons.error_outline_rounded,
            AppTheme.accentRed,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Retards',
            '$_totalRetards',
            Icons.access_time_rounded,
            AppTheme.accentOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        eventLoader: (day) {
          final dateKey = DateTime(day.year, day.month, day.day);
          return _presencesByDate[dateKey] ?? [];
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
            _filterPresencesByDate();
          });
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: AppTheme.accentGreen,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 1,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDay != null 
                  ? 'Présences du ${DateFormat('dd/MM/yyyy').format(_selectedDay!)}'
                  : 'Historique récent',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            if (_selectedDay != null)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedDay = null;
                    _filterPresencesByDate();
                  });
                },
                icon: const Icon(Icons.clear, size: 18),
                label: Text(
                  'Tout voir',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_filteredPresences.isEmpty)
          _buildEmptyState()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredPresences.length,
            itemBuilder: (context, index) {
              final record = _filteredPresences[index];
              return _buildPresenceCard(record);
            },
          ),
      ],
    );
  }

  Widget _buildPresenceCard(Map<String, dynamic> record) {
    final status = record['statut'] as String?;
    final dateRelative = _formatDateRelative(record['date'] as String?);
    final dateFormatted = _formatDate(record['date'] as String?);
    final dayOfWeek = _getDayOfWeek(record['date'] as String?);
    final moduleName = record['module_nom'] as String? ?? 'Module';
    final formateurName = record['formateur_nom'] as String? ?? 'Formateur';
    final timeSlot = record['time_slot'] as String? ?? '08:30 - 10:30';
    
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);
    final statusLabel = _getStatusLabel(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateRelative,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '$dayOfWeek • $moduleName',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formateurName,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$dateFormatted • $timeSlot',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedDay != null 
                ? 'Aucune présence ce jour' 
                : 'Aucun historique de présence',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedDay != null
                ? 'Sélectionnez une autre date'
                : 'Vos présences apparaîtront ici',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
