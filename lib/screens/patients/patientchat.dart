import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'package:icons_flutter/icons_flutter.dart';

class PatientChatPage extends StatefulWidget {
  const PatientChatPage({super.key});

  @override
  State<PatientChatPage> createState() => _PatientChatPageState();
}

class _PatientChatPageState extends State<PatientChatPage> {
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

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    final user = _firestoreService.getCurrentUser();
    if (user != null) {
      setState(() {
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
          .orderBy('lastUpdated', descending: true)
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
        String specialty = '';
        if (userDoc != null && userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>?;
          if (userData != null) {
            displayName =
                'Dr. ${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}';
            specialty = userData['department'] ?? '';
            if (displayName.trim().isEmpty) {
              displayName = otherParticipantId;
            }
          }
        }

        chats.add({
          'chatId': doc.id,
          'participantId': otherParticipantId,
          'participantName': displayName,
          'specialty': specialty,
          'lastMessage': data['lastMessage'] ?? 'Start chatting',
          'lastUpdated': data['lastUpdated'] ?? Timestamp.now(),
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
        _selectedRecipientId.isEmpty) {
      return;
    }

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
        'lastUpdated': FieldValue.serverTimestamp(),
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

    // Show a bottom sheet with a list of doctors to chat with
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Message Your Doctor',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: _firestoreService.doctorsCollection.get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              FontAwesome.user_md,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No doctors found',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var doctorDoc = snapshot.data!.docs[index];
                        var doctorData =
                            doctorDoc.data() as Map<String, dynamic>;
                        String doctorId = doctorDoc.id;
                        String doctorName =
                            'Dr. ${doctorData['firstName'] ?? ''} ${doctorData['lastName'] ?? ''}';
                        String specialty = doctorData['department'] ?? '';

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[700],
                              radius: 25,
                              child: const Icon(
                                FontAwesome.user_md,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              doctorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: specialty.isNotEmpty
                                ? Row(
                                    children: [
                                      Icon(
                                        FontAwesome.stethoscope,
                                        size: 12,
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        specialty,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                            trailing: Icon(
                              FontAwesome.comments,
                              color: Colors.blue[700],
                            ),
                            onTap: () async {
                              // Check if a chat already exists with this doctor
                              QuerySnapshot existingChats =
                                  await _firestoreService.messagingCollection
                                      .where('participants',
                                          arrayContains: _currentUserId)
                                      .get();

                              String? existingChatId;
                              for (var doc in existingChats.docs) {
                                List<String> participants = List<String>.from(
                                    (doc.data() as Map<String, dynamic>)[
                                        'participants']);
                                if (participants.contains(doctorId)) {
                                  existingChatId = doc.id;
                                  break;
                                }
                              }

                              if (existingChatId != null) {
                                // Chat already exists, open it
                                Navigator.pop(context);
                                _selectChat(
                                    existingChatId, doctorId, doctorName);
                              } else {
                                // Create a new chat room
                                String chatRoomId = await _firestoreService
                                    .createChatRoom(
                                        [_currentUserId!, doctorId]);

                                // Initialize the chat room with metadata
                                await _firestoreService.messagingCollection
                                    .doc(chatRoomId)
                                    .set({
                                  'participants': [_currentUserId!, doctorId],
                                  'lastMessage': 'Start a conversation',
                                  'lastUpdated': FieldValue.serverTimestamp(),
                                  'unreadCount_$_currentUserId': 0,
                                  'unreadCount_$doctorId': 0,
                                });

                                Navigator.pop(context);
                                await _loadRecentChats();
                                _selectChat(chatRoomId, doctorId, doctorName);
                              }
                            },
                          ),
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
      appBar: AppBar(
        title: _isLargeScreen || _selectedChatId == null
            ? const Text('My Messages')
            : Text(_selectedRecipientName),
        backgroundColor: Colors.blue[700],
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
        actions: [
          if (_isLargeScreen || _selectedChatId == null)
            IconButton(
              icon: const Icon(FontAwesome.refresh),
              onPressed: _loadRecentChats,
            ),
        ],
      ),
      backgroundColor: Colors.blue[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isLargeScreen
              ? _buildLargeScreenLayout()
              : _buildSmallScreenLayout(),
      floatingActionButton:
          (!_isLargeScreen && _selectedChatId != null) || _isLoading
              ? null
              : FloatingActionButton(
                  backgroundColor: Colors.blue[700],
                  onPressed: () => _createNewChat(context),
                  child: const Icon(FontAwesome.pencil),
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
                prefixIcon: const Icon(FontAwesome.search),
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
                        Icon(
                          FontAwesome.comments_o,
                          size: 70,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          icon: const Icon(FontAwesome.user_md),
                          label: const Text('Message Your Doctor'),
                          onPressed: () => _createNewChat(context),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _recentChats.length,
                    itemBuilder: (context, index) {
                      var chat = _recentChats[index];
                      bool isSelected = _selectedChatId == chat['chatId'];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        elevation: isSelected ? 2 : 0,
                        color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue[700],
                                radius: 24,
                                child: const Icon(
                                  FontAwesome.user_md,
                                  color: Colors.white,
                                  size: 16,
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
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    child: Text(
                                      chat['unreadCount'].toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
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
                                  : FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (chat['specialty']?.isNotEmpty == true) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      FontAwesome.stethoscope,
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
                              ],
                              const SizedBox(height: 4),
                              Text(
                                chat['lastMessage'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: chat['unreadCount'] > 0
                                      ? Colors.black87
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTimestamp(chat['lastUpdated']),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Icon(
                                FontAwesome.chevron_right,
                                size: 14,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                          onTap: () => _selectChat(
                            chat['chatId'],
                            chat['participantId'],
                            chat['participantName'],
                          ),
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
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesome.comments_o,
              size: 70,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Select a conversation to start chatting',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // Chat messages widget (right side on large screens, full screen on small screens when a chat is selected)
  Widget _buildChatMessages() {
    return Column(
      children: [
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
                      Icon(
                        FontAwesome.comments_o,
                        size: 70,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var messageDoc = snapshot.data!.docs[index];
                  var messageData = messageDoc.data() as Map<String, dynamic>;
                  bool isSentByCurrentUser =
                      messageData['senderId'] == _currentUserId;

                  return Align(
                    alignment: isSentByCurrentUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSentByCurrentUser
                            ? Colors.blue[700]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            messageData['text'] ?? '',
                            style: TextStyle(
                              color: isSentByCurrentUser
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTimestamp(messageData['timestamp']),
                            style: TextStyle(
                              color: isSentByCurrentUser
                                  ? Colors.white70
                                  : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                onPressed: _sendMessage,
                backgroundColor: Colors.blue[700],
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(dynamic timestampData) {
    if (timestampData == null) {
      return 'Now';
    }

    try {
      // Ensure we're working with a Timestamp
      Timestamp timestamp;
      if (timestampData is Timestamp) {
        timestamp = timestampData;
      } else {
        // If it's not a timestamp but can be parsed as one (e.g., map)
        return 'Now';
      }

      DateTime dateTime = timestamp.toDate();
      DateTime now = DateTime.now();

      if (dateTime.year == now.year &&
          dateTime.month == now.month &&
          dateTime.day == now.day) {
        return DateFormat('h:mm a').format(dateTime);
      } else if (dateTime.year == now.year) {
        return DateFormat('MMM d').format(dateTime);
      } else {
        return DateFormat('MMM d, y').format(dateTime);
      }
    } catch (e) {
      print('Error formatting timestamp: $e');
      return 'Now';
    }
  }
}
