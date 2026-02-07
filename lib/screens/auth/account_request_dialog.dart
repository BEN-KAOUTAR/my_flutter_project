import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user.dart';
import '../../models/groupe.dart';
import '../../theme/app_theme.dart';
import '../../data/database_helper.dart';
import '../../models/user_request.dart';
import '../../widgets/responsive_layout.dart';

class AccountRequestDialog extends StatefulWidget {
  const AccountRequestDialog({super.key});

  @override
  State<AccountRequestDialog> createState() => _AccountRequestDialogState();
}

class _AccountRequestDialogState extends State<AccountRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  String? _selectedRole;
  User? _selectedDirector;
  Groupe? _selectedGroupe;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  List<User> _directors = [];
  List<Groupe> _groupes = [];

  @override
  void initState() {
    super.initState();
    _loadDirectors();
  }

  Future<void> _loadDirectors() async {
    final dps = await DatabaseHelper.instance.getUsersByRole(UserRole.dp);
    setState(() {
      _directors = dps;
    });
  }

  Future<void> _loadGroupes(int directorId) async {
    final groups = await DatabaseHelper.instance.getGroupesByDirectorId(directorId);
    setState(() {
      _groupes = groups;
      _selectedGroupe = null;
    });
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez un rôle')));
      return;
    }
    if (_selectedDirector == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez un directeur')));
      return;
    }
    if (_selectedRole == 'STAGIAIRE' && _selectedGroupe == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez un groupe')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final request = UserRequest(
        nom: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _selectedRole!,
        groupe: _selectedRole == 'STAGIAIRE' ? _selectedGroupe!.nom : null,
        annee: _selectedRole == 'STAGIAIRE' ? _selectedGroupe!.annee.toString() : null,
        directorId: _selectedDirector!.id!,
        timestamp: DateTime.now(),
      );

      await DatabaseHelper.instance.createUserRequest(request);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Demande envoyée à ${_selectedDirector!.nom}'),
            backgroundColor: AppTheme.accentGreen,
          ),
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
        constraints: BoxConstraints(
          maxWidth: ResponsiveLayout.respSize(context, 500, 650, 800)
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Demande de Création de Compte',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveLayout.respSize(context, 20, 24, 28), 
                    fontWeight: FontWeight.bold
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Envoyez une demande au Directeur Pédagogique pour créer votre compte.',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveLayout.respSize(context, 13, 14, 15), 
                    color: AppTheme.textSecondary
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                DropdownButtonFormField<User>(
                  decoration: const InputDecoration(labelText: 'Directeur Pédagogique'),
                  value: _selectedDirector,
                  items: _directors.map((dp) => DropdownMenuItem(value: dp, child: Text(dp.nom))).toList(),
                  onChanged: (val) {
                    setState(() => _selectedDirector = val);
                    if (val != null) {
                      _loadGroupes(val.id!);
                    }
                  },
                  validator: (val) => val == null ? 'Requis' : null,
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Votre Rôle'),
                  value: _selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'STAGIAIRE', child: Text('Stagiaire')),
                    DropdownMenuItem(value: 'FORMATEUR', child: Text('Formateur')),
                  ],
                  onChanged: (val) => setState(() => _selectedRole = val),
                  validator: (val) => val == null ? 'Requis' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nom & Prénom', prefixIcon: Icon(Icons.person_outline)),
                  validator: (val) => val!.isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Requis';
                    if (!val.contains('@')) return 'Email invalide (doit contenir @)';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Téléphone (ex: 06... ou +2126...)', prefixIcon: Icon(Icons.phone_outlined)),
                  keyboardType: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Requis';
                    final phoneRegex = RegExp(r'^(0|\+212)\d{9}$');
                    if (!phoneRegex.hasMatch(val.replaceAll(' ', ''))) {
                      return 'Format: 0... ou +212... (10 chiffres)';
                    }
                    return null;
                  },
                ),
                
                if (_selectedRole == 'STAGIAIRE') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Groupe>(
                          decoration: const InputDecoration(labelText: 'Groupe'),
                          value: _selectedGroupe,
                          items: _groupes.map((g) => DropdownMenuItem(value: g, child: Text(g.nom))).toList(),
                          onChanged: (val) => setState(() => _selectedGroupe = val),
                          validator: (val) => val == null ? 'Requis' : null,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 32),
                
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Annuler', 
                          style: GoogleFonts.poppins(
                            color: AppTheme.textSecondary,
                            fontSize: ResponsiveLayout.respSize(context, 14, 16, 18)
                          )
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                'Envoyer',
                                style: GoogleFonts.poppins(
                                  fontSize: ResponsiveLayout.respSize(context, 14, 16, 18)
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

