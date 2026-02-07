import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../services/notification_service.dart';
import '../../data/database_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Function(File?)? onProfileUpdated;
  const ProfileScreen({super.key, this.onBack, this.onProfileUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User _currentUser;
  bool _isEditing = false;
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      _currentUser = user;
      _phoneController.text = user.phone ?? '';
      _passwordController.text = user.password;
      _loadSavedImage();
    }
  }

  Future<void> _loadSavedImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_${_currentUser.id}');
    
    if (imagePath != null && imagePath.isNotEmpty) {
      if (kIsWeb) {
        if (imagePath.startsWith('data:image')) {
          setState(() {
            _selectedImageBytes = base64Decode(imagePath.split(',').last);
          });
        }
      } else {
        final file = File(imagePath);
        if (await file.exists()) {
          setState(() {
            _selectedImage = file;
          });
        }
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    
    String? newPhotoUrl = _currentUser.photoUrl;
    if (_selectedImage != null || _selectedImageBytes != null) {
      final prefs = await SharedPreferences.getInstance();
      if (kIsWeb && _selectedImageBytes != null) {
        final base64Image = 'data:image/png;base64,${base64Encode(_selectedImageBytes!)}';
        await prefs.setString('profile_image_${_currentUser.id}', base64Image);
        newPhotoUrl = base64Image;
      } else if (!kIsWeb && _selectedImage != null) {
        await prefs.setString('profile_image_${_currentUser.id}', _selectedImage!.path);
        newPhotoUrl = _selectedImage!.path;
      }
    }

    final updatedUser = _currentUser.copyWith(
      phone: _phoneController.text.trim(),
      password: _passwordController.text.trim(),
      photoUrl: newPhotoUrl,
    );
    
    try {
       await DatabaseHelper.instance.updateUser(updatedUser);
       
       await NotificationService().notifyUser(
         userId: updatedUser.id!, 
         title: 'Profil mis à jour', 
         message: 'Vos informations ont été modifiées avec succès',
         type: 'SUCCESS'
       );
       
       if (mounted) {
         setState(() {
           _currentUser = updatedUser;
           _isEditing = false;
         });
          
          Provider.of<AuthService>(context, listen: false).updateCurrentUser(updatedUser);
          
          if (widget.onProfileUpdated != null) {
            widget.onProfileUpdated!(_selectedImage);
          }

         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Profil mis à jour avec succès'), backgroundColor: AppTheme.accentGreen),
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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          if (kIsWeb) {
            _selectedImageBytes = bytes;
          } else {
            _selectedImage = File(image.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading 
      ? const Center(child: CircularProgressIndicator())
      : Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.primaryBlue,
                          backgroundImage: kIsWeb 
                            ? (_selectedImageBytes != null ? MemoryImage(_selectedImageBytes!) : null)
                            : (_selectedImage != null ? FileImage(_selectedImage!) : null),
                          child: (kIsWeb ? _selectedImageBytes == null : _selectedImage == null)
                               ? Text(
                                   _currentUser.nom.isNotEmpty ? _currentUser.nom[0].toUpperCase() : '?',
                                   style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                                 )
                               : null,
                        ),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentUser.nom,
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  Text(
                    _currentUser.role.displayName,
                    style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  
                  _buildProfileCard(),
                ],
              ),
            ),
            Positioned(
              top: 24,
              right: 24,
              child: FloatingActionButton.small(
                onPressed: () {
                  if (_isEditing) {
                    _saveProfile();
                  } else {
                    setState(() => _isEditing = true);
                  }
                },
                backgroundColor: AppTheme.primaryBlue,
                child: Icon(_isEditing ? Icons.check_rounded : Icons.edit_rounded, color: Colors.white),
              ),
            ),
          ],
        );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildInfoRow('Email', _currentUser.email, icon: Icons.email_outlined),
          const Divider(height: 32),
          _buildEditableRow('Téléphone', _phoneController, icon: Icons.phone_outlined),
          const Divider(height: 32),
          _buildEditableRow('Mot de passe', _passwordController, icon: Icons.lock_outline, isPassword: true),
          if (_currentUser.role == UserRole.stagiaire && _currentUser.matricule != null) ...[
             const Divider(height: 32),
             _buildInfoRow('Matricule', _currentUser.matricule!, icon: Icons.badge_outlined),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {required IconData icon}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.textSecondary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
              Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
            ],
          ),
        ),
        if (label == 'Email' || label == 'Matricule') 
           const Icon(Icons.lock, size: 16, color: Colors.grey),
      ],
    );
  }

  Widget _buildEditableRow(String label, TextEditingController controller, {required IconData icon, bool isPassword = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.textSecondary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
              _isEditing
                  ? TextFormField(
                      controller: controller,
                      obscureText: isPassword && _obscurePassword,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryBlue)),
                        suffixIcon: isPassword 
                          ? IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18,
                                color: AppTheme.textSecondary,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            )
                          : null,
                      ),
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                    )
                  : Text(
                      isPassword ? (_obscurePassword ? '••••••••' : controller.text) : (controller.text.isEmpty ? 'Non renseigné' : controller.text),
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                    ),
              if (!_isEditing && isPassword)
                IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
