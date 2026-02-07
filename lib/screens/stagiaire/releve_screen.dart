import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';
import '../../data/database_helper.dart';
import '../../models/note.dart';
import '../../models/module.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../services/pdf_service.dart';

class ReleveScreen extends StatefulWidget {
  const ReleveScreen({super.key});

  @override
  State<ReleveScreen> createState() => _ReleveScreenState();
}

class _ReleveScreenState extends State<ReleveScreen> {
  List<Note> _notes = [];
  List<Module> _modules = [];
  bool _isLoading = true;
  double _average = 0;
  
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
      try {
        final notes = await DatabaseHelper.instance.getNotesByStagiaire(user.id!);
        final modules = await DatabaseHelper.instance.getAllModules();
        
        final validatedExams = notes.where((n) => n.validee).toList();
        double avg = 0;
        if (validatedExams.isNotEmpty) {
           avg = validatedExams.map((n) => n.valeur).reduce((a, b) => a + b) / validatedExams.length;
        }

        if (mounted) {
          setState(() {
            _notes = validatedExams;
            _modules = modules;
            _average = avg;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading transcript data: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getModuleName(int id) {
    return _modules.firstWhere((m) => m.id == id, orElse: () => Module(nom: 'Inconnu', masseHoraireTotale: 0, filiereId: 0)).nom;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Votre bulletin détaillé',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildWarningBanner(),
            const SizedBox(height: 32),
            _buildTranscriptHeader(),
            const SizedBox(height: 16),
            _buildTranscriptTable(),
            const SizedBox(height: 32),
            _buildDownloadButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFC2410C)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ce document est fourni à titre informatif. Seul le relevé cacheté par la direction est officiel.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF9A3412),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptHeader() {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.nom ?? 'Étudiant',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Matricule: ${user?.matricule ?? 'N/A'}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                    ? (user.photoUrl!.startsWith('http')
                        ? NetworkImage(user.photoUrl!) as ImageProvider
                        : (kIsWeb 
                            ? (user.photoUrl!.startsWith('data:image') 
                                ? MemoryImage(base64Decode(user.photoUrl!.split(',').last)) as ImageProvider
                                : const AssetImage('assets/images/placeholder.png') as ImageProvider)
                            : FileImage(File(user.photoUrl!.replaceFirst('file://', ''))) as ImageProvider))
                    : null,
                child: user?.photoUrl == null || user!.photoUrl!.isEmpty
                    ? Text(
                        (user?.nom ?? 'S')[0],
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                      )
                    : null,
              ),
            ],
          ),
          const Divider(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSimpleStat('Moyenne', _average.toStringAsFixed(2)),
              _buildSimpleStat('Modules', '${_notes.length}'),
              _buildSimpleStat('Décision', _average >= 10 ? 'Admis' : 'Ajourné'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
          left: BorderSide(color: AppTheme.border.withValues(alpha: 0.5)),
          right: BorderSide(color: AppTheme.border.withValues(alpha: 0.5)),
          bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppTheme.background,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Module',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Note/20',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Résultat',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          if (_notes.isEmpty)
             Padding(
               padding: const EdgeInsets.all(32.0),
               child: Text('Aucune note validée', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
             )
          else
            ..._notes.map((n) => _buildTableRow(
              _getModuleName(n.moduleId),
              n.valeur.toStringAsFixed(2),
              n.valeur >= 10 ? 'Validé' : 'Non Validé'
            )),
          
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTableRow(String module, String note, String result) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              module,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              note,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              result,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color:  result == 'Validé' ? AppTheme.accentGreen : AppTheme.accentRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          final authService = Provider.of<AuthService>(context, listen: false);
          final user = authService.currentUser;
          if (user != null && _notes.isNotEmpty) {
            PdfService.generateNoteReportPdf(user, _notes, _modules);
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Aucune donnée à exporter')),
             );
          }
        },
        icon: const Icon(Icons.file_download_outlined, color: Colors.white),
        label: Text(
          'Télécharger le PDF',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

