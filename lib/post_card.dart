import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'commets_screen.dart';

class PostCard extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;
  final String? currentUserId;

  const PostCard({
    super.key,
    required this.postId,
    required this.postData,
    this.currentUserId,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late int _likesCount;
  late List<dynamic> _likedBy; // List of user UIDs who liked the post
  late int _commentCount;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.postData['likes'] ?? 0;
    _likedBy = widget.postData['likedBy'] ?? [];
    _commentCount = widget.postData['commentCount'] ?? 0;
    _fetchCommentCount(); // Fetch initial comment count
  }

  // Fetch comment count in real-time
  void _fetchCommentCount() {
    FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _commentCount = snapshot.docs.length;
        });
        // Optionally, update the main post document with the new comment count
        FirebaseFirestore.instance.collection('posts').doc(widget.postId).update({
          'commentCount': _commentCount,
        });
      }
    });
  }

  // Function to toggle like status
  Future<void> _toggleLike() async {
    if (widget.currentUserId == null) {
      _showMessageBox('Login Required', 'You need to be logged in to like posts.');
      return;
    }

    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);

    // Check if the current user has already liked the post
    final bool hasLiked = _likedBy.contains(widget.currentUserId);

    try {
      if (hasLiked) {
        // Unlike the post
        await postRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([widget.currentUserId]),
        });
        setState(() {
          _likesCount--;
          _likedBy.remove(widget.currentUserId);
        });
      } else {
        // Like the post
        await postRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([widget.currentUserId]),
        });
        setState(() {
          _likesCount++;
          _likedBy.add(widget.currentUserId);
        });
      }
    } catch (e) {
      _showMessageBox('Error', 'Failed to update like: $e');
    }
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

  @override
  Widget build(BuildContext context) {
    final String username = widget.postData['username'] ?? 'Anonymous';
    final String postText = widget.postData['text'] ?? '';
    final String? imageUrl = widget.postData['imageUrl'];
    final Timestamp? createdAt = widget.postData['createdAt'] as Timestamp?;

    // Format the timestamp
    String formattedDate = '';
    if (createdAt != null) {
      formattedDate = DateFormat('MMM d, yyyy \'at\' h:mm a').format(createdAt.toDate());
    }

    final bool isLiked = _likedBy.contains(widget.currentUserId);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info and Timestamp
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blueGrey,
                  child: Icon(Icons.person, color: Colors.white), // Placeholder for profile pic
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 0.5),
            // Post Text
            if (postText.isNotEmpty)
              Text(
                postText,
                style: const TextStyle(fontSize: 15),
              ),
            if (postText.isNotEmpty && imageUrl != null)
              const SizedBox(height: 10), // Space between text and image
            // Post Image
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 250,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 250,
                      color: Colors.grey.shade200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 250,
                      color: Colors.grey.shade200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 50, color: Colors.grey.shade500),
                            const SizedBox(height: 8),
                            Text(
                              'Could not load image',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const Divider(height: 20, thickness: 0.5),
            // Like and Comment Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Like Button
                TextButton.icon(
                  onPressed: _toggleLike,
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey.shade700,
                  ),
                  label: Text(
                    '$_likesCount Likes',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                // Comment Button
                TextButton.icon(
                  onPressed: () {
                    // Navigate to comments screen, passing the postId
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CommentsScreen(postId: widget.postId),
                      ),
                    );
                  },
                  icon: Icon(Icons.comment_outlined, color: Colors.grey.shade700),
                  label: Text(
                    '$_commentCount Comments',
                    style: TextStyle(color: Colors.grey.shade700),
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
