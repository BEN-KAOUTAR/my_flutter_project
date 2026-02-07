import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user_request.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../data/database_helper.dart';
import '../../providers/notification_provider.dart';

class InscriptionRequestsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const InscriptionRequestsScreen({super.key, this.onBack});

  @override
  State<InscriptionRequestsScreen> createState() => _InscriptionRequestsScreenState();
}

class _InscriptionRequestsScreenState extends State<InscriptionRequestsScreen> {
  bool _isLoading = true;
  List<UserRequest> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      final reqs = await DatabaseHelper.instance.getUserRequests(user.id!);
      setState(() {
        _requests = reqs;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRequest(UserRequest request, bool accept) async {
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    try {
      await DatabaseHelper.instance.updateUserRequestStatus(
        request.id!,
        accept ? 'ACCEPTEE' : 'REFUSEE',
      );

      if (accept) {
        int? resolvedGroupId;
        if (request.role == 'STAGIAIRE' && request.groupe != null) {
          final groupModel = await DatabaseHelper.instance.getGroupeByName(request.groupe!);
          resolvedGroupId = groupModel?.id;
        }

        final newUser = User(
          nom: request.nom,
          email: request.email,
          password: '123456', 
          role: UserRoleExtension.fromDbValue(request.role),
          groupeId: resolvedGroupId,
          phone: request.phone,
          directorId: currentUser?.id,
        );
        
        await DatabaseHelper.instance.insertUser(newUser);
      }

      if (mounted) {
        final user = Provider.of<AuthService>(context, listen: false).currentUser;
        Provider.of<NotificationProvider>(context, listen: false).refreshCounts(user);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Demande acceptée' : 'Demande refusée'),
            backgroundColor: accept ? AppTheme.accentGreen : AppTheme.accentRed,
          ),
        );
      }
      
      _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _requests.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune demande en attente',
                      style: GoogleFonts.poppins(fontSize: 18, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  final req = _requests[index];
                  return _buildRequestCard(req);
                },
              );
  }

  Widget _buildRequestCard(UserRequest req) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: req.role == 'FORMATEUR' 
                        ? AppTheme.formateurColor.withValues(alpha: 0.1) 
                        : req.role == 'DP'
                            ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                            : AppTheme.stagiaireColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    req.role == 'DP' ? 'DIRECTEUR' : req.role,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: req.role == 'FORMATEUR' 
                          ? AppTheme.formateurColor 
                          : req.role == 'DP' 
                              ? AppTheme.primaryBlue 
                              : AppTheme.stagiaireColor,
                    ),
                  ),
                ),
                Text(
                  '${req.timestamp.day}/${req.timestamp.month} ${req.timestamp.hour}:${req.timestamp.minute}',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              req.nom,
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            Text(
              req.email,
              style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
            ),
            if (req.phone != null && req.phone!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone_outlined, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    req.phone!,
                    style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
            if (req.role == 'STAGIAIRE' && req.groupe != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.group_outlined, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('${req.groupe} - Année ${req.annee}', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleRequest(req, false),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Refuser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentRed,
                      side: const BorderSide(color: AppTheme.accentRed),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleRequest(req, true),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accepter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

