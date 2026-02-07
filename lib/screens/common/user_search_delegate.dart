import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user.dart';
import '../../data/database_helper.dart';
import '../../theme/app_theme.dart';

class UserSearchDelegate extends SearchDelegate<User?> {
  final int? directorId;
  UserSearchDelegate({this.directorId});

  @override
  String get searchFieldLabel => 'Rechercher un utilisateur...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return Center(
        child: Text(
          'Entrez un nom ou email',
          style: GoogleFonts.poppins(color: AppTheme.textSecondary),
        ),
      );
    }

    return FutureBuilder<List<User>>(
      future: DatabaseHelper.instance.searchUsers(query, directorId: directorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'Aucun utilisateur trouvé',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
          );
        }

        final users = snapshot.data!;
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                child: Text(
                  user.nom[0].toUpperCase(),
                  style: GoogleFonts.poppins(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(user.nom, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: Text('${user.role.displayName} • ${user.email}', style: GoogleFonts.poppins(fontSize: 12)),
              onTap: () => close(context, user),
            );
          },
        );
      },
    );
  }
}
