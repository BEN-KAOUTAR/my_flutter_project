import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/reclamation.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../data/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../services/notification_service.dart';
import '../../providers/notification_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'create_reclamation_dialog.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import '../../services/pdf_service.dart';

class ReclamationsListScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ReclamationsListScreen({super.key, this.onBack});

  @override
  State<ReclamationsListScreen> createState() => _ReclamationsListScreenState();
}

class _ReclamationsListScreenState extends State<ReclamationsListScreen> {
  List<Reclamation> _reclamations = [];
  bool _isLoading = true;
  late User _currentUser;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthService>(context, listen: false).currentUser!;
    _loadData();

    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_isLoading) {
        _loadData(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    
    List<Reclamation> data;
    if (_currentUser.role == UserRole.dp) {
      data = await DatabaseHelper.instance.getAllReclamations(directorId: _currentUser.id);
    } else {
      data = await DatabaseHelper.instance.getReclamationsByUser(_currentUser.id!);
    }

    setState(() {
      _reclamations = data;
      _isLoading = false;
    });
  }

  Future<void> _updateStatus(Reclamation reclamation, String status) async {
    String? response;
    if (status == 'TRAITEE' || status == 'REJETEE') {
      response = await showDialog<String>(
        context: context,
        builder: (context) => _ResponseDialog(initialStatus: status),
      );
      if (response == null) return;
    }

    await DatabaseHelper.instance.updateReclamationStatus(
      reclamation.id!, 
      status, 
      response: response
    );
    
      final statusMessage = status == 'TRAITEE' 
        ? 'Votre réclamation "${reclamation.subject}" a été traitée.' 
        : 'Votre réclamation "${reclamation.subject}" a été rejetée.';
      
      final fullMessage = response != null && response.isNotEmpty
          ? '$statusMessage\nRéponse: $response'
          : statusMessage;

      await NotificationService().notifyUser(
      userId: reclamation.userId,
      title: 'Mise à jour Réclamation',
      message: fullMessage,
      type: status == 'TRAITEE' ? 'SUCCESS' : 'WARNING'
    );
    
    if (mounted) {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      Provider.of<NotificationProvider>(context, listen: false).refreshCounts(user);
    }

    _loadData();
  }

  Future<void> _downloadFormalPdf(Reclamation reclamation) async {
    setState(() => _isLoading = true);
    try {
      final sender = await DatabaseHelper.instance.getUserById(reclamation.userId);
      if (sender == null) throw Exception('Utilisateur introuvable');
      
      final dateStr = '${reclamation.timestamp.day}/${reclamation.timestamp.month}/${reclamation.timestamp.year} ${reclamation.timestamp.hour}:${reclamation.timestamp.minute.toString().padLeft(2, '0')}';
      
      await PdfService.generateFormalReclamationPdf(
        fromName: sender.nom,
        fromEmail: sender.email,
        toName: 'Directeur Pédagogique',
        subject: reclamation.subject,
        date: dateStr,
        content: reclamation.message,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du téléchargement: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              _reclamations.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _reclamations.length,
                      itemBuilder: (context, index) => _buildCard(_reclamations[index]),
                    ),
              if (_currentUser.role != UserRole.dp)
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: FloatingActionButton.extended(
                    onPressed: () async {
                      final result = await showDialog(
                        context: context,
                        builder: (context) => const CreateReclamationDialog(),
                      );
                      if (result == true && mounted) {
                        final user = Provider.of<AuthService>(context, listen: false).currentUser;
                        Provider.of<NotificationProvider>(context, listen: false).refreshCounts(user);
                        _loadData();
                      }
                    },
                    label: const Text('Nouvelle réclamation'),
                    icon: const Icon(Icons.add),
                    backgroundColor: AppTheme.primaryBlue,
                  ),
                ),
            ],
          );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Aucune réclamation trouvée',
            style: GoogleFonts.poppins(fontSize: 18, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Reclamation rec) {
    Color statusColor;
    IconData statusIcon;
    
    switch (rec.status) {
      case 'TRAITEE':
        statusColor = AppTheme.accentGreen;
        statusIcon = Icons.check_circle;
        break;
      case 'REJETEE':
        statusColor = AppTheme.accentRed;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = AppTheme.accentOrange;
        statusIcon = Icons.schedule;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        rec.status,
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ],
                  ),
                ),
                    Text(
                      '${rec.timestamp.day}/${rec.timestamp.month}/${rec.timestamp.year}',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
            const SizedBox(height: 12),
            Text(
              '[${rec.type}] ${rec.subject}',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              rec.message,
              style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
            ),
            
            if (rec.attachmentUrl != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.1)),
                ),
                child: Builder(
                  builder: (context) {
                    final isBase64 = rec.attachmentUrl?.startsWith('data:base64,') ?? false;
                    String displayName = '';
                    Uint8List? bytes;
                    
                    if (isBase64) {
                      final parts = rec.attachmentUrl!.split('|');
                      displayName = parts.length > 1 ? parts[1] : 'Fichier';
                      final base64Data = parts[0].substring('data:base64,'.length);
                      bytes = base64Decode(base64Data);
                    } else {
                      displayName = rec.attachmentUrl!.split('/').last;
                    }

                    final isImage = rec.attachmentType == 'IMAGE' || displayName.toLowerCase().endsWith('.png') || displayName.toLowerCase().endsWith('.jpg') || displayName.toLowerCase().endsWith('.jpeg');
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox.shrink(),
                        GestureDetector(
                          onTap: () async {
                            if (isBase64) {
                              if (isImage) {
                                _showImagePreview(context, rec, bytes);
                              } else {
                                try {
                                  final parts = rec.attachmentUrl!.split('|');
                                  final base64Data = parts[0].substring('data:base64,'.length);
                                  final bytes = base64Decode(base64Data);
                                  
                                  await Printing.layoutPdf(
                                    onLayout: (_) => bytes,
                                    name: parts.length > 1 ? parts[1] : 'Reclamation_PDF',
                                  );
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Erreur lors de l\'affichage du PDF : $e')),
                                    );
                                  }
                                }
                              }
                            } else {
                              try {
                                await OpenFilex.open(rec.attachmentUrl!);
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Impossible d\'ouvrir la pièce jointe: $e')),
                                  );
                                }
                              }
                            }
                          },
                          child: Row(
                            children: [
                              Icon(
                                isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
                                color: AppTheme.primaryBlue,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ),
            ],

            if (rec.response != null) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Réponse:',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rec.response!,
                      style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],

            if (_currentUser.role == UserRole.dp && rec.status == 'EN_ATTENTE') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _updateStatus(rec, 'REJETEE'),
                    child: Text('Rejeter', style: GoogleFonts.poppins(color: AppTheme.accentRed)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _updateStatus(rec, 'TRAITEE'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                    child: Text('Traiter', style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                ],
              ),
            ],
            ],
          ),
        ),
      );
    }

  void _showImagePreview(BuildContext context, Reclamation rec, Uint8List? bytes) {
    showDialog(
      context: context,
      builder: (context) => _DetailedImageViewer(
        rec: rec,
        bytes: bytes,
      ),
    );
  }
}

class _DetailedImageViewer extends StatelessWidget {
  final Reclamation rec;
  final Uint8List? bytes;

  const _DetailedImageViewer({required this.rec, this.bytes});

  @override
  Widget build(BuildContext context) {
    final bool isBase64 = bytes != null;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          rec.subject,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: isBase64
            ? Image.memory(bytes!)
            : (!kIsWeb 
                ? Image.file(File(rec.attachmentUrl!))
                : const Center(child: Icon(Icons.broken_image, size: 64, color: Colors.grey))),
        ),
      ),
    );
  }
}

class _ResponseDialog extends StatefulWidget {
  final String initialStatus;
  const _ResponseDialog({required this.initialStatus});

  @override
  State<_ResponseDialog> createState() => _ResponseDialogState();
}

class _ResponseDialogState extends State<_ResponseDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Répondre à la réclamation'),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: 'Message de réponse',
          hintText: 'Expliquez la décision...',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              Navigator.pop(context, _controller.text);
            }
          },
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}

