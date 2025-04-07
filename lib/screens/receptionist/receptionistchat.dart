import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'package:icons_flutter/icons_flutter.dart';

// Global search query (if needed elsewhere)
// ignore: unused_element
String _searchQuery = '';
// ignore: unused_element
final TextEditingController _searchController = TextEditingController();

class ReceptionistChatPage extends StatefulWidget {
  const ReceptionistChatPage({Key? key}) : super(key: key);

  @override
  State<ReceptionistChatPage> createState() => _ReceptionistChatPageState();
}

class _ReceptionistChatPageState extends State<ReceptionistChatPage> {
  // Service for Firestore interactions
  final FirestoreService _firestoreService = FirestoreService();

  // User interface controllers
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Chat UI state management
  String? _currentUserId;
  String? _selectedChatId;
  String _selectedRecipientId = '';
  String _selectedRecipientName = '';
  String _searchQuery = '';

  // Data stores
  List<Map<String, dynamic>> _recentChats = [];
  StreamSubscription<QuerySnapshot>? _chatSubscription;
  bool _isLoading = true;
  // This flag ensures we display the spinner until the first snapshot is processed.
  bool _initialLoadCompleted = false;
  bool _isLargeScreen = false;

  @override
  void initState() {
    super.initState();
    _initializeChatSession();
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  /// Initializes chat session with real-time updates.
  /// Sets loading state until the current user's data is ready.
  void _initializeChatSession() async {
    setState(() => _isLoading = true);
    final user = _firestoreService.getCurrentUser();
    if (user != null) {
      _currentUserId = user.uid;
      _setupRealTimeUpdates();
    }
    // Note: _isLoading remains true until the snapshot listener processes at least one update.
    // Once that happens, _initialLoadCompleted is set to true.
  }

  /// Sets up Firestore stream for real-time conversation updates.
  void _setupRealTimeUpdates() {
    // Cancel any existing subscription before setting up a new one.
    _chatSubscription?.cancel();
    _chatSubscription = _firestoreService.messagingCollection
        .where('participants', arrayContains: _currentUserId)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .listen((snapshot) async {
      await _processConversations(snapshot.docs);
      // Mark that we've received data at least once.
      if (!_initialLoadCompleted) {
        setState(() {
          _initialLoadCompleted = true;
          _isLoading = false;
        });
      }
    });
  }

  /// Processes conversation documents with participant details.
  Future<void> _processConversations(List<QueryDocumentSnapshot> docs) async {
    List<Map<String, dynamic>> chats = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final participants = List<String>.from(data['participants'] ?? []);
      final otherParticipantId = participants.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => 'Unknown',
      );

      // Get doctor and patient details from Firestore
      final doctorDoc = await _firestoreService.doctorsCollection
          .doc(otherParticipantId)
          .get();
      final patientDoc = await _firestoreService.patientsCollection
          .doc(otherParticipantId)
          .get();

      String displayName = 'Unknown User';
      String specialty = '';

      if (doctorDoc.exists) {
        final doctorData = doctorDoc.data() as Map<String, dynamic>;
        displayName =
            'Dr. ${doctorData['firstName']} ${doctorData['lastName']}';
        specialty = doctorData['department'] ?? '';
      } else if (patientDoc.exists) {
        final patientData = patientDoc.data() as Map<String, dynamic>;
        displayName = '${patientData['firstName']} ${patientData['lastName']}';
        specialty = 'Patient';
      }

      chats.add({
        'chatId': doc.id,
        'participantId': otherParticipantId,
        'participantName': displayName,
        'specialty': specialty,
        'lastMessage': data['lastMessage'] ?? 'Start chatting',
        'lastUpdated': data['lastUpdated'] ?? Timestamp.now(),
        'unreadCount': data['unreadCount_$_currentUserId'] ?? 0,
        'isMedicalStaff': doctorDoc.exists,
      });
    }

    if (mounted) {
      setState(() => _recentChats = chats);
    }
  }

  /// Cleans up controllers and listeners.
  void _cleanupResources() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatSubscription?.cancel();
  }

  /// Loads recent chat conversations from Firestore manually (e.g., via refresh).
  Future<void> _loadRecentConversations() async {
    if (_currentUserId == null) return;

    try {
      // Query all conversations where receptionist is a participant.
      QuerySnapshot chatRoomsSnapshot = await _firestoreService
          .messagingCollection
          .where('participants', arrayContains: _currentUserId)
          .orderBy('lastUpdated', descending: true)
          .get();

      List<Map<String, dynamic>> chats = [];

      for (var doc in chatRoomsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final participants = List<String>.from(data['participants'] ?? []);
        final otherParticipantId = participants.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => 'Unknown',
        );

        // Get participant details from both doctors and patients collections.
        final doctorDoc = await _firestoreService.doctorsCollection
            .doc(otherParticipantId)
            .get();
        final patientDoc = await _firestoreService.patientsCollection
            .doc(otherParticipantId)
            .get();

        String displayName = 'Unknown User';
        String specialty = '';

        // Prioritize doctor information if exists.
        if (doctorDoc.exists) {
          final doctorData = doctorDoc.data() as Map<String, dynamic>;
          displayName =
              'Dr. ${doctorData['firstName']} ${doctorData['lastName']}';
          specialty = doctorData['department'] ?? '';
        } else if (patientDoc.exists) {
          final patientData = patientDoc.data() as Map<String, dynamic>;
          displayName =
              '${patientData['firstName']} ${patientData['lastName']}';
          specialty = 'Patient';
        }

        chats.add({
          'chatId': doc.id,
          'participantId': otherParticipantId,
          'participantName': displayName,
          'specialty': specialty,
          'lastMessage': data['lastMessage'] ?? 'Start chatting',
          'lastUpdated': data['lastUpdated'] ?? Timestamp.now(),
          'unreadCount': data['unreadCount_$_currentUserId'] ?? 0,
          'isMedicalStaff': doctorDoc.exists,
        });
      }

      setState(() => _recentChats = chats);
    } catch (e) {
      print('Error loading conversations: $e');
    }
  }

  /// Handles chat selection and marks messages as read.
  void _selectConversation(
      String chatId, String recipientId, String recipientName) {
    setState(() {
      _selectedChatId = chatId;
      _selectedRecipientId = recipientId;
      _selectedRecipientName = recipientName;
    });
    _markMessagesAsRead(chatId);
    _scrollToBottom();
  }

  /// Marks all messages in a conversation as read.
  Future<void> _markMessagesAsRead(String chatId) async {
    try {
      await _firestoreService.messagingCollection.doc(chatId).update({
        'unreadCount_$_currentUserId': 0,
      });
      if (mounted) setState(() {});
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  /// Handles message composition and delivery.
  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedChatId == null)
      return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      await _firestoreService.sendMessage(
        chatRoomId: _selectedChatId!,
        senderId: _currentUserId!,
        receiverId: _selectedRecipientId,
        text: messageText,
      );

      await _firestoreService.messagingCollection.doc(_selectedChatId).update({
        'lastMessage': messageText,
        'lastUpdated': FieldValue.serverTimestamp(),
        'unreadCount_$_selectedRecipientId': FieldValue.increment(1),
      });

      _scrollToBottom();
    } catch (e) {
      print('Message delivery failed: $e');
    }
  }

  /// Builds the main chat interface.
  @override
  Widget build(BuildContext context) {
    _isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: _isLargeScreen || _selectedChatId == null
            ? const Text('Receptionist Messages')
            : Text(_selectedRecipientName),
        backgroundColor: Colors.blue[700],
        actions: [
          // Show refresh button only when not in a selected conversation on small screens.
          if (_isLargeScreen || _selectedChatId == null)
            IconButton(
              icon: const Icon(FontAwesome.refresh),
              onPressed: _handleRefresh,
              tooltip: 'Refresh Conversations',
            ),
        ],
      ),
      body: _buildBodyLayout(),
      floatingActionButton: _buildNewChatButton(),
    );
  }

  /// Handles refresh action by reloading conversations and showing a loading indicator.
  Future<void> _handleRefresh() async {
    setState(() {
      _isLoading = true;
      _initialLoadCompleted = false;
    });
    // Reload conversations manually.
    await _loadRecentConversations();
    // Reinitialize real-time updates to ensure the stream is up-to-date.
    _setupRealTimeUpdates();
    setState(() {
      _isLoading = false;
      _initialLoadCompleted = true;
    });
  }

  /// Determines appropriate body layout based on screen size and load state.
  Widget _buildBodyLayout() {
    // Show a loading indicator until the initial conversation data is loaded.
    if (_isLoading || !_initialLoadCompleted) {
      return const Center(child: CircularProgressIndicator());
    }

    return _isLargeScreen
        ? Row(
            children: [
              Expanded(flex: 3, child: _buildConversationList()),
              Expanded(
                  flex: 5,
                  child: _selectedChatId == null
                      ? _buildEmptyState()
                      : _buildChatInterface()),
            ],
          )
        : _selectedChatId == null
            ? _buildConversationList()
            : _buildChatInterface();
  }

  /// Builds the list of recent conversations.
  Widget _buildConversationList() {
    final filteredChats = _recentChats.where((chat) {
      final name = chat['participantName'].toString().toLowerCase();
      final specialty = chat['specialty'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || specialty.contains(query);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            right: _isLargeScreen
                ? BorderSide(color: Colors.grey.shade300)
                : BorderSide.none),
      ),
      child: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: filteredChats.isEmpty
                ? _buildEmptyConversationList()
                : ListView.builder(
                    itemCount: filteredChats.length,
                    itemBuilder: (context, index) =>
                        _conversationListItem(filteredChats[index]),
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds individual conversation list item.
  Widget _conversationListItem(Map<String, dynamic> chat) {
    final isSelected = _selectedChatId == chat['chatId'];
    final isMedicalStaff = chat['isMedicalStaff'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isSelected ? Colors.blue.withOpacity(0.1) : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildParticipantAvatar(chat, isMedicalStaff),
        title: Text(
          chat['participantName'],
          style: TextStyle(
            fontWeight:
                chat['unreadCount'] > 0 ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        subtitle: _buildConversationPreview(chat),
        trailing: _buildConversationMetadata(chat),
        onTap: () => _selectConversation(
          chat['chatId'],
          chat['participantId'],
          chat['participantName'],
        ),
      ),
    );
  }

  /// Builds participant avatar with role indication.
  Widget _buildParticipantAvatar(
      Map<String, dynamic> chat, bool isMedicalStaff) {
    return Stack(
      children: [
        CircleAvatar(
          backgroundColor:
              isMedicalStaff ? Colors.blue[700] : Colors.green[700],
          radius: 24,
          child: Icon(
            isMedicalStaff ? FontAwesome.user_md : FontAwesome.user,
            color: Colors.white,
          ),
        ),
        if (chat['unreadCount'] > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                chat['unreadCount'].toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds conversation preview with last message.
  Widget _buildConversationPreview(Map<String, dynamic> chat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chat['specialty']?.isNotEmpty == true)
          Row(
            children: [
              Icon(
                chat['isMedicalStaff']
                    ? FontAwesome.stethoscope
                    : FontAwesome.user,
                size: 12,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                chat['specialty'],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        const SizedBox(height: 4),
        Text(
          chat['lastMessage'],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: chat['unreadCount'] > 0 ? Colors.black87 : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// Builds conversation metadata (timestamp and navigation indicator).
  Widget _buildConversationMetadata(Map<String, dynamic> chat) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _formatTimestamp(chat['lastUpdated']),
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const Icon(FontAwesome.chevron_right, size: 14, color: Colors.grey),
      ],
    );
  }

  /// Builds the active chat interface.
  Widget _buildChatInterface() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.getMessages(_selectedChatId!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.builder(
                controller: _scrollController,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) => _buildMessageBubble(
                  snapshot.data!.docs[index].data() as Map<String, dynamic>,
                ),
              );
            },
          ),
        ),
        _buildMessageComposer(),
      ],
    );
  }

  /// Builds individual message bubble.
  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isSentByReceptionist = message['senderId'] == _currentUserId;

    return Align(
      alignment:
          isSentByReceptionist ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSentByReceptionist ? Colors.blue[700] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message['text'] ?? '',
                style: TextStyle(
                    color:
                        isSentByReceptionist ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message['timestamp']),
              style: TextStyle(
                color: isSentByReceptionist ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds message input composer.
  Widget _buildMessageComposer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            backgroundColor: Colors.blue[700],
            onPressed: _sendMessage,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  /// Builds empty state widget for chat interface.
  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FontAwesome.comments_o, size: 70, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Select a conversation',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );

  /// Builds empty conversation list widget.
  Widget _buildEmptyConversationList() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FontAwesome.comments_o, size: 70, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
                _searchQuery.isEmpty
                    ? 'No conversations yet'
                    : 'No matching conversations',
                style: TextStyle(color: Colors.grey[600])),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: const Text('Clear search'),
              )
            ]
          ],
        ),
      );

  /// Builds the "New Conversation" floating button.
  Widget _buildNewChatButton() {
    // Hide new chat button when loading or when in a chat on small screens.
    final shouldShow =
        !((!_isLargeScreen && _selectedChatId != null) || _isLoading);
    return Visibility(
      visible: shouldShow,
      child: FloatingActionButton(
        backgroundColor: Colors.blue[700],
        onPressed: _showContactSelection,
        child: const Icon(FontAwesome.pencil),
        tooltip: 'New Conversation',
      ),
    );
  }

  /// Shows contact selection interface in a modal bottom sheet.
  void _showContactSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildContactSelectionSheet(),
    );
  }

  /// Builds contact selection bottom sheet.
  Widget _buildContactSelectionSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSheetHeader(),
          const Divider(),
          Expanded(child: _buildContactTabs()),
        ],
      ),
    );
  }

  /// Builds bottom sheet header.
  Widget _buildSheetHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Select Contact',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  /// Builds tabbed contact interface for Medical Staff and Patients.
  Widget _buildContactTabs() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Medical Staff'),
              Tab(text: 'Patients'),
            ],
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildMedicalStaffList(),
                _buildPatientList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds list of medical staff (doctors).
  Widget _buildMedicalStaffList() {
    return FutureBuilder<QuerySnapshot>(
      future: _firestoreService.doctorsCollection.get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyContactList('No medical staff available');
        }
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) =>
              _buildMedicalStaffItem(snapshot.data!.docs[index]),
        );
      },
    );
  }

  /// Builds individual medical staff list item.
  Widget _buildMedicalStaffItem(QueryDocumentSnapshot doc) {
    final doctor = doc.data() as Map<String, dynamic>;
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.blue,
        child: Icon(FontAwesome.user_md, color: Colors.white),
      ),
      title: Text('Dr. ${doctor['firstName']} ${doctor['lastName']}'),
      subtitle: Text(doctor['department'] ?? 'General Practitioner'),
      trailing: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
      onTap: () => _startNewConversation(doc.id, 'Dr. ${doctor['firstName']}'),
    );
  }

  /// Builds list of patients.
  Widget _buildPatientList() {
    return FutureBuilder<QuerySnapshot>(
      future: _firestoreService.patientsCollection.get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyContactList('No patients available');
        }
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) =>
              _buildPatientItem(snapshot.data!.docs[index]),
        );
      },
    );
  }

  /// Builds individual patient list item.
  Widget _buildPatientItem(QueryDocumentSnapshot doc) {
    final patient = doc.data() as Map<String, dynamic>;
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.green,
        child: Icon(FontAwesome.user, color: Colors.white),
      ),
      title: Text('${patient['firstName']} ${patient['lastName']}'),
      subtitle: const Text('Patient'),
      trailing: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
      onTap: () => _startNewConversation(doc.id, '${patient['firstName']}'),
    );
  }

  /// Starts new conversation with selected contact.
  void _startNewConversation(String userId, String displayName) async {
    Navigator.pop(context); // Close selection sheet

    // Check existing conversations.
    final existingChats = await _firestoreService.messagingCollection
        .where('participants', arrayContains: _currentUserId)
        .get();

    String? existingChatId;
    for (var doc in existingChats.docs) {
      final participants = List<String>.from(doc['participants']);
      if (participants.contains(userId)) {
        existingChatId = doc.id;
        break;
      }
    }

    if (existingChatId != null) {
      _selectConversation(existingChatId, userId, displayName);
    } else {
      final chatId =
          await _firestoreService.createChatRoom([_currentUserId!, userId]);

      await _firestoreService.messagingCollection.doc(chatId).set({
        'participants': [_currentUserId!, userId],
        'lastMessage': 'Conversation started',
        'lastUpdated': FieldValue.serverTimestamp(),
        'unreadCount_$_currentUserId': 0,
        'unreadCount_$userId': 0,
      });

      await _loadRecentConversations();
      _selectConversation(chatId, userId, displayName);
    }
  }

  /// Builds empty contact list widget.
  Widget _buildEmptyContactList(String message) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FontAwesome.users, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      );

  /// Helper method to scroll chat view to bottom when new messages are loaded.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Builds search bar widget for filtering conversations.
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search conversations',
          prefixIcon: const Icon(FontAwesome.search),
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  /// Formats timestamps for display.
  String _formatTimestamp(dynamic timestamp) {
    try {
      final date = (timestamp as Timestamp).toDate();
      final now = DateTime.now();

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return DateFormat('h:mm a').format(date);
      }
      return DateFormat('MMM d, y').format(date);
    } catch (_) {
      return 'Now';
    }
  }
}
