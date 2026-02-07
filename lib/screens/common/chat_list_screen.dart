import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../data/database_helper.dart';
import '../../theme/app_theme.dart';
import 'chat_screen.dart';
import 'user_search_delegate.dart';

class ChatListScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ChatListScreen({super.key, this.onBack});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _groupsWithStudents = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadGroupsAndStudents();

    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isLoading) {
        _loadConversations(showLoading: false);
        _loadGroupsAndStudents(showLoading: false);
      }
    });
  }

  Future<void> _loadGroupsAndStudents({bool showLoading = true}) async {
    if (showLoading) {
    }
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user?.role == UserRole.dp) {
      final groups = await DatabaseHelper.instance.getAllGroupes(directorId: user?.id);
      List<Map<String, dynamic>> data = [];
      for (var group in groups) {
        final students = await DatabaseHelper.instance.getStagiairesByGroupe(group.id!);
        if (students.isNotEmpty) {
          data.add({
            'id': group.id,
            'nom': group.nom,
            'students': students,
          });
        }
      }
      if (mounted) {
        setState(() => _groupsWithStudents = data);
      }
    } else if (user?.role == UserRole.formateur) {
      final groups = await DatabaseHelper.instance.getGroupsForFormateur(user!.id!);
      List<Map<String, dynamic>> data = [];
      for (var group in groups) {
         final groupId = group.id!;
         final students = await DatabaseHelper.instance.getStagiairesByGroupe(groupId);
         data.add({
            'id': groupId,
            'nom': group.nom,
            'students': students,
         });
      }
       if (mounted) {
        setState(() => _groupsWithStudents = data);
      }
    } else if (user?.role == UserRole.stagiaire && user?.groupeId != null) {
      final db = await DatabaseHelper.instance.database;
      final groupResult = await db.query(
        'groupes',
        where: 'id = ?',
        whereArgs: [user!.groupeId],
      );
      
      if (groupResult.isNotEmpty) {
        final groupData = groupResult.first;
        final students = await DatabaseHelper.instance.getStagiairesByGroupe(user.groupeId!);
        
        if (mounted) {
          setState(() {
            _groupsWithStudents = [{
              'id': groupData['id'],
              'nom': groupData['nom'],
              'students': students,
            }];
          });
        }
      }
    }
  }

  Future<void> _loadConversations({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      final conversations = await DatabaseHelper.instance.getConversations(user.id!);
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  _buildSearchField(),
                  if (_groupsWithStudents.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Text(
                        'Groupes et Stagiaires',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    ..._groupsWithStudents.map((g) => _buildGroupExpansionTile(g)),
                    const Divider(indent: 24, endIndent: 24),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Text(
                      'Messages récents',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  if (_conversations.isEmpty)
                    _buildEmptyState()
                  else
                    ..._conversations.map((conv) => _buildConversationTile(conv)).toList(),
                ],
              ),
              Positioned(
                bottom: 24,
                right: 24,
                child: FloatingActionButton(
                  onPressed: () {
                    final user = Provider.of<AuthService>(context, listen: false).currentUser;
                    showSearch(context: context, delegate: UserSearchDelegate(directorId: user?.id)).then((selectedUser) {
                      if (selectedUser != null && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatScreen(otherUser: selectedUser)),
                        ).then((_) => _loadConversations());
                      }
                    });
                  },
                  backgroundColor: AppTheme.primaryBlue,
                  child: const Icon(Icons.edit, color: Colors.white),
                ),
              ),
            ],
          );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: TextField(
          readOnly: true,
          onTap: () {
            final user = Provider.of<AuthService>(context, listen: false).currentUser;
            showSearch(context: context, delegate: UserSearchDelegate(directorId: user?.id)).then((selectedUser) {
              if (selectedUser != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChatScreen(otherUser: selectedUser)),
                ).then((_) => _loadConversations());
              }
            });
          },
          decoration: InputDecoration(
            hintText: 'Rechercher un contact...',
            hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 14),
            border: InputBorder.none,
            icon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupExpansionTile(Map<String, dynamic> groupData) {
    final groupName = groupData['nom'] as String;
    final List<User> students = groupData['students'] as List<User>;

    return ExpansionTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.groups_rounded, color: AppTheme.primaryBlue, size: 20),
      ),
      title: Text(groupName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text('${students.length} stagiaires', style: GoogleFonts.poppins(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryBlue, size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    groupId: groupData['id'],
                    groupName: groupName,
                  ),
                ),
              ).then((_) => _loadConversations());
            },
            tooltip: 'Chat de groupe',
          ),
          const Icon(Icons.expand_more, color: AppTheme.textSecondary),
        ],
      ),
      children: students.map((student) => ListTile(
        contentPadding: const EdgeInsets.only(left: 72, right: 16),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: AppTheme.stagiaireColor.withValues(alpha: 0.1),
          child: Text(student.nom[0], style: GoogleFonts.poppins(color: AppTheme.stagiaireColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        title: Text(student.nom, style: GoogleFonts.poppins(fontSize: 14)),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatScreen(otherUser: student)),
          ).then((_) => _loadConversations());
        },
      )).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Aucune conversation',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          Text(
            'Commencez à discuter avec vos contacts',
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conv) {
    final bool isGroup = (conv['is_group'] as int? ?? 0) == 1;
    final String lastMessage = conv['last_message'] as String? ?? '';
    final String? lastTimeStr = conv['last_time'] as String?;
    final int unreadCount = conv['unread_count'] as int? ?? 0;
    
    final String name = conv['nom'] as String;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: isGroup 
            ? AppTheme.accentOrange.withValues(alpha: 0.1)
            : AppTheme.primaryBlue.withValues(alpha: 0.1),
        child: isGroup
            ? const Icon(Icons.groups_rounded, color: AppTheme.accentOrange)
            : Text(
                name[0].toUpperCase(),
                style: GoogleFonts.poppins(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 18),
              ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (lastTimeStr != null)
            Text(
              _formatDate(DateTime.parse(lastTimeStr)),
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              lastMessage,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: unreadCount > 0 ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppTheme.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount.toString(),
                style: GoogleFonts.poppins(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      onTap: () {
        if (isGroup) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                groupId: conv['id'] as int,
                groupName: name,
              ),
            ),
          ).then((_) => _loadConversations());
        } else {
          final otherUser = User(
            id: conv['id'] as int,
            nom: name,
            email: conv['email'] as String? ?? '',
            password: '',
            role: UserRoleExtension.fromDbValue(conv['role'] as String? ?? 'STAGIAIRE'),
            phone: conv['phone'] as String?,
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatScreen(otherUser: otherUser)),
          ).then((_) => _loadConversations());
        }
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}
