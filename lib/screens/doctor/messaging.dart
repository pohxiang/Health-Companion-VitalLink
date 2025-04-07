import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';

class MessagingPage extends StatefulWidget {
  final String? initialConversationId;

  const MessagingPage({Key? key, this.initialConversationId}) : super(key: key);

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _currentUserId;
  String? _selectedChatId;
  String _selectedRecipientId = '';
  String _selectedRecipientName = '';
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _recentChats = [];
  bool _isLoading = true;
  bool _isLargeScreen = false;
  String? _selectedConversationId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _selectedConversationId = widget.initialConversationId;

    // If initial conversation provided, load it
    if (_selectedConversationId != null) {
      _loadConversation(_selectedConversationId!);
    }
  }

  Future<void> _getCurrentUser() async {
    final user = _firestoreService.getCurrentUser();
    if (user != null) {
      setState(() {
        // Use UID instead of email
        _currentUserId = user.uid;
        _isLoading = false;
      });
      await _loadRecentChats();
    }
  }

  Future<void> _loadRecentChats() async {
    if (_currentUserId == null) return;

    try {
      // Get all chat rooms where the current user is a participant
      QuerySnapshot chatRoomsSnapshot = await _firestoreService
          .messagingCollection
          .where('participants', arrayContains: _currentUserId)
          .orderBy('lastMessageTime', descending: true)
          .get();

      List<Map<String, dynamic>> chats = [];

      for (var doc in chatRoomsSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // Get the other participant (not the current user)
        List<String> participants =
            List<String>.from(data['participants'] ?? []);
        String otherParticipantId = participants.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => 'Unknown',
        );

        // Get user details based on ID
        String userType = await _determineUserType(otherParticipantId);
        DocumentSnapshot? userDoc =
            await _getUserDocument(otherParticipantId, userType);

        String displayName = 'Unknown User';
        if (userDoc != null && userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>?;
          if (userData != null) {
            displayName =
                '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}';
            if (displayName.trim().isEmpty) {
              displayName = otherParticipantId;
            }
          }
        }

        chats.add({
          'chatId': doc.id,
          'participantId': otherParticipantId,
          'participantName': displayName,
          'lastMessage': data['lastMessage'] ?? 'Start chatting',
          'lastMessageTime': data['lastMessageTime'] ?? Timestamp.now(),
          'unreadCount': data['unreadCount_$_currentUserId'] ?? 0,
          'userType': userType,
        });
      }

      setState(() {
        _recentChats = chats;
      });
    } catch (e) {
      print('Error loading chats: $e');
    }
  }

  Future<String> _determineUserType(String userId) async {
    try {
      // Check each collection to find the user
      DocumentSnapshot doctorDoc =
          await _firestoreService.doctorsCollection.doc(userId).get();
      if (doctorDoc.exists) return 'doctor';

      DocumentSnapshot patientDoc =
          await _firestoreService.patientsCollection.doc(userId).get();
      if (patientDoc.exists) return 'patient';

      DocumentSnapshot receptionistDoc =
          await _firestoreService.receptionistsCollection.doc(userId).get();
      if (receptionistDoc.exists) return 'receptionist';

      return 'unknown';
    } catch (e) {
      print('Error determining user type: $e');
      return 'unknown';
    }
  }

  Future<DocumentSnapshot?> _getUserDocument(
      String userId, String userType) async {
    try {
      switch (userType) {
        case 'doctor':
          return await _firestoreService.doctorsCollection.doc(userId).get();
        case 'patient':
          return await _firestoreService.patientsCollection.doc(userId).get();
        case 'receptionist':
          return await _firestoreService.receptionistsCollection
              .doc(userId)
              .get();
        default:
          return null;
      }
    } catch (e) {
      print('Error getting user document: $e');
      return null;
    }
  }

  void _selectChat(String chatId, String recipientId, String recipientName) {
    setState(() {
      _selectedChatId = chatId;
      _selectedRecipientId = recipientId;
      _selectedRecipientName = recipientName;
    });

    // Mark messages as read
    _markMessagesAsRead(chatId);

    // Scroll to bottom of messages when loaded
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

  Future<void> _markMessagesAsRead(String chatId) async {
    try {
      // Update the unread count for the current user to 0
      await _firestoreService.messagingCollection.doc(chatId).update({
        'unreadCount_$_currentUserId': 0,
      });

      // Refresh the chat list to update UI
      _loadRecentChats();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty ||
        _selectedChatId == null ||
        _selectedRecipientId.isEmpty) return;

    String messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      // Use the FirestoreService to send message
      await _firestoreService.sendMessage(
        chatRoomId: _selectedChatId!,
        senderId: _currentUserId!,
        receiverId: _selectedRecipientId,
        text: messageText,
      );

      // Also update the lastMessage and unread count
      await _firestoreService.messagingCollection.doc(_selectedChatId).update({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount_$_selectedRecipientId': FieldValue.increment(1),
      });

      // Scroll to bottom after sending message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<void> _createNewChat(BuildContext context) async {
    if (_currentUserId == null) return;

    // Show a bottom sheet with a list of users to chat with
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Start a new conversation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Patients',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: _firestoreService.patientsCollection.get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No patients found'));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var patientDoc = snapshot.data!.docs[index];
                        var patientData =
                            patientDoc.data() as Map<String, dynamic>;
                        String patientId = patientDoc.id;
                        String patientName =
                            '${patientData['firstName'] ?? ''} ${patientData['lastName'] ?? ''}';

                        if (patientId == _currentUserId)
                          return const SizedBox(); // Skip self

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            child: const Icon(Icons.person, color: Colors.blue),
                          ),
                          title: Text(patientName),
                          subtitle: const Text('Patient'),
                          onTap: () async {
                            // Check if a chat already exists
                            QuerySnapshot existingChats =
                                await _firestoreService.messagingCollection
                                    .where('participants',
                                        arrayContains: _currentUserId)
                                    .get();

                            String? existingChatId;
                            for (var doc in existingChats.docs) {
                              List<String> participants = List<String>.from(
                                  (doc.data()
                                      as Map<String, dynamic>)['participants']);
                              if (participants.contains(patientId)) {
                                existingChatId = doc.id;
                                break;
                              }
                            }

                            if (existingChatId != null) {
                              // Chat already exists, just open it
                              Navigator.pop(context);
                              _selectChat(
                                  existingChatId, patientId, patientName);
                            } else {
                              // Create a new chat room
                              String chatRoomId = await _firestoreService
                                  .createChatRoom([_currentUserId!, patientId]);

                              // Initialize the chat room with metadata
                              await _firestoreService.messagingCollection
                                  .doc(chatRoomId)
                                  .set({
                                'participants': [_currentUserId!, patientId],
                                'lastMessage': 'Start a conversation',
                                'lastMessageTime': FieldValue.serverTimestamp(),
                                'unreadCount_$_currentUserId': 0,
                                'unreadCount_$patientId': 0,
                              });

                              Navigator.pop(context);
                              await _loadRecentChats();
                              _selectChat(chatRoomId, patientId, patientName);
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we're on a large screen (tablet/desktop) or small screen (phone)
    _isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: _isLargeScreen || _selectedChatId == null
            ? const Text('Messages')
            : Text(_selectedRecipientName),
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: _isLargeScreen || _selectedChatId == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedChatId = null;
                    _selectedRecipientName = '';
                  });
                },
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isLargeScreen
              ? _buildLargeScreenLayout()
              : _buildSmallScreenLayout(),
      floatingActionButton:
          (!_isLargeScreen && _selectedChatId != null) || _isLoading
              ? null
              : FloatingActionButton(
                  backgroundColor: Colors.black,
                  child: const Icon(Icons.add),
                  onPressed: () => _createNewChat(context),
                ),
    );
  }

  // Layout for large screens (tablet/desktop) - split view
  Widget _buildLargeScreenLayout() {
    return Row(
      children: [
        // Chat list - left side
        Expanded(
          flex: 3,
          child: _buildChatList(),
        ),

        // Chat messages - right side
        Expanded(
          flex: 5,
          child: _selectedChatId == null
              ? _buildEmptyChatPlaceholder()
              : _buildChatMessages(),
        ),
      ],
    );
  }

  // Layout for small screens (phones) - single view
  Widget _buildSmallScreenLayout() {
    if (_selectedChatId == null) {
      return _buildChatList();
    } else {
      return _buildChatMessages();
    }
  }

  // Chat list widget (left side on large screens, full screen on small screens when no chat selected)
  Widget _buildChatList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: _isLargeScreen
              ? BorderSide(color: Colors.grey.shade300)
              : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search conversations',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          Expanded(
            child: _recentChats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 70, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _createNewChat(context),
                          child: const Text('Start a conversation'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _recentChats.length,
                    itemBuilder: (context, index) {
                      var chat = _recentChats[index];
                      bool isSelected = _selectedChatId == chat['chatId'];

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Colors.blue.withOpacity(0.1),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: _getUserColor(chat['userType'])
                                  .withOpacity(0.1),
                              child: Icon(
                                _getUserIcon(chat['userType']),
                                color: _getUserColor(chat['userType']),
                              ),
                            ),
                            if (chat['unreadCount'] > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    chat['unreadCount'].toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          chat['participantName'],
                          style: TextStyle(
                            fontWeight: chat['unreadCount'] > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          chat['lastMessage'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          _formatTimestamp(chat['lastMessageTime']),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        onTap: () => _selectChat(
                          chat['chatId'],
                          chat['participantId'],
                          chat['participantName'],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Empty chat placeholder (shown when no chat is selected on large screens)
  Widget _buildEmptyChatPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Select a conversation to start chatting',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _createNewChat(context),
            child: const Text('Start a new conversation'),
          ),
        ],
      ),
    );
  }

  // Chat messages widget (right side on large screens, full screen on small screens when chat selected)
  Widget _buildChatMessages() {
    return Column(
      children: [
        // Chat header (only shown on large screens)
        if (_isLargeScreen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: const Icon(Icons.person, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedRecipientName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        // Messages
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.getMessages(_selectedChatId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat, size: 70, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('No messages yet'),
                      const SizedBox(height: 8),
                      const Text('Start the conversation!'),
                    ],
                  ),
                );
              }

              // Scroll to bottom when new messages come in
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var messageData = snapshot.data!.docs[index].data()
                        as Map<String, dynamic>;
                    bool isCurrentUser =
                        messageData['senderId'] == _currentUserId;

                    return _buildMessageBubble(
                      message: messageData['text'] ?? '',
                      isCurrentUser: isCurrentUser,
                      timestamp: messageData['timestamp'] ?? Timestamp.now(),
                      isRead: messageData['read'] ?? false,
                    );
                  },
                ),
              );
            },
          ),
        ),

        // Message input
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: () {
                  // Attachment functionality would go here
                },
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                color: Colors.blue,
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required bool isCurrentUser,
    required Timestamp timestamp,
    required bool isRead,
  }) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _formatMessageTime(timestamp),
                  style: TextStyle(
                    color: isCurrentUser
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey[600],
                    fontSize: 10,
                  ),
                ),
                if (isCurrentUser) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 12,
                    color: isCurrentUser
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey[600],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();

    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      return DateFormat('h:mm a').format(dateTime);
    } else if (dateTime.year == now.year) {
      return DateFormat('MMM d').format(dateTime);
    } else {
      return DateFormat('MM/dd/yy').format(dateTime);
    }
  }

  String _formatMessageTime(Timestamp timestamp) {
    return DateFormat('h:mm a').format(timestamp.toDate());
  }

  IconData _getUserIcon(String userType) {
    switch (userType) {
      case 'patient':
        return Icons.person;
      case 'doctor':
        return Icons.medical_services;
      case 'receptionist':
        return Icons.support_agent;
      default:
        return Icons.person_outline;
    }
  }

  Color _getUserColor(String userType) {
    switch (userType) {
      case 'patient':
        return Colors.blue;
      case 'doctor':
        return Colors.green;
      case 'receptionist':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _loadConversation(String conversationId) async {
    try {
      // Get the chat room document
      DocumentSnapshot chatDoc =
          await _firestoreService.messagingCollection.doc(conversationId).get();

      if (!chatDoc.exists) {
        print('Chat room not found: $conversationId');
        return;
      }

      // Extract data from the chat document
      var chatData = chatDoc.data() as Map<String, dynamic>;
      List<String> participants =
          List<String>.from(chatData['participants'] ?? []);

      // Find the other participant (not the current user)
      String? otherParticipantId;
      if (_currentUserId != null) {
        otherParticipantId = participants.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => '',
        );
      }

      if (otherParticipantId == null || otherParticipantId.isEmpty) {
        print('Could not determine other participant');
        return;
      }

      // Get user type and details
      String userType = await _determineUserType(otherParticipantId);
      DocumentSnapshot? userDoc =
          await _getUserDocument(otherParticipantId, userType);

      String displayName = 'Unknown User';
      if (userDoc != null && userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null) {
          displayName =
              '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}';
          if (displayName.trim().isEmpty) {
            displayName = otherParticipantId;
          }
        }
      }

      // Select this chat
      setState(() {
        _selectedChatId = conversationId;
        _selectedRecipientId = otherParticipantId ?? '';
        _selectedRecipientName = displayName;
      });

      // Mark messages as read
      await _markMessagesAsRead(conversationId);

      // Refresh the chat list
      await _loadRecentChats();

      // Scroll to bottom of messages when they load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Error loading conversation: $e');
    }
  }
}
