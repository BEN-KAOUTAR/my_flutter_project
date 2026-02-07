import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/database_helper.dart';
import '../../models/groupe.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

import '../../models/emploi.dart';
import 'package:intl/intl.dart';

class PresenceFormateurScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const PresenceFormateurScreen({super.key, this.onBack});

  @override
  State<PresenceFormateurScreen> createState() => _PresenceFormateurScreenState();
}

class _PresenceFormateurScreenState extends State<PresenceFormateurScreen> {
  List<Groupe> _groupes = [];
  int? _selectedGroupeId;
  List<User> _stagiaires = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  Map<int, String> _presenceStatus = {};
  List<Creneau> _availableCreneaux = [];
  Creneau? _selectedCreneau;
  List<Map<String, dynamic>> _todaySessions = [];



  bool _isValidated = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null) {
      try {
        final groupes = await DatabaseHelper.instance.getGroupsForFormateur(user.id!);
        
        final weekNum = _getWeekNumber(_selectedDate);
        final dayName = _getFrenchDayName(_selectedDate.weekday);
        
        List<Map<String, dynamic>> dailySessions = [];
        
        for (var g in groupes) {
          final emploi = await DatabaseHelper.instance.getEmploiBySemaineAndGroupe(weekNum, g.id!);
          if (emploi != null) {
            final sessionCreneaux = emploi.creneaux.where((c) => 
              c.jour == dayName && c.formateurId == user.id
            ).toList();
            
            for (var c in sessionCreneaux) {
              dailySessions.add({
                'creneau': c,
                'groupeId': g.id,
                'groupeNom': g.nom,
              });
            }
          }
        }

        dailySessions.sort((a, b) => (a['creneau'] as Creneau).heureDebut.compareTo((b['creneau'] as Creneau).heureDebut));

        if (mounted) {
          setState(() {
            _groupes = groupes;
            _todaySessions = dailySessions;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        debugPrint('Error loading schedule: $e');
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadStagiaires(int groupeId) async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      await _loadAvailableCreneaux(groupeId);

      final stagiaires = await DatabaseHelper.instance.getStagiairesByGroupe(groupeId);
      
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      String? selectedHeure = _selectedCreneau != null 
          ? '${_selectedCreneau!.heureDebut} - ${_selectedCreneau!.heureFin}' 
          : null;

      final presenceData = await DatabaseHelper.instance.getPresenceByDateGroup(
        dateStr, 
        groupeId,
        heure: selectedHeure
      );
      
      Map<int, String> statusMap = {};
      bool isValidated = false;

      if (presenceData.isNotEmpty) {
        for (var p in presenceData) {
          statusMap[p['stagiaire_id'] as int] = p['statut'] as String;
          if ((p['valide_par_dp'] as int? ?? 0) == 1) {
            isValidated = true;
          }
        }
      }

      for (var s in stagiaires) {
        if (!statusMap.containsKey(s.id)) {
          statusMap[s.id!] = 'PRESENT';
        }
      }
      
      if (mounted) {
        setState(() {
          _stagiaires = stagiaires;
          _presenceStatus = statusMap;
          _isValidated = isValidated;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stagiaires: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du chargement des données. Veuillez réessayer.')),
        );
      }
    }
  }

  Future<void> _loadAvailableCreneaux(int groupeId) async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    final weekNum = _getWeekNumber(_selectedDate);
    final emploi = await DatabaseHelper.instance.getEmploiBySemaineAndGroupe(weekNum, groupeId);
    
    if (emploi != null) {
      final dayName = _getFrenchDayName(_selectedDate.weekday);
      final valid = emploi.creneaux.where((c) => 
        c.jour == dayName && c.formateurId == user.id
      ).toList();
      
      if (mounted) {
        setState(() {
          _availableCreneaux = valid;
          if (valid.isNotEmpty) {
            if (_selectedCreneau == null || !valid.any((c) => c.heureDebut == _selectedCreneau!.heureDebut)) {
               _selectedCreneau = valid.first;
            }
          } else {
            _selectedCreneau = null;
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _availableCreneaux = [];
          _selectedCreneau = null;
        });
      }
    }
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysToFirstMonday = (8 - firstDayOfYear.weekday) % 7;
    final firstMonday = DateTime(date.year, 1, 1 + daysToFirstMonday);
    
    if (date.isBefore(firstMonday)) return 1;
    
    final daysSinceFirstMonday = date.difference(firstMonday).inDays;
    return (daysSinceFirstMonday / 7).floor() + 1;
  }

  String _getFrenchDayName(int weekday) {
    const days = {
      1: 'Lundi',
      2: 'Mardi',
      3: 'Mercredi',
      4: 'Jeudi',
      5: 'Vendredi',
      6: 'Samedi',
      7: 'Dimanche',
    };
    return days[weekday] ?? '';
  }

  Future<void> _savePresence() async {
    if (_selectedGroupeId == null) return;
    if (_isValidated) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cette fiche de présence a été validée par le DP et ne peut plus être modifiée.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final formateurId = Provider.of<AuthService>(context, listen: false).currentUser?.id ?? 0;

    for (var student in _stagiaires) {
      final status = _presenceStatus[student.id!] ?? 'PRESENT';
      String? selectedHeure = _selectedCreneau != null 
          ? '${_selectedCreneau!.heureDebut} - ${_selectedCreneau!.heureFin}' 
          : null;
          
      await DatabaseHelper.instance.savePresence(
        student.id!, 
        _selectedGroupeId!, 
        dateStr, 
        status, 
        formateurId,
        heure: selectedHeure
      );
    }
    
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Présence enregistrée avec succès')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          width: double.infinity,
          color: AppTheme.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Marquez la présence de vos groupes',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        _buildDateSelector(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _groupes.isEmpty
                  ? Center(child: Text('Aucun groupe assigné', style: GoogleFonts.poppins(color: AppTheme.textSecondary)))
                  : _selectedDate.weekday == DateTime.sunday
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy_rounded, size: 60, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'Aucune séance le dimanche',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildContent(),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
            Tooltip(
            message: 'Changer la date',
            child: GestureDetector(
              onTap: () async {
                DateTime initial = _selectedDate;
                if (_selectedDate.weekday == DateTime.sunday) {
                  initial = _selectedDate.subtract(const Duration(days: 1));
                }
                
                final date = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                  selectableDayPredicate: (day) => day.weekday != DateTime.sunday,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppTheme.primaryBlue,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                    _selectedCreneau = null;
                    _selectedGroupeId = null;
                    _todaySessions = [];
                    _stagiaires = [];
                  });
                  _loadGroups();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 20, color: AppTheme.primaryBlue),
                    const SizedBox(width: 12),
                    Text(
                      '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedGroupeId != null && _selectedCreneau != null && _stagiaires.isNotEmpty) {
      return _buildPresenceMarkingList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note_rounded, color: AppTheme.primaryBlue),
              const SizedBox(width: 12),
              Text(
                'Vos séances d\'aujourd\'hui',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_todaySessions.isEmpty)
             _buildNoSessionsPlaceholder()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todaySessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final session = _todaySessions[index];
                final creneau = session['creneau'] as Creneau;
                final groupeNom = session['groupeNom'] as String;
                final groupeId = session['groupeId'] as int;

                return _buildSessionCard(creneau, groupeId, groupeNom);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNoSessionsPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_today_rounded, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Aucune séance programmée',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          Text(
            'Vérifiez l\'emploi du temps pour cette date.',
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Creneau creneau, int groupeId, String groupeNom) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedGroupeId = groupeId;
          _selectedCreneau = creneau;
        });
        _loadStagiaires(groupeId);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.schedule_rounded, color: AppTheme.primaryBlue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${creneau.heureDebut} - ${creneau.heureFin}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  Text(
                    '$groupeNom • ${creneau.salle}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    creneau.moduleName,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildPresenceMarkingList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _selectedGroupeId = null;
                    _selectedCreneau = null;
                    _stagiaires = [];
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedCreneau != null 
                          ? '${_selectedCreneau!.heureDebut} - ${_selectedCreneau!.heureFin}' 
                          : '',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                    ),
                    Text(
                      _groupes.firstWhere((g) => g.id == _selectedGroupeId).nom,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text('Stagiaire', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Center(child: Text('Statut', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)))),
                      ],
                    ),
                  ),
                  if (_isValidated)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      color: AppTheme.accentGreen.withValues(alpha: 0.1),
                      child: Center(
                        child: Text(
                          '🔒 Validé par le Directeur Pédagogique',
                          style: GoogleFonts.poppins(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _stagiaires.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final student = _stagiaires[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                      child: Text(student.nom[0], style: GoogleFonts.poppins(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(student.nom, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildStatusButton(student.id!, 'PRESENT', Icons.check_circle, AppTheme.accentGreen),
                                    const SizedBox(width: 8),
                                    _buildStatusButton(student.id!, 'ABSENT', Icons.cancel, AppTheme.accentRed),
                                    const SizedBox(width: 8),
                                    _buildStatusButton(student.id!, 'RETARD', Icons.schedule, AppTheme.accentOrange),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isValidated ? null : _savePresence,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isValidated ? Colors.grey : AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _isValidated ? 'Verrouillé' : 'Enregistrer',
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusButton(int studentId, String status, IconData icon, Color color) {
    final isSelected = _presenceStatus[studentId] == status;
    return InkWell(
      onTap: _isValidated ? null : () => setState(() => _presenceStatus[studentId] = status),
      child: Opacity(
        opacity: _isValidated && !isSelected ? 0.3 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? color : Colors.grey.shade300),
          ),
          child: Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
        ),
      ),
    );
  }
}
