import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ChatPages extends StatefulWidget {
  final String currentUserId; // The logged-in user's ID
  final String receiverId; // The recipient's ID
  final String receiverName; // Name of the chat recipient

  const ChatPages({
    Key? key,
    required this.currentUserId,
    required this.receiverId,
    required this.receiverName,
  }) : super(key: key);

  @override
  _ChatPagesState createState() => _ChatPagesState();
}

class _ChatPagesState extends State<ChatPages> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  final DatabaseReference _messagesRef =
      FirebaseDatabase.instance.ref('messages');

  List<Map<dynamic, dynamic>> _messages = [];
  int _unseenMessagesCount = 0;

  @override
  void initState() {
    super.initState();
    _listenForMessages();
  }

  String getChatRoomId() {
    List<String> ids = [widget.currentUserId, widget.receiverId];
    ids.sort();
    return ids.join('_');
  }

  void _listenForMessages() {
    String chatRoomId = getChatRoomId();

    _messagesRef.child(chatRoomId).onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        List<Map<dynamic, dynamic>> tempMessages = [];

        int unseenCount = 0;

        data.forEach((key, value) {
          if (value is Map) {
            final message = Map<dynamic, dynamic>.from(value);
            message['key'] = key;

            if (message['receiverID'] == widget.currentUserId &&
                !(message['seen'] ?? false)) {
              unseenCount++;
            }

            tempMessages.add(message);
          }
        });

        setState(() {
          _messages = tempMessages;
          _messages.sort((a, b) => (a['timestamp'] ?? 0)
              .compareTo(b['timestamp'] ?? 0));
          _unseenMessagesCount = unseenCount;
        });

        _scrollToBottom();
        _markMessagesAsSeen();
      }
    });
  }

  void _sendMessage() {
    if (_controller.text.trim().isNotEmpty) {
      String chatRoomId = getChatRoomId();

      final newMessage = {
        'senderID': widget.currentUserId,
        'receiverID': widget.receiverId,
        'message': _controller.text.trim(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'text',
        'seen': false,
      };

      _messagesRef.child(chatRoomId).push().set(newMessage);
      _controller.clear();
      _scrollToBottom();
    }
  }

  Future<void> _sendImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      String chatRoomId = getChatRoomId();

      final String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final Reference storageRef =
          FirebaseStorage.instance.ref().child('chat_images').child(fileName);

      await storageRef.putFile(imageFile);
      final String downloadUrl = await storageRef.getDownloadURL();

      final newMessage = {
        'senderID': widget.currentUserId,
        'receiverID': widget.receiverId,
        'message': downloadUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'image',
        'seen': false,
      };

      _messagesRef.child(chatRoomId).push().set(newMessage);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _markMessagesAsSeen() {
    String chatRoomId = getChatRoomId();

    for (var message in _messages) {
      if (message['receiverID'] == widget.currentUserId &&
          !(message['seen'] ?? false)) {
        final messageKey = message['key'];
        if (messageKey != null) {
          _messagesRef
              .child(chatRoomId)
              .child(messageKey)
              .update({'seen': true});
        }
      }
    }
  }

  // Delete a specific message
  void _deleteMessage(String messageKey) {
    String chatRoomId = getChatRoomId();
    _messagesRef.child(chatRoomId).child(messageKey).remove();
  }

  // Delete all messages sent by the current user
  void _clearAllSentMessages() {
    String chatRoomId = getChatRoomId();
    for (var message in _messages) {
      if (message['senderID'] == widget.currentUserId) {
        final messageKey = message['key'];
        if (messageKey != null) {
          _messagesRef.child(chatRoomId).child(messageKey).remove();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat with ${widget.receiverName}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Unseen Messages: $_unseenMessagesCount',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Messages'),
                  content: const Text(
                      'Are you sure you want to clear all messages you sent?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        _clearAllSentMessages();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isSentByMe = message['senderID'] == widget.currentUserId;
                final messageType = message['type'] ?? 'text';

                return GestureDetector(
                  onLongPress: isSentByMe
                      ? () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Message'),
                              content: const Text(
                                  'Are you sure you want to delete this message?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _deleteMessage(message['key']);
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      : null,
                  child: Align(
                    alignment: isSentByMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            isSentByMe ? Colors.blueAccent : Colors.grey[300],
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: isSentByMe
                              ? const Radius.circular(12)
                              : const Radius.circular(0),
                          bottomRight: isSentByMe
                              ? const Radius.circular(0)
                              : const Radius.circular(12),
                        ),
                      ),
                      child: messageType == 'image'
                          ? Image.network(
                              message['message'],
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                            )
                          : Text(
                              message['message'] ?? '',
                              style: TextStyle(
                                color: isSentByMe
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image, color: Colors.blueAccent),
                  onPressed: _sendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Enter your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.blueAccent,
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
