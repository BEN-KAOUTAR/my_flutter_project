import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/database_helper.dart';
import '../../models/note.dart';
import '../../models/module.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../services/pdf_service.dart';
import '../common/dashboard_components.dart';

class NotesStagiaireScreen extends StatefulWidget {
  const NotesStagiaireScreen({super.key});

  @override
  State<NotesStagiaireScreen> createState() => _NotesStagiaireScreenState();
}

class _NotesStagiaireScreenState extends State<NotesStagiaireScreen> {
  List<Note> _notes = [];
  List<Module> _modules = [];
  bool _isLoading = true;
  double _averageNote = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null) {
      final notes = await DatabaseHelper.instance.getNotesByStagiaire(user.id!);
      final modules = await DatabaseHelper.instance.getAllModules();

      final validatedNotes = notes.where((n) => n.validee).toList();
      double average = 0;
      if (validatedNotes.isNotEmpty) {
        average = validatedNotes.map((n) => n.valeur).reduce((a, b) => a + b) / validatedNotes.length;
      }

      setState(() {
        _notes = notes.where((n) => n.validee).toList();
        _modules = modules;
        _averageNote = average;
        _isLoading = false;
      });
    }
  }

  String _getModuleName(int id) {
    return _modules.where((m) => m.id == id).firstOrNull?.nom ?? 'N/A';
  }

  Color _getNoteColor(double note) {
    if (note >= 16) return AppTheme.accentGreen;
    if (note >= 12) return AppTheme.primaryBlue;
    if (note >= 10) return AppTheme.accentOrange;
    return AppTheme.accentRed;
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
          Container(
            padding: const EdgeInsets.all(24),
            color: AppTheme.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vos résultats et évaluations',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAverageCard(),
                    const SizedBox(height: 32),
                    Text(
                      'Détail des notes',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_notes.isEmpty)
                      _buildEmptyState()
                    else
                      ..._notes.map((note) => _buildNoteCard(note)),
                    const SizedBox(height: 80),
                  ],
                ),
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
          Icon(Icons.assignment_turned_in_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Aucune note publiée',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            'Vos résultats apparaîtront ici dès validation',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageCard() {
    final noteColor = _getNoteColor(_averageNote);
    return PremiumCard(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      boxShadow: [
        BoxShadow(
          color: noteColor.withValues(alpha: 0.1),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
      border: Border.all(color: noteColor.withValues(alpha: 0.1)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MOYENNE GÉNÉRALE',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _notes.isEmpty ? '-- / 20' : '${_averageNote.toStringAsFixed(2)} / 20',
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: noteColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _averageNote >= 10 ? 'Admis' : 'En progression',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: noteColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_notes.length} modules validés',
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: noteColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _averageNote >= 16 ? Icons.auto_awesome : (_averageNote >= 10 ? Icons.emoji_events : Icons.trending_up),
              size: 48,
              color: noteColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final noteColor = _getNoteColor(note.valeur);

    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: noteColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    note.valeur.toStringAsFixed(1),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: noteColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getModuleName(note.moduleId),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          note.type.displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateFormat.format(note.dateExamen),
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
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: note.valeur / 20,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(noteColor),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${((note.valeur / 20) * 100).toInt()}%',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

