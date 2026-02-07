import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../dp/dp_dashboard.dart';
import '../formateur/formateur_dashboard.dart';
import '../stagiaire/stagiaire_dashboard.dart';
import '../../widgets/responsive_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  UserRole _selectedRole = UserRole.stagiaire;
  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Les mots de passe ne correspondent pas');
      return;
    }

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.register(
      nom: _nomController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      _navigateToDashboard(authService.currentUser!.role);
    } else if (mounted) {
      _showError('Erreur lors de l\'inscription. L\'email est peut-être déjà utilisé.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _navigateToDashboard(UserRole role) {
    Widget dashboard;
    switch (role) {
      case UserRole.dp:
        dashboard = const DPDashboard();
        break;
      case UserRole.formateur:
        dashboard = const FormateurDashboard();
        break;
      case UserRole.stagiaire:
        dashboard = const StagiaireDashboard();
        break;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => dashboard),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(),
        tablet: _buildDesktopLayout(isTablet: true),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout({bool isTablet = false}) {
    return Row(
      children: [
        Expanded(
          flex: 45,
          child: Container(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.05),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(
                    padding: EdgeInsets.all(isTablet ? 24 : 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.jpg', 
                      width: isTablet ? 80 : 100, 
                      height: isTablet ? 80 : 100
                    ),
                  ),
                  SizedBox(height: isTablet ? 30 : 40),
                  Text(
                    'Academic Pro',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 34 : 42,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Rejoignez l\'excellence pédagogique',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 16 : 18,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 55,
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isTablet ? 32 : 48),
              child: _buildRegisterContent(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildRegisterContent(isMobile: true),
        ),
      ),
    );
  }

  Widget _buildRegisterContent({bool isMobile = false}) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            if (isMobile) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Image.asset('assets/images/logo.jpg', width: 60, height: 60),
              ),
              const SizedBox(height: 24),
              Text(
                'Academic Pro',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 48),
            ],

            _buildHeader(),
            const SizedBox(height: 32),
            _buildRoleSelection(),
            const SizedBox(height: 24),
            _buildRegisterForm(),
            const SizedBox(height: 24),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: ResponsiveLayout.isMobile(context) ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          'Créer un compte',
          style: GoogleFonts.poppins(
            fontSize: ResponsiveLayout.respSize(context, 28, 34, 40),
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Rejoignez la plateforme Academic Pro',
          style: GoogleFonts.poppins(
            fontSize: ResponsiveLayout.respSize(context, 14, 15, 16),
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: UserRole.values.map((role) {
        final isSelected = _selectedRole == role;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FilterChip(
            selected: isSelected,
            label: Text(role.displayName),
            onSelected: (selected) {
              if (selected) setState(() => _selectedRole = role);
            },
            selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
            checkmarkColor: AppTheme.primaryBlue,
            labelStyle: GoogleFonts.poppins(
              color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nomController,
            decoration: const InputDecoration(
              labelText: 'Nom complet',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) => value == null || value.length < 6 ? 'Minimum 6 caractères' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscurePassword,
            decoration: const InputDecoration(
              labelText: 'Confirmer le mot de passe',
              prefixIcon: Icon(Icons.lock_clock_outlined),
            ),
            validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: ResponsiveLayout.respSize(context, 56, 60, 64),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: EdgeInsets.symmetric(vertical: ResponsiveLayout.respSize(context, 14, 16, 18)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'S\'inscrire', 
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveLayout.respSize(context, 16, 17, 18), 
                        fontWeight: FontWeight.w600
                      )
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginLink() {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(
        'Déjà un compte ? Se connecter',
        style: GoogleFonts.poppins(
          color: AppTheme.primaryBlue, 
          fontWeight: FontWeight.w500,
          fontSize: ResponsiveLayout.respSize(context, 14, 15, 16)
        ),
      ),
    );
  }
}

