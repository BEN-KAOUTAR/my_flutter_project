import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/reclamation.dart';
import '../../services/auth_service.dart';
import '../../data/database_helper.dart';
import '../../theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

class CreateReclamationDialog extends StatefulWidget {
  const CreateReclamationDialog({super.key});

  @override
  State<CreateReclamationDialog> createState() => _CreateReclamationDialogState();
}

class _CreateReclamationDialogState extends State<CreateReclamationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedType = 'AUTRE';
  bool _isLoading = false;
  String? _attachmentUrl;
  String? _attachmentType;
  PlatformFile? _pickedFile;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        final pickedFile = result.files.first;
        setState(() {
          _pickedFile = pickedFile;
          if (kIsWeb) {
            final bytes = pickedFile.bytes;
            if (bytes != null) {
              _attachmentUrl = 'data:base64,${base64Encode(bytes)}|${pickedFile.name}';
            }
          } else {
            _attachmentUrl = pickedFile.path;
          }
          _attachmentType = pickedFile.extension?.toUpperCase() ?? 'FILE';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection du fichier: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user == null) return;

      final reclamation = Reclamation(
        userId: user.id!,
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        type: _selectedType,
        timestamp: DateTime.now(),
        attachmentUrl: _attachmentUrl,
        attachmentType: _attachmentType,
      );

      await DatabaseHelper.instance.createReclamation(reclamation);
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réclamation envoyée avec succès'), backgroundColor: AppTheme.accentGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nouvelle réclamation',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'NOTE', child: Text('Problème de note')),
                  DropdownMenuItem(value: 'ABSENCE', child: Text('Justification d\'absence')),
                  DropdownMenuItem(value: 'AUTRE', child: Text('Autre demande')),
                ],
                onChanged: (v) => setState(() => _selectedType = v!),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'Sujet',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              
              InkWell(
                onTap: _pickFile,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file_rounded, color: AppTheme.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _attachmentUrl != null 
                            ? (kIsWeb && _attachmentUrl!.startsWith('data:base64,') 
                                ? _attachmentUrl!.split('|').last 
                                : _attachmentUrl!.split('/').last)
                            : 'Joindre un fichier (PDF, Image)',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _attachmentUrl != null ? AppTheme.primaryBlue : AppTheme.textSecondary,
                            fontWeight: _attachmentUrl != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (_attachmentUrl != null)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.cancel_rounded, size: 20, color: AppTheme.accentRed),
                          onPressed: () => setState(() {
                            _attachmentUrl = null;
                            _attachmentType = null;
                            _pickedFile = null;
                          }),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Envoyer', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

