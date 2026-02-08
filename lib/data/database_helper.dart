import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/filiere.dart';
import '../models/groupe.dart';
import '../models/module.dart';
import '../models/affectation.dart';
import '../models/seance.dart';
import '../models/note.dart';
import '../models/emploi.dart';
import '../models/message.dart';
import '../models/user_request.dart';
import '../models/reclamation.dart';
import '../models/notification_model.dart';
import 'dart:async';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static const int _databaseVersion = 31;
  static Database? _database;

  DatabaseHelper._init();
  
  
  final _onDataChange = StreamController<void>.broadcast();
  Stream<void> get onDataChange => _onDataChange.stream;

  void notifyDataChanged() {
    _onDataChange.add(null);
  }

  
  Future<int> createNotification(NotificationModel notification) async {
    final db = await database;
    final id = await db.insert('notifications', notification.toMap());
    notifyDataChanged();
    return id;
  }

  Future<List<User>> getUsersByGroupe(int groupeId) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'groupe_id = ?',
      whereArgs: [groupeId],
    );
    return result.map((map) => User.fromMap(map)).toList();
  }

  Future<Database> get database async {
    try {
      if (_database != null) return _database!;
      _database = await _initDB('academic_pro.db');
      
      
      final usersCount = Sqflite.firstIntValue(await _database!.rawQuery('SELECT COUNT(*) FROM users')) ?? 0;
      if (usersCount == 0) {
        await _seedData(_database!);
      }
      
      return _database!;
    } catch (e) {
      debugPrint('Database access error: $e');
      rethrow;
    }
  }

  Future<Database> _initDB(String filePath) async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      debugPrint('Database initialization error: $e');
      rethrow;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN phone TEXT');
      } catch (e) {}

      try {
        await db.execute('ALTER TABLE users ADD COLUMN photo_url TEXT');
      } catch (e) {}
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sender_id INTEGER NOT NULL,
          receiver_id INTEGER NOT NULL,
          content TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          is_read INTEGER DEFAULT 0,
          FOREIGN KEY (sender_id) REFERENCES users (id),
          FOREIGN KEY (receiver_id) REFERENCES users (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_requests (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nom TEXT NOT NULL,
          email TEXT NOT NULL,
          role TEXT NOT NULL,
          groupe TEXT,
          annee TEXT,
          director_id INTEGER NOT NULL,
          timestamp TEXT NOT NULL,
          status TEXT DEFAULT 'EN_ATTENTE',
          FOREIGN KEY (director_id) REFERENCES users (id)
        )
      ''');
    }
  
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reclamations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          subject TEXT NOT NULL,
          message TEXT NOT NULL,
          type TEXT NOT NULL,
          status TEXT DEFAULT 'EN_ATTENTE',
          timestamp TEXT NOT NULL,
          response TEXT,
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');
    }

    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          message TEXT NOT NULL,
          type TEXT DEFAULT 'INFO',
          is_read INTEGER DEFAULT 0,
          timestamp TEXT NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');
    }

    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN group_id INTEGER REFERENCES groupes(id)');
      } catch (e) {
      }
    }

    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN birth_date TEXT');
      } catch (e) {
      }
    }

    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE exams (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          affectation_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          type TEXT NOT NULL,
          description TEXT,
          status TEXT DEFAULT 'PLANIFIE',
          FOREIGN KEY (affectation_id) REFERENCES affectations (id)
        )
      ''');
    }

    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS exams (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          affectation_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          type TEXT NOT NULL,
          description TEXT,
          status TEXT DEFAULT 'PLANIFIE',
          FOREIGN KEY (affectation_id) REFERENCES affectations (id)
        )
      ''');
    }

    if (oldVersion < 14) {
      try {
        final columns = await db.rawQuery('PRAGMA table_info(reclamations)');
        final columnNames = columns.map((c) => c['name'] as String? ?? '').toList();
        
        if (!columnNames.contains('attachment_url')) {
          await db.execute('ALTER TABLE reclamations ADD COLUMN attachment_url TEXT');
        }
        if (!columnNames.contains('attachment_type')) {
          await db.execute('ALTER TABLE reclamations ADD COLUMN attachment_type TEXT');
        }
      } catch (e) {
        debugPrint('Migration error v14: $e');
      }
    }

    if (oldVersion < 15) {
      try {
        final columns = await db.rawQuery('PRAGMA table_info(notes)');
        final columnNames = columns.map((c) => c['name'] as String? ?? '').toList();
        
        if (!columnNames.contains('statut')) {
          await db.execute("ALTER TABLE notes ADD COLUMN statut TEXT DEFAULT 'Valide'");
        }
      } catch (e) {
        debugPrint('Migration error v15: $e');
      }
    }
    if (oldVersion < 16) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS exams (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          affectation_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          type TEXT NOT NULL,
          description TEXT,
          status TEXT DEFAULT 'PLANIFIE',
          FOREIGN KEY (affectation_id) REFERENCES affectations (id)
        )
      ''');
    }
    
    if (oldVersion < 17) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS presences (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          stagiaire_id INTEGER NOT NULL,
          groupe_id INTEGER,
          date TEXT NOT NULL,
          statut TEXT DEFAULT 'PRESENT',
          valide_par_dp INTEGER DEFAULT 0,
          timestamp TEXT,
          FOREIGN KEY (stagiaire_id) REFERENCES users (id)
        )
      ''');
    }

    if (oldVersion < 18) {
      try {
        await db.execute('DROP TABLE IF EXISTS presences');
        await db.execute('''
          CREATE TABLE presences (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stagiaire_id INTEGER NOT NULL,
            groupe_id INTEGER,
            date TEXT NOT NULL,
            statut TEXT DEFAULT 'PRESENT',
            valide_par_dp INTEGER DEFAULT 0,
            timestamp TEXT,
            FOREIGN KEY (stagiaire_id) REFERENCES users (id)
          )
        ''');
      } catch (e) {
      }
    }

    if (oldVersion < 19) {
      try {
        final columns = await db.rawQuery('PRAGMA table_info(users)');
        final columnNames = columns.map((c) => c['name'] as String? ?? '').toList();
        
        final requiredColumns = {
          'photo_url': 'TEXT',
          'phone': 'TEXT',
          'birth_date': 'TEXT',
          'invitation_status': "TEXT DEFAULT 'En attente'",
          'matricule': 'TEXT',
          'specialite': 'TEXT',
          'total_heures_affectees': 'REAL DEFAULT 0',
          'groupe_id': 'INTEGER'
        };

        for (var entry in requiredColumns.entries) {
          if (!columnNames.contains(entry.key)) {
            await db.execute('ALTER TABLE users ADD COLUMN ${entry.key} ${entry.value}');
            debugPrint('Migration v19: Added column ${entry.key} to users table');
          }
        }
      } catch (e) {
        debugPrint('Migration error v19: $e');
      }
    }

    if (oldVersion < 20) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN director_id INTEGER REFERENCES users(id)');
        await db.execute('ALTER TABLE filieres ADD COLUMN director_id INTEGER REFERENCES users(id)');
        debugPrint('Migration v20: Added director_id to users and filieres');
      } catch (e) {
        debugPrint('Migration error v20: $e');
      }
    }

    if (oldVersion < 21) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS message_reads (
          message_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          PRIMARY KEY (message_id, user_id),
          FOREIGN KEY (message_id) REFERENCES messages (id),
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');
    }
    if (oldVersion < 22) {
      try {
        final columns = await db.rawQuery('PRAGMA table_info(presences)');
        final columnNames = columns.map((c) => c['name'] as String? ?? '').toList();
        
        if (!columnNames.contains('formateur_id')) {
          await db.execute('ALTER TABLE presences ADD COLUMN formateur_id INTEGER');
          debugPrint('Migration v22: Added formateur_id to presences');
        }
        if (!columnNames.contains('vu_par_dp')) {
          await db.execute('ALTER TABLE presences ADD COLUMN vu_par_dp INTEGER DEFAULT 0');
          debugPrint('Migration v22: Added vu_par_dp to presences');
        }
      } catch (e) {
        debugPrint('Migration error v22: $e');
      }
    }
    
    if (oldVersion < 23) {
      try {
        final columns = await db.rawQuery('PRAGMA table_info(users)');
        final columnNames = columns.map((c) => c['name'] as String? ?? '').toList();
        
        if (!columnNames.contains('phone')) {
          await db.execute('ALTER TABLE users ADD COLUMN phone TEXT');
          debugPrint('Migration v23: Added phone to users');
        }
        if (!columnNames.contains('birth_date')) {
          await db.execute('ALTER TABLE users ADD COLUMN birth_date TEXT');
          debugPrint('Migration v23: Added birth_date to users');
        }
        
        await db.execute('''
          CREATE TABLE IF NOT EXISTS message_reads (
            message_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            PRIMARY KEY (message_id, user_id),
            FOREIGN KEY (message_id) REFERENCES messages (id),
            FOREIGN KEY (user_id) REFERENCES users (id)
          )
        ''');
        debugPrint('Migration v23: Created message_reads table');
      } catch (e) {
        debugPrint('Migration error v23: $e');
      }
    }

    if (oldVersion < 24) {
      try {
        final columns = await db.rawQuery('PRAGMA table_info(user_requests)');
        final columnNames = columns.map((c) => c['name'] as String? ?? '').toList();
        
        if (!columnNames.contains('phone')) {
          await db.execute('ALTER TABLE user_requests ADD COLUMN phone TEXT');
          debugPrint('Migration v24: Added phone to user_requests');
        }
      } catch (e) {
        debugPrint('Migration error v24: $e');
      }
    }

    if (oldVersion < 25) {
      try {
        final columns = await db.rawQuery('PRAGMA table_info(seances)');
        final columnNames = columns.map((c) => c['name'] as String? ?? '').toList();
        
        if (!columnNames.contains('heure_debut')) {
          await db.execute('ALTER TABLE seances ADD COLUMN heure_debut TEXT');
          debugPrint('Migration v25: Added heure_debut to seances');
        }
      } catch (e) {
        debugPrint('Migration error v25: $e');
      }
    }

    if (oldVersion < 26) {
      try {
        final columns = await db.rawQuery('PRAGMA table_info(modules)');
        final columnNames = columns.map((c) => c['name'] as String? ?? '').toList();
        
        if (!columnNames.contains('coefficient')) {
          await db.execute('ALTER TABLE modules ADD COLUMN coefficient INTEGER DEFAULT 1');
          debugPrint('Migration v26: Added coefficient to modules');
        }
      } catch (e) {
        debugPrint('Migration error v26: $e');
      }
    }

    if (oldVersion < 28) {
      try {
        final columns = await db.rawQuery('PRAGMA table_info(presences)');
        final columnNames = columns.map((c) => c['name'] as String? ?? '').toList();
        
        if (!columnNames.contains('heure')) {
          await db.execute('ALTER TABLE presences ADD COLUMN heure TEXT');
          debugPrint('Migration v28: Added heure to presences');
        }
      } catch (e) {
        debugPrint('Migration error v28: $e');
      }
    }
    if (oldVersion < 29) {
      try {
        await db.execute('ALTER TABLE groupes ADD COLUMN annee_scolaire TEXT');
        await db.execute('ALTER TABLE modules ADD COLUMN annee INTEGER DEFAULT 1');
        await db.execute('ALTER TABLE modules ADD COLUMN semestre INTEGER DEFAULT 1');
        debugPrint('Migration v29: Added columns to groupes and modules');
      } catch (e) {
        debugPrint('Migration error v29: $e');
      }
    }
    if (oldVersion < 30) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN is_expert INTEGER DEFAULT 0');
        debugPrint('Migration v30: Added is_expert to users');
      } catch (e) {
        debugPrint('Migration error v30: $e');
      }
    }
    if (oldVersion < 31) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN annee_scolaire TEXT');
        debugPrint('Migration v31: Added annee_scolaire to users');
      } catch (e) {
        debugPrint('Migration error v31: $e');
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        total_heures_affectees REAL DEFAULT 0,
        groupe_id INTEGER,
        matricule TEXT,
        specialite TEXT,
        invitation_status TEXT DEFAULT 'En attente',
        photo_url TEXT,
        phone TEXT,
        birth_date TEXT,
        director_id INTEGER,
        is_expert INTEGER DEFAULT 0,
        annee_scolaire TEXT,
        FOREIGN KEY (groupe_id) REFERENCES groupes (id),
        FOREIGN KEY (director_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender_id INTEGER NOT NULL,
        receiver_id INTEGER,
        group_id INTEGER,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        attachment_type TEXT,
        attachment_url TEXT,
        FOREIGN KEY (sender_id) REFERENCES users (id),
        FOREIGN KEY (receiver_id) REFERENCES users (id),
        FOREIGN KEY (group_id) REFERENCES groupes (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT DEFAULT 'INFO',
        is_read INTEGER DEFAULT 0,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE user_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT,
        role TEXT NOT NULL,
        groupe TEXT,
        annee TEXT,
        director_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        status TEXT DEFAULT 'EN_ATTENTE',
        FOREIGN KEY (director_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE reclamations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        subject TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT DEFAULT 'EN_ATTENTE',
        timestamp TEXT NOT NULL,
        response TEXT,
        attachment_url TEXT,
        attachment_type TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE presences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stagiaire_id INTEGER NOT NULL,
        groupe_id INTEGER,
        date TEXT NOT NULL,
        heure TEXT,
        statut TEXT DEFAULT 'PRESENT',
        valide_par_dp INTEGER DEFAULT 0,
        vu_par_dp INTEGER DEFAULT 0,
        formateur_id INTEGER,
        timestamp TEXT,
        FOREIGN KEY (stagiaire_id) REFERENCES users (id),
        FOREIGN KEY (formateur_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE filieres (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        description TEXT,
        director_id INTEGER,
        FOREIGN KEY (director_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE groupes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        filiere_id INTEGER NOT NULL,
        annee INTEGER NOT NULL,
        annee_scolaire TEXT,
        photo_url TEXT,
        FOREIGN KEY (filiere_id) REFERENCES filieres (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE modules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        masse_horaire_totale REAL NOT NULL,
        filiere_id INTEGER NOT NULL,
        coefficient INTEGER DEFAULT 1,
        annee INTEGER DEFAULT 1,
        semestre INTEGER DEFAULT 1,
        photo_url TEXT,
        FOREIGN KEY (filiere_id) REFERENCES filieres (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE affectations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        formateur_id INTEGER NOT NULL,
        module_id INTEGER NOT NULL,
        groupe_id INTEGER NOT NULL,
        annee_scolaire TEXT NOT NULL,
        FOREIGN KEY (formateur_id) REFERENCES users (id),
        FOREIGN KEY (module_id) REFERENCES modules (id),
        FOREIGN KEY (groupe_id) REFERENCES groupes (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE seances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        affectation_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        heure_debut TEXT,
        duree REAL NOT NULL,
        contenu TEXT NOT NULL,
        statut TEXT DEFAULT 'EN_ATTENTE',
        FOREIGN KEY (affectation_id) REFERENCES affectations (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stagiaire_id INTEGER NOT NULL,
        module_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        valeur REAL NOT NULL,
        date_examen TEXT NOT NULL,
        validee INTEGER DEFAULT 0,
        publiee INTEGER DEFAULT 0,
        statut TEXT DEFAULT 'Valide',
        FOREIGN KEY (stagiaire_id) REFERENCES users (id),
        FOREIGN KEY (module_id) REFERENCES modules (id)
      )
    ''');


    await db.execute('''
      CREATE TABLE emplois (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        semaine_num INTEGER NOT NULL,
        groupe_id INTEGER NOT NULL,
        formateur_id INTEGER,
        donnees_json TEXT,
        pdf_url TEXT,
        FOREIGN KEY (groupe_id) REFERENCES groupes (id),
        FOREIGN KEY (formateur_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE exams (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        affectation_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT,
        status TEXT DEFAULT 'PLANIFIE',
        FOREIGN KEY (affectation_id) REFERENCES affectations (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE message_reads (
        message_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        PRIMARY KEY (message_id, user_id),
        FOREIGN KEY (message_id) REFERENCES messages (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    
    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    await db.insert('users', {
      'nom': 'Directeur Pédagogique',
      'email': 'dp@digitalpole.ma',
      'password': 'dp123456',
      'role': 'DP',
      'total_heures_affectees': 0,
    });
  }

  
  Future<User?> authenticateUser(String email, String password) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    if (result.isEmpty) return null;
    
    final user = User.fromMap(result.first);
    
    
    if (user.role != UserRole.dp && user.directorId == null) {
      debugPrint('Authentication failed: Non-DP user ${user.email} has no director_id');
      return null;
    }
    
    return user;
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final result = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
  }

  Future<List<User>> getUsersByRole(UserRole role, {int? directorId}) async {
    final db = await database;
    String where = 'role = ?';
    List<dynamic> args = [role.dbValue];
    
    if (directorId != null) {
      where += ' AND director_id = ?';
      args.add(directorId);
    }

    final result = await db.query(
      'users',
      where: where,
      whereArgs: args,
    );
    return result.map((map) => User.fromMap(map)).toList();
  }

  Future<List<User>> getFormateursWithModuleCount({int? directorId}) async {
    final db = await database;
    String query = '''
      SELECT u.*, COUNT(a.id) as module_count
      FROM users u
      LEFT JOIN affectations a ON u.id = a.formateur_id
      WHERE u.role = 'FORMATEUR'
    ''';
    
    List<dynamic> args = [];
    if (directorId != null) {
      query += ' AND u.director_id = ?';
      args.add(directorId);
    }
    
    query += ' GROUP BY u.id';
    
    final result = await db.rawQuery(query, args);
    return result.map((map) => User.fromMap(map)).toList();
  }

  Future<List<User>> getStagiairesByGroupe(int groupeId) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'role = ? AND groupe_id = ?',
      whereArgs: ['STAGIAIRE', groupeId],
    );
    return result.map((map) => User.fromMap(map)).toList();
  }

  Future<int> insertUser(User user) async {
    final db = await database;
    final id = await db.insert('users', user.toMap()..remove('id'));
    notifyDataChanged();
    return id;
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    final result = await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
    notifyDataChanged();
    return result;
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    final result = await db.delete('users', where: 'id = ?', whereArgs: [id]);
    notifyDataChanged();
    return result;
  }

  Future<bool> checkFormateurAvailability(int formateurId, int semaineNum, String jour, String heureDebut) async {
    final db = await database;
    final result = await db.query(
      'emplois',
      where: 'semaine_num = ?',
      whereArgs: [semaineNum],
    );

    for (var row in result) {
      final jsonStr = row['donnees_json'] as String?;
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          final List<dynamic> creneaux = jsonDecode(jsonStr);
          for (var c in creneaux) {
            if (c['formateur_id'] == formateurId && 
                c['jour'] == jour && 
                c['heure_debut'] == heureDebut) {
              return false;
            }
          }
        } catch (e) {
          debugPrint('Error parsing schedule JSON: $e');
        }
      }
    }
    return true;
  }


  Future<List<Filiere>> getAllFilieres({int? directorId}) async {
    final db = await database;
    if (directorId != null) {
      final result = await db.query('filieres', where: 'director_id = ?', whereArgs: [directorId]);
      return result.map((map) => Filiere.fromMap(map)).toList();
    }
    final result = await db.query('filieres');
    return result.map((map) => Filiere.fromMap(map)).toList();
  }

  Future<Filiere?> getFiliereById(int id) async {
    final db = await database;
    final result = await db.query('filieres', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Filiere.fromMap(result.first);
  }

  Future<int> insertFiliere(Filiere filiere) async {
    final db = await database;
    final existing = await db.query(
      'filieres',
      where: 'nom = ? AND director_id = ?',
      whereArgs: [filiere.nom, filiere.directorId],
    );
    if (existing.isNotEmpty) {
      throw Exception('Une filière avec ce nom existe déjà.');
    }
    return await db.insert('filieres', filiere.toMap()..remove('id'));
  }

  Future<int> updateFiliere(Filiere filiere) async {
    final db = await database;
    return await db.update(
      'filieres',
      filiere.toMap(),
      where: 'id = ?',
      whereArgs: [filiere.id],
    );
  }

  Future<int> deleteFiliere(int id) async {
    final db = await database;
    return await db.delete('filieres', where: 'id = ?', whereArgs: [id]);
  }


  Future<List<Groupe>> getAllGroupes({int? directorId}) async {
    final db = await database;
    if (directorId != null) {
      final result = await db.rawQuery('''
        SELECT g.* FROM groupes g
        JOIN filieres f ON g.filiere_id = f.id
        WHERE f.director_id = ?
      ''', [directorId]);
      return result.map((map) => Groupe.fromMap(map)).toList();
    }
    final result = await db.query('groupes');
    return result.map((map) => Groupe.fromMap(map)).toList();
  }

  Future<List<User>> getGroupStudents(int groupId) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'groupe_id = ? AND role = ?',
      whereArgs: [groupId, 'STAGIAIRE'],
    );
    return result.map((map) => User.fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getGroupsWithStudents() async {
    final db = await database;
    final groups = await db.query('groupes');
    List<Map<String, dynamic>> res = [];
    for (var g in groups) {
      final students = await db.query('users', where: 'groupe_id = ? AND role = ?', whereArgs: [g['id'], 'STAGIAIRE']);
      res.add({
        'id': g['id'],
        'nom': g['nom'],
        'students': students.map((map) => User.fromMap(map)).toList(),
      });
    }
    return res;
  }

  Future<List<Groupe>> getGroupesByFiliere(int filiereId) async {
    final db = await database;
    final result = await db.query(
      'groupes',
      where: 'filiere_id = ?',
      whereArgs: [filiereId],
    );
    return result.map((map) => Groupe.fromMap(map)).toList();
  }

  Future<Groupe?> getGroupeById(int id) async {
    final db = await database;
    final result = await db.query('groupes', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Groupe.fromMap(result.first);
  }

  Future<int> getGroupeStagiairesCount(int groupeId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM users WHERE groupe_id = ? AND role = ?',
      [groupeId, 'STAGIAIRE'],
    );
    return result.first['count'] as int;
  }

  Future<int> insertGroupe(Groupe groupe) async {
    final db = await database;
    final existing = await db.query(
      'groupes',
      where: 'nom = ? AND filiere_id = ? AND annee = ? AND annee_scolaire = ?',
      whereArgs: [groupe.nom, groupe.filiereId, groupe.annee, groupe.anneeScolaire],
    );
    if (existing.isNotEmpty) {
      throw Exception('Un groupe avec ce nom existe déjà dans cette filière.');
    }
    final result = await db.insert('groupes', groupe.toMap());
    notifyDataChanged();
    return result;
  }

  Future<int> updateGroupe(Groupe groupe) async {
    final db = await database;
    final result = await db.update(
      'groupes',
      groupe.toMap(),
      where: 'id = ?',
      whereArgs: [groupe.id],
    );
    notifyDataChanged();
    return result;
  }

  Future<int> deleteGroupe(int id) async {
    final db = await database;
    final result = await db.delete('groupes', where: 'id = ?', whereArgs: [id]);
    notifyDataChanged();
    return result;
  }


  Future<List<Module>> getAllModules({int? directorId}) async {
    final db = await database;
    if (directorId != null) {
      final result = await db.rawQuery('''
        SELECT m.* FROM modules m
        JOIN filieres f ON m.filiere_id = f.id
        WHERE f.director_id = ?
      ''', [directorId]);
      return result.map((map) => Module.fromMap(map)).toList();
    }
    final result = await db.query('modules');
    return result.map((map) => Module.fromMap(map)).toList();
  }

  Future<List<Module>> getModulesByFiliere(int filiereId) async {
    final db = await database;
    final result = await db.query(
      'modules',
      where: 'filiere_id = ?',
      whereArgs: [filiereId],
    );
    return result.map((map) => Module.fromMap(map)).toList();
  }

  Future<Module?> getModuleById(int id) async {
    final db = await database;
    final result = await db.query('modules', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Module.fromMap(result.first);
  }

  Future<int> insertModule(Module module) async {
    final db = await database;
    final existing = await db.query(
      'modules',
      where: 'nom = ? AND filiere_id = ? AND annee = ? AND semestre = ?',
      whereArgs: [module.nom, module.filiereId, module.annee, module.semestre],
    );
    if (existing.isNotEmpty) {
      throw Exception('Un module avec ce nom existe déjà dans cette filière.');
    }
    final result = await db.insert('modules', module.toMap());
    notifyDataChanged();
    return result;
  }

  Future<int> updateModule(Module module) async {
    final db = await database;
    final result = await db.update(
      'modules',
      module.toMap(),
      where: 'id = ?',
      whereArgs: [module.id],
    );
    notifyDataChanged();
    return result;
  }

  Future<int> deleteModule(int id) async {
    final db = await database;
    final result = await db.delete('modules', where: 'id = ?', whereArgs: [id]);
    notifyDataChanged();
    return result;
  }


  Future<List<Affectation>> getAllAffectations({int? directorId}) async {
    final db = await database;
    if (directorId != null) {
      final result = await db.rawQuery('''
        SELECT a.* FROM affectations a
        JOIN modules m ON a.module_id = m.id
        JOIN filieres f ON m.filiere_id = f.id
        WHERE f.director_id = ?
      ''', [directorId]);
      return result.map((map) => Affectation.fromMap(map)).toList();
    }
    final result = await db.query('affectations');
    return result.map((map) => Affectation.fromMap(map)).toList();
  }

  Future<List<Affectation>> getAffectationsByFormateur(int formateurId) async {
    final db = await database;
    final result = await db.query(
      'affectations',
      where: 'formateur_id = ?',
      whereArgs: [formateurId],
    );
    return result.map((map) => Affectation.fromMap(map)).toList();
  }

  Future<List<Affectation>> getAffectationsByGroupe(int groupeId) async {
    final db = await database;
    final result = await db.query(
      'affectations',
      where: 'groupe_id = ?',
      whereArgs: [groupeId],
    );
    return result.map((map) => Affectation.fromMap(map)).toList();
  }

  Future<int> insertAffectation(Affectation affectation) async {
    final db = await database;
    
    final existing = await db.query(
      'affectations',
      where: 'formateur_id = ? AND module_id = ? AND groupe_id = ? AND annee_scolaire = ?',
      whereArgs: [
        affectation.formateurId,
        affectation.moduleId,
        affectation.groupeId,
        affectation.anneeScolaire
      ],
    );
    if (existing.isNotEmpty) {
      throw Exception('Cette affectation existe déjà.');
    }

 
    final formateur = await getUserById(affectation.formateurId);
    final module = await getModuleById(affectation.moduleId);
    if (formateur != null && module != null) {
      if ((formateur.totalHeuresAffectees + module.masseHoraireTotale) > 910) {
        throw Exception('Le formateur ${formateur.nom} dépasserait la limit annuelle de 910h (${formateur.totalHeuresAffectees + module.masseHoraireTotale}h prévues).');
      }
    }

    final id = await db.insert('affectations', affectation.toMap()..remove('id'));
    
    if (module != null) {
      await db.rawUpdate(
        'UPDATE users SET total_heures_affectees = total_heures_affectees + ? WHERE id = ?',
        [module.masseHoraireTotale, affectation.formateurId]
      );
    }

    notifyDataChanged();
    return id;
  }

  Future<int> updateAffectation(Affectation affectation) async {
    final db = await database;
    return await db.update(
      'affectations',
      affectation.toMap(),
      where: 'id = ?',
      whereArgs: [affectation.id],
    );
  }

  Future<int> deleteAffectation(int id) async {
    final db = await database;
    
    final result = await db.query('affectations', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      final affectation = Affectation.fromMap(result.first);
      final module = await getModuleById(affectation.moduleId);
      if (module != null) {
        await db.rawUpdate(
          'UPDATE users SET total_heures_affectees = total_heures_affectees - ? WHERE id = ?',
          [module.masseHoraireTotale, affectation.formateurId]
        );
      }
    }

    final deleted = await db.delete('affectations', where: 'id = ?', whereArgs: [id]);
    notifyDataChanged();
    return deleted;
  }


  Future<double> getFormateurWeeklyHours(int formateurId, int semaineNum) async {
    final db = await database;
    final result = await db.query(
      'emplois',
      where: 'semaine_num = ?',
      whereArgs: [semaineNum],
    );

    double total = 0;
    for (var row in result) {
      final jsonStr = row['donnees_json'] as String?;
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> creneaux = jsonDecode(jsonStr);
        for (var c in creneaux) {
          if (c['formateur_id'] == formateurId || c['formateurId'] == formateurId) {
            final start = (c['heure_debut'] ?? c['heureDebut']).split(':');
            final end = (c['heure_fin'] ?? c['heureFin']).split(':');
            final dur = (int.parse(end[0]) * 60 + int.parse(end[1])) - (int.parse(start[0]) * 60 + int.parse(start[1]));
            total += dur / 60.0;
          }
        }
      }
    }
    return total;
  }

  Future<double> getGroupeWeeklyHours(int groupeId, int semaineNum) async {
    final db = await database;
    final result = await db.query(
      'emplois',
      where: 'semaine_num = ? AND groupe_id = ?',
      whereArgs: [semaineNum, groupeId],
    );

    double total = 0;
    for (var row in result) {
      final jsonStr = row['donnees_json'] as String?;
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> creneaux = jsonDecode(jsonStr);
        for (var c in creneaux) {
          final start = (c['heure_debut'] ?? c['heureDebut']).split(':');
          final end = (c['heure_fin'] ?? c['heureFin']).split(':');
          final dur = (int.parse(end[0]) * 60 + int.parse(end[1])) - (int.parse(start[0]) * 60 + int.parse(start[1]));
          total += dur / 60.0;
        }
      }
    }
    return total;
  }


  Future<List<Seance>> getSeancesByAffectation(int affectationId) async {
    final db = await database;
    final result = await db.query(
      'seances',
      where: 'affectation_id = ?',
      whereArgs: [affectationId],
      orderBy: 'date DESC',
    );
    return result.map((map) => Seance.fromMap(map)).toList();
  }

  Future<double> getValidatedHoursByAffectation(int affectationId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(duree) as total FROM seances WHERE affectation_id = ? AND statut = ?',
      [affectationId, 'VALIDE'],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Seance>> getSeancesEnAttente({int? directorId}) async {
    final db = await database;
    if (directorId != null) {
      final result = await db.rawQuery('''
        SELECT s.* FROM seances s
        JOIN affectations a ON s.affectation_id = a.id
        JOIN modules m ON a.module_id = m.id
        JOIN filieres f ON m.filiere_id = f.id
        WHERE s.statut = 'EN_ATTENTE' AND f.director_id = ?
      ''', [directorId]);
      return result.map((map) => Seance.fromMap(map)).toList();
    }
    final result = await db.query('seances', where: "statut = 'EN_ATTENTE'");
    return result.map((map) => Seance.fromMap(map)).toList();
  }

  Future<double> getTotalHeuresEffectuees(int affectationId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(duree) as total FROM seances WHERE affectation_id = ? AND statut = ?',
      [affectationId, 'VALIDE'],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> insertSeance(Seance seance) async {
    final db = await database;
    return await db.insert('seances', seance.toMap()..remove('id'));
  }

  Future<int> updateSeance(Seance seance) async {
    final db = await database;
    return await db.update(
      'seances',
      seance.toMap(),
      where: 'id = ?',
      whereArgs: [seance.id],
    );
  }

  Future<int> deleteSeance(int id) async {
    final db = await database;
    return await db.delete('seances', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> validerSeance(int id) async {
    final db = await database;
    return await db.update(
      'seances',
      {'statut': 'VALIDE'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> rejeterSeance(int id) async {
    final db = await database;
    return await db.update(
      'seances',
      {'statut': 'REJETEE'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }


  Future<List<Note>> getNotesByStagiaire(int stagiaireId) async {
    final db = await database;
    final result = await db.query(
      'notes',
      where: 'stagiaire_id = ?',
      whereArgs: [stagiaireId],
    );
    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<Note>> getNotesByModule(int moduleId) async {
    final db = await database;
    final result = await db.query(
      'notes',
      where: 'module_id = ?',
      whereArgs: [moduleId],
    );
    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<Note>> getNotesEnAttente({int? directorId}) async {
    final db = await database;
    if (directorId != null) {
      final result = await db.rawQuery('''
        SELECT n.* FROM notes n
        JOIN users u ON n.stagiaire_id = u.id
        WHERE n.statut = 'EN_ATTENTE' AND n.validee = 0 AND u.director_id = ?
      ''', [directorId]);
      return result.map((map) => Note.fromMap(map)).toList();
    }
    final result = await db.query(
      'notes',
      where: "statut = 'EN_ATTENTE' AND validee = 0",
    );
    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<int> insertNote(Note note) async {
    final db = await database;
    final id = await db.insert('notes', note.toMap());
    
    final module = await getModuleById(note.moduleId);
    await createNotification(NotificationModel(
      userId: note.stagiaireId,
      title: 'Nouvelle note',
      message: 'Une nouvelle note a été ajoutée pour le module ${module?.nom ?? "Inconnu"}: ${note.valeur}/20',
      type: 'INFO',
      timestamp: DateTime.now(),
    ));
    
    notifyDataChanged();
    return id;
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> validerNote(int id) async {
    final db = await database;
    return await db.update(
      'notes',
      {'validee': 1, 'statut': 'VALIDEE'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> rejeterNote(int id) async {
    final db = await database;
    return await db.update(
      'notes',
      {'statut': 'REJETEE', 'validee': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Note>> getNotesAPublier({int? directorId}) async {
    final db = await database;
    if (directorId != null) {
      final result = await db.rawQuery('''
        SELECT n.* FROM notes n
        JOIN users u ON n.stagiaire_id = u.id
        WHERE n.validee = 1 AND n.publiee = 0 AND u.director_id = ?
      ''', [directorId]);
      return result.map((map) => Note.fromMap(map)).toList();
    }
    final result = await db.query(
      'notes',
      where: 'validee = ? AND publiee = ?',
      whereArgs: [1, 0],
    );
    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<int> publierNote(int id) async {
    final db = await database;
    final result = await db.update(
      'notes',
      {'publiee': 1, 'statut': 'Publié'},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result > 0) {
      final note = await db.query('notes', where: 'id = ?', whereArgs: [id]);
      if (note.isNotEmpty) {
        final stagiaireId = note.first['stagiaire_id'] as int;
        final moduleId = note.first['module_id'] as int;
        
        final module = await db.query('modules', columns: ['nom'], where: 'id = ?', whereArgs: [moduleId]);
        final moduleName = module.isNotEmpty ? module.first['nom'] as String : 'un module';

        await createNotification(NotificationModel(
          userId: stagiaireId,
          title: 'Nouvelle note disponible',
          message: 'Une nouvelle note a été publiée pour le module $moduleName.',
          type: 'NOTE',
          timestamp: DateTime.now(),
        ));
        
        notifyDataChanged();
      }
    }
    return result;
  }


  Future<List<Emploi>> getEmploisByGroupe(int groupeId) async {
    final db = await database;
    final result = await db.query(
      'emplois',
      where: 'groupe_id = ?',
      whereArgs: [groupeId],
    );
    return result.map((map) => Emploi.fromMap(map)).toList();
  }

  Future<List<Emploi>> getEmploisByFormateur(int formateurId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT e.* 
      FROM emplois e
      JOIN affectations a ON e.groupe_id = a.groupe_id
      WHERE a.formateur_id = ?
    ''', [formateurId]);
    return result.map((map) => Emploi.fromMap(map)).toList();
  }

  Future<Emploi?> getEmploiBySemaineAndGroupe(int semaineNum, int groupeId) async {
    final db = await database;
    final result = await db.query(
      'emplois',
      where: 'semaine_num = ? AND groupe_id = ?',
      whereArgs: [semaineNum, groupeId],
    );
    if (result.isEmpty) return null;
    return Emploi.fromMap(result.first);
  }

  Future<int> insertEmploi(Emploi emploi) async {
    final db = await database;
    final id = await db.insert('emplois', emploi.toMap()..remove('id'));
    if (id > 0) {
      await _notifyStakeholdersOfEmploi(emploi.copyWith(id: id));
    }
    notifyDataChanged();
    return id;
  }

  Future<int> updateEmploi(Emploi emploi) async {
    final db = await database;
    final result = await db.update(
      'emplois',
      emploi.toMap(),
      where: 'id = ?',
      whereArgs: [emploi.id],
    );
    if (result > 0) {
      await _notifyStakeholdersOfEmploi(emploi);
    }
    notifyDataChanged();
    return result;
  }

  Future<void> _notifyStakeholdersOfEmploi(Emploi emploi) async {
    final groupe = await getGroupeById(emploi.groupeId);
    final groupName = groupe?.nom ?? 'votre groupe';

    final stagiaires = await getStagiairesByGroupe(emploi.groupeId);
    for (var s in stagiaires) {
      if (s.id != null) {
        await createNotification(NotificationModel(
          userId: s.id!,
          title: 'Emploi du temps mis à jour',
          message: 'L\'emploi du temps de la semaine ${emploi.semaineNum} pour $groupName est disponible.',
          type: 'INFO',
          timestamp: DateTime.now(),
        ));
      }
    }

    final formateurIds = emploi.creneaux.map((c) => c.formateurId).toSet();
    for (var fId in formateurIds) {
      if (fId != 0) {
        await createNotification(NotificationModel(
          userId: fId,
          title: 'Planning mis à jour',
          message: 'Votre planning pour la semaine ${emploi.semaineNum} a été mis à jour pour le groupe $groupName.',
          type: 'INFO',
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  Future<int> deleteEmploi(int id) async {
    final db = await database;
    return await db.delete('emplois', where: 'id = ?', whereArgs: [id]);
  }


  Future<Map<String, dynamic>> getGlobalStats({int? directorId}) async {
    final db = await database;
    
    String userWhere = 'role = ?';
    List<dynamic> userArgs = ['STAGIAIRE'];
    if (directorId != null) {
      userWhere += ' AND director_id = ?';
      userArgs.add(directorId);
    }
    final stagiairesCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM users WHERE $userWhere',
      userArgs,
    );
    
    userArgs[0] = 'FORMATEUR';
    final formateursCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM users WHERE $userWhere',
      userArgs,
    );
    
    String filiereWhere = '';
    List<dynamic> filiereArgs = [];
    if (directorId != null) {
      filiereWhere = 'WHERE director_id = ?';
      filiereArgs.add(directorId);
    }
    final filieresCount = await db.rawQuery('SELECT COUNT(*) as count FROM filieres $filiereWhere', filiereArgs);
    
    final groupesCount = await db.rawQuery(
      directorId != null 
        ? 'SELECT COUNT(*) as count FROM groupes g JOIN filieres f ON g.filiere_id = f.id WHERE f.director_id = ?'
        : 'SELECT COUNT(*) as count FROM groupes',
      directorId != null ? [directorId] : null
    );
    
    final modulesCount = await db.rawQuery(
      directorId != null 
        ? 'SELECT COUNT(*) as count FROM modules m JOIN filieres f ON m.filiere_id = f.id WHERE f.director_id = ?'
        : 'SELECT COUNT(*) as count FROM modules',
      directorId != null ? [directorId] : null
    );

    final seancesValidees = await db.rawQuery(
      directorId != null
        ? 'SELECT COUNT(*) as count FROM seances s JOIN affectations a ON s.affectation_id = a.id JOIN modules m ON a.module_id = m.id JOIN filieres f ON m.filiere_id = f.id WHERE s.statut = ? AND f.director_id = ?'
        : 'SELECT COUNT(*) as count FROM seances WHERE statut = ?',
      directorId != null ? ['VALIDE', directorId] : ['VALIDE'],
    );

    final seancesEnAttente = await db.rawQuery(
      directorId != null
        ? 'SELECT COUNT(*) as count FROM seances s JOIN affectations a ON s.affectation_id = a.id JOIN modules m ON a.module_id = m.id JOIN filieres f ON m.filiere_id = f.id WHERE s.statut = ? AND f.director_id = ?'
        : 'SELECT COUNT(*) as count FROM seances WHERE statut = ?',
      directorId != null ? ['EN_ATTENTE', directorId] : ['EN_ATTENTE'],
    );

    final absencesCount = await db.rawQuery(
      directorId != null
        ? 'SELECT COUNT(*) as count FROM presences p JOIN users u ON p.stagiaire_id = u.id WHERE p.statut = ? AND u.director_id = ?'
        : 'SELECT COUNT(*) as count FROM presences WHERE statut = ?',
      directorId != null ? ['ABSENT', directorId] : ['ABSENT'],
    );

    final presencesCount = await db.rawQuery(
      directorId != null
        ? 'SELECT COUNT(*) as count FROM presences p JOIN users u ON p.stagiaire_id = u.id WHERE p.statut = ? AND u.director_id = ?'
        : 'SELECT COUNT(*) as count FROM presences WHERE statut = ?',
      directorId != null ? ['PRESENT', directorId] : ['PRESENT'],
    );

    return {
      'stagiaires': stagiairesCount.first['count'],
      'formateurs': formateursCount.first['count'],
      'filieres': filieresCount.first['count'],
      'groupes': groupesCount.first['count'],
      'modules': modulesCount.first['count'],
      'seancesValidees': seancesValidees.first['count'],
      'seancesEnAttente': seancesEnAttente.first['count'],
      'absences': absencesCount.first['count'],
      'presences': presencesCount.first['count'],
    };
  }

  Future<List<Map<String, dynamic>>> getRecentActivity({int? directorId}) async {
    final db = await database;
    
    String seanceWhere = "s.statut = 'VALIDE'";
    String noteWhere = "n.statut = 'PUBLIE'";
    
    if (directorId != null) {
      seanceWhere += " AND f.director_id = ?";
      noteWhere += " AND f.director_id = ?";
    }

    final query = '''
      SELECT 'SEANCE' as type, s.date as timestamp, m.nom as text, g.nom as subtext
      FROM seances s
      JOIN affectations a ON s.affectation_id = a.id
      JOIN modules m ON a.module_id = m.id
      JOIN groupes g ON a.groupe_id = g.id
      ${directorId != null ? 'JOIN filieres f ON m.filiere_id = f.id' : ''}
      WHERE $seanceWhere
      UNION ALL
      SELECT 'NOTE' as type, n.date_examen as timestamp, m.nom as text, 'Note publiée' as subtext
      FROM notes n
      JOIN modules m ON n.module_id = m.id
      ${directorId != null ? 'JOIN filieres f ON m.filiere_id = f.id' : ''}
      WHERE $noteWhere
      ORDER BY timestamp DESC
      LIMIT 10
    ''';
    
    return await db.rawQuery(query, directorId != null ? [directorId, directorId] : []);
  }

  Future<List<Map<String, dynamic>>> getPresenceStatsForDP({int? directorId}) async {
    final db = await database;
    String where = "u.role = 'STAGIAIRE'";
    List<dynamic> args = [];
    if (directorId != null) {
      where += " AND u.director_id = ?";
      args.add(directorId);
    }
    final result = await db.rawQuery('''
      SELECT u.id, u.nom, u.matricule, g.nom as groupe_nom,
             COUNT(CASE WHEN p.statut = 'PRESENT' THEN 1 END) as presences,
             COUNT(CASE WHEN p.statut = 'ABSENT' THEN 1 END) as absences,
             COUNT(CASE WHEN p.statut = 'RETARD' THEN 1 END) as retards
      FROM users u
      LEFT JOIN groupes g ON u.groupe_id = g.id
      LEFT JOIN presences p ON u.id = p.stagiaire_id
      WHERE $where
      GROUP BY u.id
    ''', args);
    return result;
  }

  Future<double> getFormateurTotalHours(int formateurId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(s.duree) as total 
      FROM seances s
      JOIN affectations a ON s.affectation_id = a.id
      WHERE a.formateur_id = ? AND s.statut = ?
    ''', [formateurId, 'VALIDE']);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, dynamic>> getDashboardStats({int? filiereId, int? directorId}) async {
    final db = await database;

    String stagWhere = 'WHERE u.role = ?';
    List<dynamic> stagArgs = ['STAGIAIRE'];
    if (filiereId != null) {
      stagWhere += ' AND u.groupe_id IN (SELECT id FROM groupes WHERE filiere_id = ?)';
      stagArgs.add(filiereId);
    }
    if (directorId != null) {
      stagWhere += ' AND u.director_id = ?';
      stagArgs.add(directorId);
    }
    final stagiairesCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM users u $stagWhere', stagArgs)
    ) ?? 0;
    
    String formWhere = 'WHERE u.role = ?';
    List<dynamic> formArgs = ['FORMATEUR'];
    if (filiereId != null) {
      formWhere += ' AND EXISTS (SELECT 1 FROM affectations a JOIN modules m ON a.module_id = m.id WHERE a.formateur_id = u.id AND m.filiere_id = ?)';
      formArgs.add(filiereId);
    }
    if (directorId != null) {
      formWhere += ' AND u.director_id = ?';
      formArgs.add(directorId);
    }
    final formateursCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(DISTINCT u.id) FROM users u $formWhere', formArgs)
    ) ?? 0;
    
    String hoursQuery = "SELECT SUM(s.duree) as total FROM seances s JOIN affectations a ON s.affectation_id = a.id JOIN modules m ON a.module_id = m.id";
    String hoursWhere = "WHERE s.statut = 'VALIDE'";
    List<dynamic> hoursArgs = [];
    if (filiereId != null) {
      hoursWhere += " AND m.filiere_id = ?";
      hoursArgs.add(filiereId);
    }
    if (directorId != null) {
      hoursQuery += " JOIN filieres f ON m.filiere_id = f.id";
      hoursWhere += " AND f.director_id = ?";
      hoursArgs.add(directorId);
    }
    final heuresValidees = await db.rawQuery('$hoursQuery $hoursWhere', hoursArgs);
    final double totalHeures = (heuresValidees.first['total'] as num?)?.toDouble() ?? 0.0;

    String repQuery = '''SELECT f.nom,
                 (SELECT COUNT(*) FROM users u JOIN groupes g ON u.groupe_id = g.id WHERE g.filiere_id = f.id AND u.role = 'STAGIAIRE') as stagiaires,
                 (SELECT COUNT(*) FROM groupes g WHERE g.filiere_id = f.id) as groupes,
                 (SELECT COUNT(*) FROM modules m WHERE m.filiere_id = f.id) as modules
               FROM filieres f''';
    String repWhere = "";
    List<dynamic> repArgs = [];
    if (filiereId != null) {
      repWhere = "WHERE f.id = ?";
      repArgs.add(filiereId);
    } else if (directorId != null) {
      repWhere = "WHERE f.director_id = ?";
      repArgs.add(directorId);
    }
    final repartitionFiliere = await db.rawQuery('$repQuery $repWhere', repArgs);

    String noteQuery;
    List<dynamic> noteArgs = [];

    if (filiereId != null) {
      noteQuery = '''SELECT 
                CASE 
                  WHEN n.valeur < 5 THEN '0-5'
                  WHEN n.valeur < 8 THEN '5-8'
                  WHEN n.valeur < 10 THEN '8-10'
                  WHEN n.valeur < 12 THEN '10-12'
                  WHEN n.valeur < 15 THEN '12-15'
                  ELSE '15-20'
                END as range,
                COUNT(*) as count
               FROM notes n
               JOIN users u ON n.stagiaire_id = u.id
               JOIN groupes g ON u.groupe_id = g.id
               WHERE g.filiere_id = ?
               GROUP BY range''';
      noteArgs.add(filiereId);
    } else if (directorId != null) {
      noteQuery = '''SELECT 
                  CASE 
                    WHEN n.valeur < 5 THEN '0-5'
                    WHEN n.valeur < 8 THEN '5-8'
                    WHEN n.valeur < 10 THEN '8-10'
                    WHEN n.valeur < 12 THEN '10-12'
                    WHEN n.valeur < 15 THEN '12-15'
                    ELSE '15-20'
                  END as range,
                  COUNT(*) as count
                 FROM notes n
                 JOIN users u ON n.stagiaire_id = u.id
                 WHERE u.director_id = ?
                 GROUP BY range''';
      noteArgs.add(directorId);
    } else {
      noteQuery = '''SELECT 
                  CASE 
                    WHEN valeur < 5 THEN '0-5'
                    WHEN valeur < 8 THEN '5-8'
                    WHEN valeur < 10 THEN '8-10'
                    WHEN valeur < 12 THEN '10-12'
                    WHEN valeur < 15 THEN '12-15'
                    ELSE '15-20'
                  END as range,
                  COUNT(*) as count
                 FROM notes
                 GROUP BY range''';
    }

    final distributionNotes = await db.rawQuery(noteQuery, noteArgs.isNotEmpty ? noteArgs : null);

    String chargeQuery = '''SELECT u.nom, IFNULL(SUM(s.duree), 0) as done, IFNULL(u.total_heures_affectees, 0) as total
               FROM users u
               LEFT JOIN affectations a ON u.id = a.formateur_id
               LEFT JOIN modules m ON a.module_id = m.id
               LEFT JOIN seances s ON a.id = s.affectation_id AND s.statut = 'VALIDE'
               ''';
    String chargeWhere = "WHERE u.role = 'FORMATEUR'";
    List<dynamic> chargeArgs = [];
    if (filiereId != null) {
      chargeWhere += " AND m.filiere_id = ?";
      chargeArgs.add(filiereId);
    }
    if (directorId != null) {
      chargeWhere += " AND u.director_id = ?";
      chargeArgs.add(directorId);
    }
    final chargeFormateurs = await db.rawQuery('''
      $chargeQuery
      $chargeWhere
      GROUP BY u.id
      ORDER BY done DESC
      LIMIT 5
    ''', chargeArgs);

    String avancQuery = '''SELECT m.nom, IFNULL(SUM(s.duree), 0) as done, m.masse_horaire_totale as total
               FROM modules m
               LEFT JOIN affectations a ON m.id = a.module_id
               LEFT JOIN seances s ON a.id = s.affectation_id AND s.statut = 'VALIDE'
               ''';
    String avancWhere = "";
    List<dynamic> avancArgs = [];
    if (filiereId != null) {
      avancWhere = "WHERE m.filiere_id = ?";
      avancArgs.add(filiereId);
    } else if (directorId != null) {
      avancQuery += " JOIN filieres f ON m.filiere_id = f.id";
      avancWhere = "WHERE f.director_id = ?";
      avancArgs.add(directorId);
    }
    final avancementModules = await db.rawQuery('''
      $avancQuery
      $avancWhere
      GROUP BY m.id
      ORDER BY (IFNULL(SUM(s.duree), 0) / m.masse_horaire_totale) DESC
      LIMIT 6
    ''', avancArgs);

    return {
      'stagiairesActifs': stagiairesCount,
      'formateursActifs': formateursCount,
      'heuresValidees': totalHeures,
      'tauxReussite': 0.0,
      'repartitionFiliere': repartitionFiliere,
      'distributionNotes': distributionNotes,
      'chargeFormateurs': chargeFormateurs,
      'avancementModules': avancementModules,
    };
  }



  Future<List<Map<String, dynamic>>> getAllAffectationsWithProgress({int? filiereId, int? directorId}) async {
    final db = await database;
    String joinClause = '';
    String whereClause = '';
    List<dynamic> args = [];
    
    if (filiereId != null) {
      whereClause = 'WHERE m.filiere_id = ?';
      args.add(filiereId);
    }
    
    if (directorId != null) {
      joinClause = 'JOIN filieres f ON m.filiere_id = f.id';
      if (whereClause.isEmpty) {
        whereClause = 'WHERE f.director_id = ?';
      } else {
        whereClause += ' AND f.director_id = ?';
      }
      args.add(directorId);
    }

    final result = await db.rawQuery('''
      SELECT 
        g.nom as groupe_name,
        m.nom as module_name,
        u.nom as formateur_name,
        m.masse_horaire_totale,
        IFNULL(SUM(s.duree), 0) as hours_done
      FROM affectations a
      JOIN groupes g ON a.groupe_id = g.id
      JOIN modules m ON a.module_id = m.id
      JOIN users u ON a.formateur_id = u.id
      $joinClause
      LEFT JOIN seances s ON a.id = s.affectation_id AND s.statut = 'VALIDE'
      $whereClause
      GROUP BY a.id, g.nom, m.nom, u.nom, m.masse_horaire_totale
    ''', args);
    
    return result;
  }
  Future<void> close() async {
    final db = await database;
    db.close();
  }

  Future<int> sendMessage(Message message) async {
    final db = await database;
    final id = await db.insert('messages', message.toMap());
    
    if (message.receiverId != null) {
      final sender = await getUserById(message.senderId);
      await createNotification(NotificationModel(
        userId: message.receiverId!,
        title: 'Nouveau message',
        message: 'Vous avez reçu un message de ${sender?.nom ?? "quelqu\'un"}',
        type: 'MESSAGE',
        timestamp: DateTime.now(),
      ));
    }
    
    notifyDataChanged();
    return id;
  }

  Future<List<Message>> getMessages(int userId, {int? otherUserId, int? groupId}) async {
    final db = await database;
    if (groupId != null) {
      final result = await db.query(
        'messages',
        where: 'group_id = ?',
        whereArgs: [groupId],
        orderBy: 'timestamp ASC',
      );
      return result.map((map) => Message.fromMap(map)).toList();
    } else if (otherUserId != null) {
      final result = await db.query(
        'messages',
        where: '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
        whereArgs: [userId, otherUserId, otherUserId, userId],
        orderBy: 'timestamp ASC',
      );
      return result.map((map) => Message.fromMap(map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getConversations(int userId) async {
    final db = await database;
    
    final userResult = await db.rawQuery('''
      SELECT DISTINCT 
        u.id, u.nom, u.email, u.role, u.phone, 0 as is_group,
        (SELECT content FROM messages 
         WHERE (sender_id = u.id AND receiver_id = ?) OR (sender_id = ? AND receiver_id = u.id)
         ORDER BY timestamp DESC LIMIT 1) as last_message,
        (SELECT timestamp FROM messages 
         WHERE (sender_id = u.id AND receiver_id = ?) OR (sender_id = ? AND receiver_id = u.id)
         ORDER BY timestamp DESC LIMIT 1) as last_time,
        (SELECT COUNT(*) FROM messages 
         WHERE sender_id = u.id AND receiver_id = ? AND is_read = 0) as unread_count
      FROM users u
      JOIN messages m ON (m.sender_id = u.id OR m.receiver_id = u.id)
      WHERE u.id != ? AND m.group_id IS NULL AND ((m.sender_id = ? AND m.receiver_id = u.id) OR (m.sender_id = u.id AND m.receiver_id = ?))
      GROUP BY u.id
    ''', [userId, userId, userId, userId, userId, userId, userId, userId]);

    String groupQuery = '''
      SELECT 
        g.id, g.nom, '' as email, 'GROUPE' as role, '' as phone, 1 as is_group,
        (SELECT content FROM messages WHERE group_id = g.id ORDER BY timestamp DESC LIMIT 1) as last_message,
        (SELECT timestamp FROM messages WHERE group_id = g.id ORDER BY timestamp DESC LIMIT 1) as last_time,
        (SELECT COUNT(*) FROM messages 
         WHERE group_id = g.id AND sender_id != ? 
         AND id NOT IN (SELECT message_id FROM message_reads WHERE user_id = ?)) as unread_count
      FROM groupes g
    ''';
    
    
    final currentUser = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    List<dynamic> groupArgs = [userId, userId];
    
    if (currentUser.isNotEmpty && currentUser.first['role'] == 'DP') {
      groupQuery = '''
        SELECT 
          g.id, g.nom, '' as email, 'GROUPE' as role, '' as phone, 1 as is_group,
          (SELECT content FROM messages WHERE group_id = g.id ORDER BY timestamp DESC LIMIT 1) as last_message,
          (SELECT timestamp FROM messages WHERE group_id = g.id ORDER BY timestamp DESC LIMIT 1) as last_time,
          (SELECT COUNT(*) FROM messages 
           WHERE group_id = g.id AND sender_id != ? 
           AND id NOT IN (SELECT message_id FROM message_reads WHERE user_id = ?)) as unread_count
        FROM groupes g
        JOIN filieres f ON g.filiere_id = f.id
        WHERE f.director_id = ?
      ''';
      groupArgs.add(userId);
    }

    final groupResult = await db.rawQuery(groupQuery, groupArgs);
    
    List<Map<String, dynamic>> combined = List.from(userResult);
    combined.addAll(groupResult);

    if (userId != 1) {
       final user = await db.query('users', columns: ['role', 'groupe_id'], where: 'id = ?', whereArgs: [userId]);
       if (user.isNotEmpty && user.first['role'] == 'FORMATEUR') {
         final assignedGroups = await getGroupsForFormateur(userId);
         final assignedGroupIds = assignedGroups.map((g) => g.id!).toSet();
         combined.removeWhere((item) => item['is_group'] == 1 && !assignedGroupIds.contains(item['id']));
       } else if (user.isNotEmpty && user.first['role'] == 'STAGIAIRE') {
         final userGroupId = user.first['groupe_id'] as int?;
         if (userGroupId != null) {
           combined.removeWhere((item) => item['is_group'] == 1 && item['id'] != userGroupId);
         } else {
           combined.removeWhere((item) => item['is_group'] == 1);
         }
       }
    }

    combined.sort((a, b) {
      final timeA = a['last_time'] as String? ?? '';
      final timeB = b['last_time'] as String? ?? '';
      return timeB.compareTo(timeA);
    });
    
    return combined;
  }

  Future<void> markMessagesAsRead(int senderId, int receiverId) async {
    final db = await database;
    await db.update(
      'messages',
      {'is_read': 1},
      where: 'sender_id = ? AND receiver_id = ?',
      whereArgs: [senderId, receiverId],
    );
  }

  Future<void> markGroupMessagesAsRead(int groupId, int userId) async {
    final db = await database;
    
    final unreadMessages = await db.rawQuery('''
      SELECT id FROM messages 
      WHERE group_id = ? AND sender_id != ? 
      AND id NOT IN (SELECT message_id FROM message_reads WHERE user_id = ?)
    ''', [groupId, userId, userId]);

    if (unreadMessages.isNotEmpty) {
      final batch = db.batch();
      for (var msg in unreadMessages) {
        batch.insert('message_reads', {
          'message_id': msg['id'],
          'user_id': userId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    }
  }

  Future<int> getTotalUnreadMessageCount(int userId) async {
    final db = await database;
    
    final privateResult = await db.rawQuery(
      'SELECT COUNT(*) FROM messages WHERE receiver_id = ? AND is_read = 0 AND group_id IS NULL',
      [userId]
    );
    int privateCount = Sqflite.firstIntValue(privateResult) ?? 0;
    
    final groupResult = await db.rawQuery('''
      SELECT COUNT(*) FROM messages 
      WHERE group_id IS NOT NULL 
      AND sender_id != ? 
      AND id NOT IN (SELECT message_id FROM message_reads WHERE user_id = ?)
    ''', [userId, userId]);
    int groupCount = Sqflite.firstIntValue(groupResult) ?? 0;
    
    return privateCount + groupCount;
  }

  Future<void> markMessageNotificationsAsRead(int userId, {int? otherUserId, int? groupId}) async {
    final db = await database;
    
    if (groupId != null) {
      await db.update(
        'notifications',
        {'is_read': 1},
        where: 'user_id = ? AND type = ? AND is_read = 0',
        whereArgs: [userId, 'MESSAGE'],
      );
    } else if (otherUserId != null) {
      final otherUser = await getUserById(otherUserId);
      if (otherUser != null) {
        await db.update(
          'notifications',
          {'is_read': 1},
          where: 'user_id = ? AND type = ? AND message LIKE ? AND is_read = 0',
          whereArgs: [userId, 'MESSAGE', '%${otherUser.nom}%'],
        );
      }
    }
    
    notifyDataChanged();
  }

  Future<int> getUnreadNotificationsCount(int userId) async {
    final db = await database;
    final result = await db.query(
      'notifications',
      columns: ['COUNT(*)'],
      where: 'user_id = ? AND is_read = 0',
      whereArgs: [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getUnreadNotificationsCountByType(int userId, String type) async {
    final db = await database;
    final result = await db.query(
      'notifications',
      columns: ['COUNT(*)'],
      where: 'user_id = ? AND type = ? AND is_read = 0',
      whereArgs: [userId, type],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markNotificationsAsReadByType(int userId, String type) async {
    final db = await database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'user_id = ? AND type = ? AND is_read = 0',
      whereArgs: [userId, type],
    );
    notifyDataChanged();
  }

  Future<int> getUnreadReclamationsCount({int? directorId}) async {
    final db = await database;
    if (directorId != null) {
      final result = await db.rawQuery('''
        SELECT COUNT(*)
        FROM reclamations r
        JOIN users u ON r.user_id = u.id
        WHERE r.status = 'EN_ATTENTE' AND u.director_id = ?
      ''', [directorId]);
      return Sqflite.firstIntValue(result) ?? 0;
    }
    final result = await db.query(
      'reclamations',
      columns: ['COUNT(*)'],
      where: "status = 'EN_ATTENTE'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getPendingPresenceValidationsCount({int? directorId}) async {
    final db = await database;
    if (directorId != null) {
      final result = await db.rawQuery('''
        SELECT COUNT(DISTINCT p.formateur_id) as count 
        FROM presences p
        JOIN users u ON p.stagiaire_id = u.id
        WHERE p.vu_par_dp = 0 AND p.formateur_id IS NOT NULL AND u.director_id = ?
      ''', [directorId]);
      return Sqflite.firstIntValue(result) ?? 0;
    }
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT formateur_id) as count 
      FROM presences 
      WHERE vu_par_dp = 0 AND formateur_id IS NOT NULL
    ''');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markPresencesAsSeen({int? directorId}) async {
    final db = await database;
    if (directorId != null) {
      await db.execute('''
        UPDATE presences SET vu_par_dp = 1 
        WHERE vu_par_dp = 0 AND stagiaire_id IN (SELECT id FROM users WHERE director_id = ?)
      ''', [directorId]);
    } else {
      await db.update(
        'presences',
        {'vu_par_dp': 1},
        where: 'vu_par_dp = 0',
      );
    }
  }

  Future<int> getUnvalidatedNotesCount({int? directorId}) async {
    final db = await database;
    if (directorId != null) {
      final result = await db.rawQuery('''
        SELECT COUNT(*)
        FROM notes n
        JOIN users u ON n.stagiaire_id = u.id
        WHERE n.validee = 0 AND u.director_id = ?
      ''', [directorId]);
      return Sqflite.firstIntValue(result) ?? 0;
    }
    final result = await db.query(
      'notes',
      columns: ['COUNT(*)'],
      where: 'validee = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getPendingUserRequestsCount(int directorId) async {
    final db = await database;
    final result = await db.query(
      'user_requests',
      columns: ['COUNT(*)'],
      where: "status = 'EN_ATTENTE' AND director_id = ?",
      whereArgs: [directorId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    final db = await database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }


  Future<int> insertExam(Map<String, dynamic> exam) async {
    final db = await database;
    return await db.insert('exams', exam);
  }

  Future<List<Map<String, dynamic>>> getUpcomingExams(int formateurId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT e.*, a.groupe_id, a.module_id, m.nom as module_name, g.nom as groupe_name
      FROM exams e
      JOIN affectations a ON e.affectation_id = a.id
      JOIN modules m ON a.module_id = m.id
      JOIN groupes g ON a.groupe_id = g.id
      WHERE a.formateur_id = ? AND e.date >= ?
      ORDER BY e.date ASC
    ''', [formateurId, DateTime.now().toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getGlobalUpcomingExams({int? directorId}) async {
    final db = await database;
    String where = "e.date >= ?";
    List<dynamic> args = [DateTime.now().toIso8601String()];
    
    String join = "";
    if (directorId != null) {
      join = "JOIN filieres f ON m.filiere_id = f.id";
      where += " AND f.director_id = ?";
      args.add(directorId);
    }

    return await db.rawQuery('''
      SELECT e.*, a.groupe_id, a.module_id, m.nom as module_name, g.nom as groupe_name
      FROM exams e
      JOIN affectations a ON e.affectation_id = a.id
      JOIN modules m ON a.module_id = m.id
      JOIN groupes g ON a.groupe_id = g.id
      $join
      WHERE $where
      ORDER BY e.date ASC
      LIMIT 10
    ''', args);
  }

  Future<double> getAffectationCompletedHours(int affectationId) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT SUM(duree) as total FROM seances WHERE affectation_id = ? AND statut = 'VALIDE'",
      [affectationId]
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }


  Future<int> deleteExam(int id) async {
    final db = await database;
    return await db.delete('exams', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateExam(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('exams', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAffectationsWithProgress(int formateurId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT a.*, m.nom as module_name, m.masse_horaire_totale, g.nom as groupe_name,
      (SELECT IFNULL(SUM(s.duree), 0) FROM seances s WHERE s.affectation_id = a.id AND s.statut = 'VALIDE') as hours_done
      FROM affectations a
      JOIN modules m ON a.module_id = m.id
      JOIN groupes g ON a.groupe_id = g.id
      WHERE a.formateur_id = ?
    ''', [formateurId]);
  }



  Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }




  Future<int> createUserRequest(UserRequest request) async {
    final db = await database;
    final id = await db.insert('user_requests', request.toMap());
    
    await createNotification(NotificationModel(
      userId: request.directorId,
      title: 'Nouvelle demande d\'inscription',
      message: 'Une nouvelle demande d\'inscription a été reçue de ${request.nom}',
      type: 'ACCOUNT',
      timestamp: DateTime.now(),
    ));
    
    notifyDataChanged();
    return id;
  }

  Future<List<UserRequest>> getUserRequests(int directorId) async {
    final db = await database;
    final result = await db.query(
      'user_requests',
      where: 'director_id = ? AND status = ?',
      whereArgs: [directorId, 'EN_ATTENTE'],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => UserRequest.fromMap(map)).toList();
  }

  Future<void> updateUserRequestStatus(int id, String status) async {
    final db = await database;
    await db.update(
      'user_requests',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getUpcomingExamsForGroup(int groupId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT e.*, m.nom as module_name
      FROM exams e
      JOIN affectations a ON e.affectation_id = a.id
      JOIN modules m ON a.module_id = m.id
      WHERE a.groupe_id = ? AND e.date >= ? AND e.status = 'PUBLIE'
      ORDER BY e.date ASC
    ''', [groupId, DateTime.now().toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getPastExamsForGroup(int groupId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT e.*, m.nom as module_name
      FROM exams e
      JOIN affectations a ON e.affectation_id = a.id
      JOIN modules m ON a.module_id = m.id
      WHERE a.groupe_id = ? AND e.date < ? AND e.status = 'PUBLIE'
      ORDER BY e.date DESC
    ''', [groupId, DateTime.now().toIso8601String()]);
  }



  Future<List<Groupe>> getGroupsForFormateur(int formateurId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT g.*
      FROM groupes g
      JOIN affectations a ON g.id = a.groupe_id
      WHERE a.formateur_id = ?
    ''', [formateurId]);
    return result.map((map) => Groupe.fromMap(map)).toList();
  }

  Future<List<Groupe>> getGroupesByDirectorId(int directorId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT g.* FROM groupes g
      JOIN filieres f ON g.filiere_id = f.id
      WHERE f.director_id = ?
    ''', [directorId]);
    return result.map((map) => Groupe.fromMap(map)).toList();
  }

  Future<Groupe?> getGroupeByName(String name) async {
    final db = await database;
    final result = await db.query(
      'groupes',
      where: 'nom = ?',
      whereArgs: [name],
    );
    if (result.isEmpty) return null;
    return Groupe.fromMap(result.first);
  }



  Future<List<User>> searchUsers(String query, {int? directorId}) async {
    final db = await database;
    String where = '(nom LIKE ? OR email LIKE ?)';
    List<dynamic> args = ['%$query%', '%$query%'];
    
    if (directorId != null) {
      where += ' AND director_id = ?';
      args.add(directorId);
    }

    final result = await db.query(
      'users',
      where: where,
      whereArgs: args,
      limit: 20,
    );
    return result.map((map) => User.fromMap(map)).toList();
  }

  Future<int> createReclamation(Reclamation rec) async {
    final db = await database;
    final id = await db.insert('reclamations', rec.toMap());
    
    final dps = await getUsersByRole(UserRole.dp);
    for (var dp in dps) {
      await createNotification(NotificationModel(
        userId: dp.id!,
        title: 'Nouvelle réclamation',
        message: 'Une nouvelle réclamation a été soumise par ${rec.userId}',
        type: 'RECLAMATION',
        timestamp: DateTime.now(),
      ));
    }
    
    notifyDataChanged();
    return id;
  }

  Future<Reclamation?> getReclamationById(int id) async {
    final db = await database;
    final result = await db.query('reclamations', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Reclamation.fromMap(result.first);
  }

  Future<List<Reclamation>> getReclamationsByUser(int userId) async {
    final db = await database;
    final result = await db.query(
      'reclamations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => Reclamation.fromMap(map)).toList();
  }

  Future<List<Reclamation>> getAllReclamations({int? directorId}) async {
    final db = await database;
    if (directorId != null) {
      final result = await db.rawQuery('''
        SELECT r.* FROM reclamations r
        JOIN users u ON r.user_id = u.id
        WHERE u.director_id = ?
        ORDER BY r.timestamp DESC
      ''', [directorId]);
      return result.map((map) => Reclamation.fromMap(map)).toList();
    }
    final result = await db.query(
      'reclamations',
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => Reclamation.fromMap(map)).toList();
  }

  Future<void> updateReclamationStatus(int id, String status, {String? response}) async {
    final db = await database;
    final Map<String, dynamic> updates = {'status': status};
    if (response != null) {
      updates['response'] = response;
    }
    await db.update(
      'reclamations',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (status == 'RESOLUE') {
      final rec = await getReclamationById(id);
      if (rec != null) {
        await createNotification(NotificationModel(
          userId: rec.userId,
          title: 'Réclamation résolue',
          message: 'Votre réclamation concernant "${rec.subject}" a été traitée.',
          type: 'RECLAMATION',
          timestamp: DateTime.now(),
        ));
      }
    }
    notifyDataChanged();
  }

  Future<List<NotificationModel>> getNotifications(int userId) async {
    final db = await database;
    final result = await db.query(
      'notifications',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => NotificationModel.fromMap(map)).toList();
  }




  Future<List<Map<String, dynamic>>> getPresenceByDateGroup(String date, int groupeId, {String? heure}) async {
    final db = await database;
    if (heure != null) {
      return await db.query(
        'presences',
        where: 'date = ? AND groupe_id = ? AND heure = ?',
        whereArgs: [date, groupeId, heure],
      );
    }
    return await db.query(
      'presences',
      where: 'date = ? AND groupe_id = ?',
      whereArgs: [date, groupeId],
    );
  }

  Future<void> savePresence(int stagiaireId, int groupeId, String date, String statut, int formateurId, {String? heure}) async {
    final db = await database;
    final existing = await db.query(
      'presences',
      where: 'stagiaire_id = ? AND date = ? AND (heure = ? OR heure IS NULL)',
      whereArgs: [stagiaireId, date, heure],
    );

    if (existing.isNotEmpty) {
      if ((existing.first['valide_par_dp'] as int? ?? 0) == 0) {
        await db.update(
          'presences',
          {
            'statut': statut, 
            'timestamp': DateTime.now().toIso8601String(),
            'formateur_id': formateurId,
            'vu_par_dp': 0
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
    } else {
      await db.insert('presences', {
        'stagiaire_id': stagiaireId,
        'groupe_id': groupeId,
        'date': date,
        'heure': heure,
        'statut': statut,
        'valide_par_dp': 0,
        'vu_par_dp': 0,
        'formateur_id': formateurId,
        'timestamp': DateTime.now().toIso8601String(),
      });
      notifyDataChanged();
    }
  }

  Future<void> validerPresenceDP(int groupeId, String date, {String? heure}) async {
    final db = await database;
    if (heure != null) {
      await db.update(
        'presences',
        {'valide_par_dp': 1},
        where: 'groupe_id = ? AND date = ? AND heure = ?',
        whereArgs: [groupeId, date, heure],
      );
    } else {
      await db.update(
        'presences',
        {'valide_par_dp': 1},
        where: 'groupe_id = ? AND date = ?',
        whereArgs: [groupeId, date],
      );
    }

    try {
      final presences = await db.query(
        'presences', 
        where: 'groupe_id = ? AND date = ?${heure != null ? " AND heure = ?" : ""}', 
        whereArgs: [groupeId, date, if (heure != null) heure], 
        limit: 1
      );
      if (presences.isNotEmpty) {
        final formateurId = presences.first['formateur_id'] as int?;
        if (formateurId != null) {
          final groupe = await getGroupeById(groupeId);
          await createNotification(NotificationModel(
            userId: formateurId,
            title: 'Présence validée',
            message: 'La présence du ${date}${heure != null ? " ($heure)" : ""} pour le groupe ${groupe?.nom ?? ""} a été validée par le DP.',
            type: 'INFO',
            timestamp: DateTime.now(),
          ));
        }
      }
    } catch (e) {
      debugPrint('Error sending validation notification: $e');
    }

    notifyDataChanged();
  }

  Future<List<Map<String, dynamic>>> getPresencesEnAttente({int? directorId}) async {
    final db = await database;
    String where = "p.valide_par_dp = 0";
    List<dynamic> args = [];
    if (directorId != null) {
      where += " AND u.director_id = ?";
      args.add(directorId);
    }
    
    return await db.rawQuery('''
      SELECT p.date, p.groupe_id, p.heure, g.nom as groupe_nom, COUNT(DISTINCT p.stagiaire_id) as student_count
      FROM presences p
      JOIN groupes g ON p.groupe_id = g.id
      JOIN users u ON p.stagiaire_id = u.id
      WHERE $where
      GROUP BY p.date, p.groupe_id, g.nom, p.heure
      ORDER BY p.date DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getPresenceDetails(String date, int groupeId, {String? heure}) async {
    final db = await database;
    String where = "p.date = ? AND p.groupe_id = ?";
    List<dynamic> args = [date, groupeId];
    if (heure != null) {
      where += " AND p.heure = ?";
      args.add(heure);
    }

    final result = await db.rawQuery('''
      SELECT u.nom as stagiaire_nom, p.statut, p.timestamp, p.heure
      FROM presences p
      JOIN users u ON p.stagiaire_id = u.id
      WHERE $where
    ''', args);
    return result;
  }





  Future<void> markAllNotificationsAsRead(int userId) async {
    final db = await database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
  
  
  Future<List<Map<String, dynamic>>> getModuleProgressForStagiaire(int stagiaireId) async {
    final db = await database;
    
    final user = await getUserById(stagiaireId);
    if (user == null || user.groupeId == null) {
      return [];
    }
    
    final groupeResult = await db.query('groupes', where: 'id = ?', whereArgs: [user.groupeId]);
    if (groupeResult.isEmpty) return [];
    
    final filiereId = groupeResult.first['filiere_id'] as int;
    
    final result = await db.rawQuery('''
      SELECT 
        m.id as module_id,
        m.nom as module_name,
        m.masse_horaire_totale,
        COALESCE(
          (SELECT SUM(s.duree) 
           FROM seances s
           JOIN affectations a ON s.affectation_id = a.id
           WHERE a.module_id = m.id 
             AND a.groupe_id = ?
             AND s.statut = 'VALIDE'), 
          0
        ) as heures_effectuees
      FROM modules m
      WHERE m.filiere_id = ?
      ORDER BY m.nom
    ''', [user.groupeId, filiereId]);
    
    return result.map((row) {
      final totalHours = (row['masse_horaire_totale'] as num).toDouble();
      final completedHours = (row['heures_effectuees'] as num).toDouble();
      final percentage = totalHours > 0 ? (completedHours / totalHours * 100).clamp(0, 100) : 0.0;
      
      return {
        'module_id': row['module_id'],
        'module_name': row['module_name'],
        'masse_horaire_totale': totalHours,
        'heures_effectuees': completedHours,
        'pourcentage': percentage,
      };
    }).toList();
  }

  Future<double> getStagiaireAverage(int stagiaireId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT AVG(valeur) as average FROM notes 
      WHERE stagiaire_id = ? AND validee = 1
    ''', [stagiaireId]);
    
    if (result.isEmpty || result.first['average'] == null) return 0.0;
    return (result.first['average'] as num).toDouble();
  }

  Future<double> getGroupAttendanceRate(int groupId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(CASE WHEN statut = 'PRESENT' THEN 1 END) as present,
        COUNT(*) as total
      FROM presences
      WHERE groupe_id = ? AND valide_par_dp = 1
    ''', [groupId]);

    if (result.isEmpty || result.first['total'] == 0) return 100.0;
    final present = (result.first['present'] as num).toDouble();
    final total = (result.first['total'] as num).toDouble();
    return (present / total) * 100;
  }


  Future<List<Map<String, dynamic>>> getExamsAPublier({int? directorId}) async {
    final db = await database;
    String where = "e.status = 'PLANIFIE'";
    List<dynamic> args = [];
    if (directorId != null) {
      where += " AND f.director_id = ?";
      args.add(directorId);
    }

    return await db.rawQuery('''
      SELECT e.*, m.nom as module_name, g.nom as groupe_name, u.nom as formateur_name
      FROM exams e
      JOIN affectations a ON e.affectation_id = a.id
      JOIN modules m ON a.module_id = m.id
      JOIN groupes g ON a.groupe_id = g.id
      JOIN users u ON a.formateur_id = u.id
      JOIN filieres f ON g.filiere_id = f.id
      WHERE $where
      ORDER BY e.date ASC
    ''', args);
  }

  Future<void> updateExamStatus(int id, String status) async {
    final db = await database;
    await db.update(
      'exams',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}


