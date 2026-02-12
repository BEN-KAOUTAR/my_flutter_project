import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/database_helper.dart';
import '../../models/seance.dart';
import '../../models/affectation.dart';
import '../../models/module.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../common/dashboard_components.dart';

class SeancesScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const SeancesScreen({super.key, this.onBack});

  @override
  State<SeancesScreen> createState() => _SeancesScreenState();
}

class _SeancesScreenState extends State<SeancesScreen> {
  List<Seance> _seances = [];
  List<Affectation> _affectations = [];
  List<Module> _modules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.id;

    if (userId != null) {
      final user = authService.currentUser;
      final affectations = await DatabaseHelper.instance.getAffectationsByFormateur(userId);
      final modules = await DatabaseHelper.instance.getAllModules(directorId: user?.directorId);
      
      List<Seance> allSeances = [];
      for (var affectation in affectations) {
        final seances = await DatabaseHelper.instance.getSeancesByAffectation(affectation.id!);
        allSeances.addAll(seances);
      }

      setState(() {
        _affectations = affectations;
        _modules = modules;
        _seances = allSeances..sort((a, b) => b.date.compareTo(a.date));
        _isLoading = false;
      });
    }
  }

  String _getModuleName(int affectationId) {
    final affectation = _affectations.where((a) => a.id == affectationId).firstOrNull;
    if (affectation == null) return 'N/A';
    return _modules.where((m) => m.id == affectation.moduleId).firstOrNull?.nom ?? 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: _seances.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                        itemCount: _seances.length,
                        itemBuilder: (context, index) => _buildSeanceCard(_seances[index]),
                      ),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton.extended(
            onPressed: () => _showAddSeanceDialog(),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text('Nouvelle séance', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: AppTheme.formateurColor,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final totalHours = _seances.fold<double>(0, (sum, item) => sum + item.duree);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: AppTheme.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(
                 'Gérez vos interventions et le contenu abordé',
                 style: GoogleFonts.poppins(
                   fontSize: 14,
                   color: AppTheme.textSecondary,
                 ),
               ),
             ],
           ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 20, color: AppTheme.formateurColor),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${totalHours.toInt()}h',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.formateurColor,
                      ),
                    ),
                    Text(
                      'Total',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
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
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.formateurColor.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_note_outlined, size: 64, color: AppTheme.formateurColor.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucune séance enregistrée',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Commencez par ajouter votre première séance',
            style: GoogleFonts.poppins(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSeanceCard(Seance seance) {
    final dateFormat = DateFormat('dd MMMM yyyy');
    final isValidated = seance.statut == SeanceStatus.valide;
    final statusColor = isValidated ? AppTheme.accentGreen : AppTheme.accentOrange;

    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isValidated ? Icons.check_circle_rounded : Icons.schedule_rounded,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getModuleName(seance.affectationId),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${dateFormat.format(seance.date)}${seance.heureDebut != null ? ' à ${seance.heureDebut}' : ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${seance.duree.toInt()}h',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                if (!isValidated) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showAddSeanceDialog(existingSeance: seance);
                      } else if (value == 'delete') {
                        _confirmDeleteSeance(seance);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20, color: AppTheme.accentOrange),
                            SizedBox(width: 12),
                            Text('Modifier'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.accentRed),
                            SizedBox(width: 12),
                            Text('Supprimer'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Objectifs & Contenu',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isValidated ? 'VALIDÉE' : 'EN ATTENTE',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    seance.contenu,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSeance(Seance seance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer la séance ?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Cette action est irréversible.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: Text('Supprimer', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && seance.id != null) {
      await DatabaseHelper.instance.deleteSeance(seance.id!);
      _loadData();
    }
  }

  Future<void> _showAddSeanceDialog({Seance? existingSeance}) async {
    int? selectedAffectationId = existingSeance?.affectationId;
    final contenuController = TextEditingController(text: existingSeance?.contenu);
    double duree = existingSeance?.duree ?? 4;
    DateTime selectedDate = existingSeance?.date ?? DateTime.now();
    TimeOfDay? selectedTime;
    if (existingSeance?.heureDebut != null) {
      try {
        final parts = existingSeance!.heureDebut!.split(':');
        int hour = 0;
        int minute = 0;
        
        if (parts.length >= 2) {
          hour = int.parse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
          
          final minutePart = parts[1].split(' ').first;
          minute = int.parse(minutePart.replaceAll(RegExp(r'[^0-9]'), ''));
          
          if (existingSeance!.heureDebut!.toUpperCase().contains('PM') && hour < 12) {
            hour += 12;
          } else if (existingSeance!.heureDebut!.toUpperCase().contains('AM') && hour == 12) {
            hour = 0;
          }
        }
        selectedTime = TimeOfDay(hour: hour, minute: minute);
      } catch (e) {
        debugPrint('Error parsing time: $e');
        selectedTime = TimeOfDay.now();
      }
    } else {
      selectedTime = TimeOfDay.now();
    }
    bool isEditing = existingSeance != null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Modifier la séance' : 'Nouvelle séance',
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<int>(
                    value: selectedAffectationId,
                    decoration: const InputDecoration(
                      labelText: 'Module / Groupe',
                      prefixIcon: Icon(Icons.book_rounded),
                    ),
                    items: _affectations.map((a) {
                      final moduleName = _modules.where((m) => m.id == a.moduleId).firstOrNull?.nom ?? 'N/A';
                      return DropdownMenuItem(
                        value: a.id,
                        child: Text(moduleName),
                      );
                    }).toList(),
                    onChanged: isEditing ? null : (value) => setModalState(() => selectedAffectationId = value),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setModalState(() => selectedDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date de la séance',
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                      child: Text(DateFormat('dd MMMM yyyy').format(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (time != null) {
                        setModalState(() => selectedTime = time);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Heure de début',
                        prefixIcon: Icon(Icons.access_time_rounded),
                      ),
                      child: Text(selectedTime?.format(context) ?? 'Sélectionner l\'heure'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Durée de la séance: ${duree.toInt()}h',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                  Slider(
                    value: duree,
                    min: 1,
                    max: 8,
                    divisions: 7,
                    activeColor: AppTheme.formateurColor,
                    onChanged: (value) => setModalState(() => duree = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contenuController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Contenu abordé',
                      hintText: 'Décrivez les chapitres ou exercices traités...',
                      prefixIcon: Icon(Icons.description_rounded),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedAffectationId == null || contenuController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Veuillez remplir tous les champs', style: GoogleFonts.poppins()),
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                        return;
                      }
  
                      final seance = Seance(
                        id: existingSeance?.id,
                        affectationId: selectedAffectationId!,
                        date: selectedDate,
                        heureDebut: selectedTime != null 
                            ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                            : null,
                        duree: duree,
                        contenu: contenuController.text.trim(),
                        statut: existingSeance?.statut ?? SeanceStatus.enAttente,
                      );
  
                      if (isEditing) {
                        await DatabaseHelper.instance.updateSeance(seance);
                      } else {
                        await DatabaseHelper.instance.insertSeance(seance);
                      }
  
                      if (context.mounted) {
                        Navigator.pop(context);
                        _loadData();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.formateurColor,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isEditing ? 'Mettre à jour' : 'Enregistrer la séance',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

