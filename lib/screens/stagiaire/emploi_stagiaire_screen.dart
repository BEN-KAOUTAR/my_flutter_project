import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/database_helper.dart';
import '../../models/emploi.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../services/pdf_service.dart';

class EmploiStagiaireScreen extends StatefulWidget {
  const EmploiStagiaireScreen({super.key});

  @override
  State<EmploiStagiaireScreen> createState() => _EmploiStagiaireScreenState();
}

class _EmploiStagiaireScreenState extends State<EmploiStagiaireScreen> {
  Emploi? _emploi;
  bool _isLoading = true;
  int _currentWeek = 1;

  final List<String> _jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];

  @override
  void initState() {
    super.initState();
    _currentWeek = _calculateInitialWeek();
    _loadEmploi();
  }

  int _calculateInitialWeek() {
    final now = DateTime.now();
    final firstDayOfYear = DateTime(now.year, 1, 1);
    final daysToFirstMonday = (8 - firstDayOfYear.weekday) % 7;
    final firstMonday = DateTime(now.year, 1, 1 + daysToFirstMonday);
    
    if (now.isBefore(firstMonday)) return 1;
    
    final daysSinceFirstMonday = now.difference(firstMonday).inDays;
    return (daysSinceFirstMonday / 7).floor() + 1;
  }

  String _getMonthlyWeekDisplay(int yearlyWeekNum) {
    final year = DateTime.now().year;
    final firstDayOfYear = DateTime(year, 1, 1);
    final daysToFirstMonday = (8 - firstDayOfYear.weekday) % 7;
    final firstMonday = DateTime(year, 1, 1 + daysToFirstMonday);
    
    final weekMonday = firstMonday.add(Duration(days: (yearlyWeekNum - 1) * 7));
    
    final firstDayOfMonth = DateTime(weekMonday.year, weekMonday.month, 1);
    int offsetToFirstMonday = (DateTime.monday - firstDayOfMonth.weekday + 7) % 7;
    final monthFirstMonday = firstDayOfMonth.add(Duration(days: offsetToFirstMonday));
    
    int weekIndex;
    if (weekMonday.isBefore(monthFirstMonday)) {
      weekIndex = 1; 
    } else {
      weekIndex = (weekMonday.difference(monthFirstMonday).inDays / 7).floor() + 1;
    }
    
    final months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    return 'Semaine $weekIndex (${months[weekMonday.month - 1]})';
  }

  String _getWeekDateRange(int yearlyWeekNum) {
    final year = DateTime.now().year;
    final firstDayOfYear = DateTime(year, 1, 1);
    final daysToFirstMonday = (8 - firstDayOfYear.weekday) % 7;
    final firstMonday = DateTime(year, 1, 1 + daysToFirstMonday);
    
    final weekStart = firstMonday.add(Duration(days: (yearlyWeekNum - 1) * 7));
    final weekEnd = weekStart.add(const Duration(days: 5));
    
    final dateFormat = DateFormat('dd MMM');
    return '${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)}';
  }

  Future<void> _loadEmploi() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user?.groupeId != null) {
      final emploi = await DatabaseHelper.instance.getEmploiBySemaineAndGroupe(
        _currentWeek,
        user!.groupeId!,
      );
      setState(() {
        _emploi = emploi;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildWeekSelector(),
          Expanded(child: _buildSchedule()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_emploi != null) {
            PdfService.generateEmploiPdf(
              _emploi!,
              groupeName: 'Mon Groupe',
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Aucun emploi du temps disponible')),
            );
          }
        },
        icon: const Icon(Icons.picture_as_pdf),
        label: Text('Télécharger PDF', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.stagiaireColor,
      ),
    );
  }

  Widget _buildWeekSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      color: AppTheme.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Votre planning de la semaine',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: _buildWeekNavigator(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNavigator() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _currentWeek > 1 ? () {
              setState(() => _currentWeek--);
              _loadEmploi();
            } : null,
          ),
          Container(height: 24, width: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getMonthlyWeekDisplay(_currentWeek),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  _getWeekDateRange(_currentWeek),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 24, width: 1, color: AppTheme.border),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () {
              setState(() => _currentWeek++);
              _loadEmploi();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSchedule() {
    if (_emploi == null || _emploi!.creneaux.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Aucun emploi du temps',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'pour cette semaine',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _jours.length,
      itemBuilder: (context, index) => _buildDayCard(_jours[index]),
    );
  }

  Widget _buildDayCard(String jour) {
    final creneauxJour = _emploi!.creneaux.where((c) => c.jour == jour).toList();

    if (creneauxJour.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primaryBlue),
                ),
                const SizedBox(width: 12),
                Text(
                  jour,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: creneauxJour.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
            itemBuilder: (context, index) {
              final creneau = creneauxJour[index];
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${creneau.heureDebut} - ${creneau.heureFin}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 40,
                      width: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            creneau.moduleName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.room_outlined, size: 14, color: AppTheme.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                creneau.salle,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

