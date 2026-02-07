import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../dp/dp_dashboard.dart';
import '../formateur/formateur_dashboard.dart';
import '../stagiaire/stagiaire_dashboard.dart';
import 'account_request_dialog.dart';
import 'director_signup_dialog.dart';
import 'forgot_password_dialog.dart';
import '../../widgets/responsive_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = false;
  
  UserRole? _selectedRole;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez sélectionner un rôle', style: GoogleFonts.poppins()),
          backgroundColor: AppTheme.accentOrange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      final actualRole = authService.currentUser!.role;
      
      if (_selectedRole != null && actualRole != _selectedRole) {
        await authService.logout();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erreur: Ce compte n\'est pas un compte ${_getRoleLabel(_selectedRole!)}.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      _navigateToDashboard(actualRole);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Email ou mot de passe incorrect',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppTheme.accentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => dashboard),
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
                    'La plateforme d\'excellence pédagogique',
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
              child: _buildLoginContent(),
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
          child: _buildLoginContent(isMobile: true),
        ),
      ),
    );
  }

  Widget _buildLoginContent({bool isMobile = false}) {
    final welcomeSize = ResponsiveLayout.respSize(context, 36, 42, 48);
    final subWelcomeSize = ResponsiveLayout.respSize(context, 18, 19, 20);
    final labelSize = ResponsiveLayout.respSize(context, 16, 17, 18);

    return Column(
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
            child: Image.asset('assets/images/logo.jpg', width: 90, height: 90),
          ),
          const SizedBox(height: 24),
          Text(
            'Academic Pro',
            style: GoogleFonts.poppins(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            'Gestion Pédagogique',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 48),
        ],

        Text(
          'Bienvenue',
          style: GoogleFonts.poppins(
            fontSize: welcomeSize,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connectez-vous pour accéder à votre espace',
          style: GoogleFonts.poppins(
            fontSize: subWelcomeSize,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 40),

        Text(
          'Sélectionnez votre rôle',
          style: GoogleFonts.poppins(
            fontSize: labelSize,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildRoleOption(
          role: UserRole.dp,
          label: 'Directeur Pédagogique',
          sublabel: 'Gestion globale et validation',
          icon: Icons.school_outlined,
          color: const Color(0xFF0EA5E9),
        ),
        const SizedBox(height: 12),
        _buildRoleOption(
          role: UserRole.formateur,
          label: 'Formateur',
          sublabel: 'Saisie avancement et notes',
          icon: Icons.book_outlined,
          color: AppTheme.formateurColor, 
        ),
        const SizedBox(height: 12),
        _buildRoleOption(
          role: UserRole.stagiaire,
          label: 'Stagiaire',
          sublabel: 'Consultation notes et emploi',
          icon: Icons.people_outline_rounded,
          color: AppTheme.stagiaireColor, 
        ),
        
        const SizedBox(height: 32),

        _buildLoginForm(),

        const SizedBox(height: 24),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _showForgotPasswordDialog,
              child: Text(
                'Mot de passe oublié ?',
                style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: ResponsiveLayout.respSize(context, 16, 17, 18),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 20, color: Colors.grey.shade300),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _showDirectorSignupDialog,
              child: Text(
                'Créer un compte',
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveLayout.respSize(context, 16, 17, 18),
                ),
              ),
            ),
          ],
        ),

        Center(
          child: InkWell(
            onTap: _showRequestAccountDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: Text(
                'Demander un compte',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveLayout.respSize(context, 16, 17, 18),
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),
        _buildDemoInfo(),
      ],
    );
  }

  Widget _buildRoleOption({
    required UserRole role,
    required String label,
    required String sublabel,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedRole == role;
    
    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: isSelected ? null : Border.all(color: Colors.grey.shade200),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : AppTheme.textPrimary,
                      fontSize: ResponsiveLayout.respSize(context, 16, 17, 18),
                    ),
                  ),
                  Text(
                    sublabel,
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade500,
                      fontSize: ResponsiveLayout.respSize(context, 14, 15, 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Email ou Matricule',
            style: GoogleFonts.poppins(
              fontSize: ResponsiveLayout.respSize(context, 14, 15, 16),
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              hintText: 'votre.email@poledigital.ma',
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade500),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryBlue),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) => value == null || value.isEmpty ? 'Requis' : null,
          ),
          const SizedBox(height: 20),
          
          Text(
            'Mot de passe',
            style: GoogleFonts.poppins(
              fontSize: ResponsiveLayout.respSize(context, 14, 15, 16),
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.lock_outlined, color: Colors.grey.shade500),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.grey.shade500,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryBlue),
              ),
            ),
            obscureText: _obscurePassword,
            validator: (value) => value == null || value.isEmpty ? 'Requis' : null,
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: ResponsiveLayout.respSize(context, 50, 56, 62),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      'Se connecter',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveLayout.respSize(context, 16, 17, 18),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => const AccountRequestDialog(),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => const ForgotPasswordDialog(),
    );
  }

  void _showDirectorSignupDialog() {
    showDialog(
      context: context,
      builder: (context) => const DirectorSignupDialog(),
    );
  }

  String _getRoleLabel(UserRole role) {
    switch (role) {
      case UserRole.dp: return 'Directeur Pédagogique';
      case UserRole.formateur: return 'Formateur';
      case UserRole.stagiaire: return 'Stagiaire';
    }
  }

  Widget _buildDemoInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: _buildDemoButton(UserRole.dp, 'DP', 'dp@digitalpole.ma'),
      ),
    );
  }

  Widget _buildDemoButton(UserRole role, String label, String email) {
    return InkWell(
      onTap: () {
        setState(() => _selectedRole = role);
        _emailController.text = email;
        if (role == UserRole.dp) _passwordController.text = 'dp123456';
        if (role == UserRole.formateur) _passwordController.text = 'trainer123';
        if (role == UserRole.stagiaire) _passwordController.text = 'student123';
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: ResponsiveLayout.respSize(context, 14, 16, 18), 
            fontWeight: FontWeight.w500
          ),
        ),
      ),
    );
  }
}
