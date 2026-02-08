import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../models/message.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../data/database_helper.dart';
import '../../providers/notification_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

class ChatScreen extends StatefulWidget {
  final User? otherUser;
  final int? groupId;
  final String? groupName;

  const ChatScreen({
    super.key, 
    this.otherUser, 
    this.groupId, 
    this.groupName,
  }) : assert(otherUser != null || groupId != null);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  List<Message> _messages = [];
  bool _isLoading = true;
  late int _currentUserId;
  Timer? _timer;
  File? _selectedImage;
  File? _selectedPDF;
  String? _selectedLink;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  final Map<int, String> _senderNames = {};


  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    _currentUserId = user!.id!;
    _loadMessages();
    _markAsRead();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    final msgs = await DatabaseHelper.instance.getMessages(
      _currentUserId, 
      otherUserId: widget.otherUser?.id,
      groupId: widget.groupId,
    );
    
    if (mounted) {
      if (!silent || msgs.length != _messages.length) {
        if (widget.groupId != null) {
          for (var msg in msgs) {
            if (!_senderNames.containsKey(msg.senderId)) {
              final sender = await DatabaseHelper.instance.getUserById(msg.senderId);
              if (sender != null) {
                _senderNames[msg.senderId] = sender.nom;
              }
            }
          }
        }

        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
        if (!silent || (msgs.length > _messages.length)) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            }
          });
        }
      }
    }
  }

  Future<void> _markAsRead() async {
    final db = DatabaseHelper.instance;
    if (widget.groupId != null) {
      await db.markGroupMessagesAsRead(widget.groupId!, _currentUserId);
      await db.markMessageNotificationsAsRead(_currentUserId, groupId: widget.groupId);
    } else {
      await db.markMessagesAsRead(widget.otherUser!.id!, _currentUserId);
      await db.markMessageNotificationsAsRead(_currentUserId, otherUserId: widget.otherUser!.id);
    }
    
    if (mounted) {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      Provider.of<NotificationProvider>(context, listen: false).refreshCounts(user);
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedFileBytes = bytes;
          _selectedFileName = image.name;
          _selectedImage = null;
          _selectedPDF = null;
          _selectedLink = null;
        });
      } else {
        setState(() {
          _selectedImage = File(image.path);
          _selectedFileBytes = null;
          _selectedPDF = null;
          _selectedLink = null;
        });
      }
    }
  }
  Future<void> _pickPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null) {
      if (kIsWeb) {
        setState(() {
          _selectedFileBytes = result.files.single.bytes;
          _selectedFileName = result.files.single.name;
          _selectedImage = null;
          _selectedPDF = null;
          _selectedLink = null;
        });
      } else {
        setState(() {
          _selectedPDF = File(result.files.single.path!);
          _selectedFileBytes = null;
          _selectedImage = null;
          _selectedLink = null;
        });
      }
    }
  }

  Future<void> _showLinkDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajouter un lien', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'https://example.com',
            hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final link = controller.text.trim();
              if (link.isNotEmpty) {
                setState(() {
                  _selectedLink = link;
                  _selectedImage = null;
                  _selectedPDF = null;
                });
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: Text('OK', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedImage = null;
      _selectedPDF = null;
      _selectedLink = null;
      _selectedFileBytes = null;
      _selectedFileName = null;
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    
    if (text.isEmpty && _selectedImage == null && _selectedPDF == null && _selectedLink == null && _selectedFileBytes == null) return;

    String? attachmentType;
    String? attachmentUrl;
    
    if (kIsWeb && _selectedFileBytes != null) {
      if (_selectedFileName!.toLowerCase().endsWith('.pdf')) {
        attachmentType = 'pdf';
      } else {
        attachmentType = 'image';
      }
      attachmentUrl = 'data:base64,${base64Encode(_selectedFileBytes!)}|$_selectedFileName';
    } else if (_selectedImage != null) {
      attachmentType = 'image';
      attachmentUrl = _selectedImage!.path;
    } else if (_selectedPDF != null) {
      attachmentType = 'pdf';
      attachmentUrl = _selectedPDF!.path;
    } else if (_selectedLink != null) {
      attachmentType = 'link';
      attachmentUrl = _selectedLink;
    }

    final msg = Message(
      senderId: _currentUserId,
      receiverId: widget.otherUser?.id,
      groupId: widget.groupId,
      content: text.isEmpty ? 'Fichier partagé' : text,
      timestamp: DateTime.now(),
      attachmentType: attachmentType,
      attachmentUrl: attachmentUrl,
    );

    _messageController.clear();
    setState(() {
      _messages.add(msg);
      _selectedImage = null;
      _selectedPDF = null;
      _selectedLink = null;
      _selectedFileBytes = null;
      _selectedFileName = null;
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    await DatabaseHelper.instance.sendMessage(msg);
    _loadMessages(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: widget.groupId != null 
                ? AppTheme.accentOrange.withValues(alpha: 0.1)
                : AppTheme.primaryBlue.withValues(alpha: 0.1),
              child: widget.groupId != null
                ? Icon(Icons.groups_rounded, color: AppTheme.accentOrange, size: 18)
                : Text(
                    (widget.otherUser?.nom ?? 'U').substring(0, 1).toUpperCase(),
                    style: GoogleFonts.poppins(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.groupId != null ? widget.groupName! : widget.otherUser!.nom, 
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)
                ),
                Text(
                  widget.groupId != null ? 'Groupe de discussion' : widget.otherUser!.role.displayName, 
                  style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary)
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Dites bonjour ! 👋',
                          style: GoogleFonts.poppins(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.senderId == _currentUserId;
                          
                          bool showDate = false;
                          if (index == 0) {
                            showDate = true;
                          } else {
                            final prevMsg = _messages[index - 1];
                            if (!_isSameDay(msg.timestamp, prevMsg.timestamp)) {
                              showDate = true;
                            }
                          }

                          return Column(
                            children: [
                              if (showDate) _buildDateDivider(msg.timestamp),
                              _buildMessageBubble(msg, isMe),
                            ],
                          );
                        },
                      ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  Widget _buildDateDivider(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            DateFormat('d MMMM y', 'fr_FR').format(date),
            style: GoogleFonts.poppins(
              fontSize: 10, 
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryBlue : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe && widget.groupId != null) ...[
              Text(
                _senderNames[msg.senderId] ?? 'Utilisateur',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (msg.attachmentType != null) ...[
              _buildAttachment(msg, isMe),
              if (msg.content.isNotEmpty && msg.content != 'Fichier partagé') const SizedBox(height: 8),
            ],
            if (msg.content.isNotEmpty && msg.content != 'Fichier partagé')
              Text(
                msg.content,
                style: GoogleFonts.poppins(
                  color: isMe ? Colors.white : AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.poppins(
                    color: isMe ? Colors.white.withValues(alpha: 0.7) : AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.isRead ? Icons.done_all : Icons.check,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachment(Message msg, bool isMe) {
    bool isBase64 = msg.attachmentUrl?.startsWith('data:base64,') ?? false;
    Uint8List? bytes;
    String? fileName;
    if (isBase64) {
      final parts = msg.attachmentUrl!.split('|');
      final base64Data = parts[0].substring('data:base64,'.length);
      bytes = base64Decode(base64Data);
      if (parts.length > 1) fileName = parts[1];
    }

    if (msg.attachmentType == 'image') {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
                body: Center(
                  child: isBase64 
                    ? Image.memory(bytes!) 
                    : (kIsWeb ? const Icon(Icons.image, color: Colors.white, size: 50) : Image.file(File(msg.attachmentUrl!))),
                ),
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: isBase64
            ? Image.memory(bytes!, width: 200, height: 200, fit: BoxFit.cover)
            : (kIsWeb 
                ? Container(width: 200, height: 200, color: Colors.grey.shade200, child: const Icon(Icons.image)) 
                : Image.file(File(msg.attachmentUrl!), width: 200, height: 200, fit: BoxFit.cover)),
        ),
      );
    } else if (msg.attachmentType == 'pdf') {
      final displayName = isBase64 ? (fileName ?? 'Document PDF') : msg.attachmentUrl!.split('/').last;
      return GestureDetector(
        onTap: () async {
          if (isBase64) {
            try {
              final parts = msg.attachmentUrl!.split('|');
              final base64Data = parts[0].substring('data:base64,'.length);
              final bytes = base64Decode(base64Data);
              
              await Printing.layoutPdf(
                onLayout: (_) => bytes,
                name: parts.length > 1 ? parts[1] : 'Chat_Document',
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur lors de l\'affichage du PDF : $e')),
                );
              }
            }
          } else {
            final url = Uri.file(msg.attachmentUrl!);
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf, color: isMe ? Colors.white : Colors.red, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.poppins(
                        color: isMe ? Colors.white : AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'PDF Document',
                      style: GoogleFonts.poppins(
                        color: isMe ? Colors.white.withValues(alpha: 0.7) : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else if (msg.attachmentType == 'link') {
      return GestureDetector(
        onTap: () async {
          final url = Uri.parse(msg.attachmentUrl!);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.link, color: isMe ? Colors.white : AppTheme.primaryBlue, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  msg.attachmentUrl!,
                  style: GoogleFonts.poppins(
                    color: isMe ? Colors.white : AppTheme.primaryBlue,
                    decoration: TextDecoration.underline,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedImage != null || _selectedPDF != null || _selectedLink != null || _selectedFileBytes != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                if (_selectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_selectedImage!, width: 50, height: 50, fit: BoxFit.cover),
                  )
                else if (_selectedFileBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _selectedFileName!.toLowerCase().endsWith('.pdf')
                      ? Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
                        )
                      : Image.memory(_selectedFileBytes!, width: 50, height: 50, fit: BoxFit.cover),
                  )
                else if (_selectedPDF != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
                  )
                else if (_selectedLink != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.link, color: AppTheme.primaryBlue, size: 30),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedImage != null ? 'Image sélectionnée' : 
                    _selectedFileBytes != null ? _selectedFileName! :
                    _selectedPDF != null ? _selectedPDF!.path.split('/').last : 
                    _selectedLink!,
                    style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: _clearSelection,
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                offset: const Offset(0, -2),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.image_outlined, color: AppTheme.primaryBlue),
                onPressed: _pickImage,
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.primaryBlue),
                onPressed: _pickPDF,
              ),
              IconButton(
                icon: const Icon(Icons.link_rounded, color: AppTheme.primaryBlue),
                onPressed: _showLinkDialog,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Votre message...',
                    hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  minLines: 1,
                  maxLines: 4,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

