import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;

  const CommentsScreen({super.key, required this.postId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _commentTextController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isSendingComment = false;

  @override
  void dispose() {
    _commentTextController.dispose();
    super.dispose();
  }

  // Function to show a custom message box
  void _showMessageBox(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('Okay'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          )
        ],
      ),
    );
  }

  Future<void> _addComment() async {
    final commentText = _commentTextController.text.trim();
    if (commentText.isEmpty) {
      _showMessageBox('Empty Comment', 'Please enter some text to comment.');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _showMessageBox('Login Required', 'You must be logged in to comment.');
      return;
    }

    setState(() {
      _isSendingComment = true;
    });

    try {
      // Get user details from Firestore for the comment
      final userData = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final username = userData.data()?['username'] ?? user.email?.split('@')[0] ?? 'Anonymous';

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'text': commentText,
        'createdAt': Timestamp.now(),
        'userId': user.uid,
        'username': username,
      });

      _commentTextController.clear(); // Clear the input field
      // No need to manually increment commentCount here, PostCard's listener will handle it.
    } on FirebaseException catch (e) {
      _showMessageBox('Error', 'Failed to add comment: ${e.message}');
    } catch (e) {
      _showMessageBox('Error', 'An unexpected error occurred: $e');
    } finally {
      setState(() {
        _isSendingComment = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('createdAt', descending: false) // Oldest comments first
                  .snapshots(),
              builder: (ctx, AsyncSnapshot<QuerySnapshot> commentsSnapshot) {
                if (commentsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (commentsSnapshot.hasError) {
                  return Center(child: Text('Error: ${commentsSnapshot.error}'));
                }
                if (!commentsSnapshot.hasData || commentsSnapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final loadedComments = commentsSnapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: loadedComments.length,
                  itemBuilder: (ctx, index) {
                    final commentData = loadedComments[index].data() as Map<String, dynamic>;
                    final String username = commentData['username'] ?? 'Anonymous';
                    final String commentText = commentData['text'] ?? '';
                    final Timestamp? createdAt = commentData['createdAt'] as Timestamp?;

                    String formattedDate = '';
                    if (createdAt != null) {
                      formattedDate = DateFormat('MMM d, yyyy \'at\' h:mm a').format(createdAt.toDate());
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Colors.blueGrey,
                                  child: Icon(Icons.person, size: 18, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              commentText,
                              style: const TextStyle(fontSize: 14),
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
          // Comment input area
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, -3), // changes position of shadow
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentTextController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    maxLines: null, // Allows multiline input
                    keyboardType: TextInputType.multiline,
                  ),
                ),
                const SizedBox(width: 8),
                _isSendingComment
                    ? const CircularProgressIndicator()
                    : IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
