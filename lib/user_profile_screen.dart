import 'package:final_project_amona/post_card.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'auth_screen.dart';
import 'edit_profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoadingUserData = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (currentUser == null) {
      setState(() {
        _errorMessage = "No user logged in.";
        _isLoadingUserData = false;
      });
      return;
    }

    try {
      // Listen to real-time updates for user data
      FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots().listen((userDoc) {
        if (mounted) { // Check if the widget is still in the widget tree
          if (userDoc.exists) {
            setState(() {
              _userData = userDoc.data();
              _isLoadingUserData = false;
            });
          } else {
            setState(() {
              _errorMessage = "User data not found in Firestore.";
              _isLoadingUserData = false;
            });
          }
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load user data: $e";
        _isLoadingUserData = false;
      });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // Navigate back to the AuthScreen after logout
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AuthScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoadingUserData
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : SingleChildScrollView(
        child: Column(
          children: [
            // User Profile Header (Enhanced Design)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Theme.of(context).primaryColor.withOpacity(0.8), Theme.of(context).primaryColor.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white.withOpacity(0.9),
                    backgroundImage: _userData?['profileImageUrl'] != null && _userData!['profileImageUrl'].isNotEmpty
                        ? NetworkImage(_userData!['profileImageUrl'])
                        : null,
                    child: (_userData?['profileImageUrl'] == null || _userData!['profileImageUrl'].isEmpty)
                        ? Icon(Icons.person, size: 70, color: Theme.of(context).primaryColor)
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _userData?['username'] ?? currentUser?.displayName ?? 'No Username',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userData?['email'] ?? currentUser?.email ?? 'No Email',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_userData?['firstName'] != null && _userData?['lastName'] != null &&
                      _userData!['firstName'].isNotEmpty && _userData!['lastName'].isNotEmpty)
                    Text(
                      '${_userData!['firstName']} ${_userData!['lastName']}',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  const SizedBox(height: 25),
                  // Button to navigate to EditProfileScreen
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Navigate to EditProfileScreen and wait for result
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(
                            initialUserData: _userData,
                          ),
                        ),
                      );
                      // If profile was updated, refresh user data
                      if (result == true) {
                        // _fetchUserData() is now listening to snapshots, so data will auto-refresh
                        // No explicit call needed unless you want to force a re-fetch.
                      }
                    },
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    label: const Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      elevation: 5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // User's Posts Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'My Posts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const Divider(thickness: 1, indent: 16, endIndent: 16),
            StreamBuilder<QuerySnapshot>(
              // Fetch only posts by the current user
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .where('userId', isEqualTo: currentUser?.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (ctx, AsyncSnapshot<QuerySnapshot> postsSnapshot) {
                if (postsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (postsSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text('Error loading posts: ${postsSnapshot.error}'),
                    ),
                  );
                }
                if (!postsSnapshot.hasData || postsSnapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'You haven\'t posted anything yet.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final loadedPosts = postsSnapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true, // Important for nested ListView
                  physics: const NeverScrollableScrollPhysics(), // Disable scrolling for nested ListView
                  itemCount: loadedPosts.length,
                  itemBuilder: (ctx, index) {
                    final postData = loadedPosts[index].data() as Map<String, dynamic>;
                    final postId = loadedPosts[index].id;

                    return Column(
                      children: [
                        PostCard(
                          postId: postId,
                          postData: postData,
                          currentUserId: currentUser?.uid,
                        ),
                        // Display comments directly under each post on profile page
                        _buildCommentsSection(postId),
                        const SizedBox(height: 20), // Space between posts and comments
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build comments section for a post on the profile page
  Widget _buildCommentsSection(String postId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comments:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .doc(postId)
                .collection('comments')
                .orderBy('createdAt', descending: false)
                .snapshots(),
            builder: (ctx, AsyncSnapshot<QuerySnapshot> commentsSnapshot) {
              if (commentsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (commentsSnapshot.hasError) {
                return Text('Error loading comments: ${commentsSnapshot.error}');
              }
              if (!commentsSnapshot.hasData || commentsSnapshot.data!.docs.isEmpty) {
                return const Text('No comments on this post yet.', style: TextStyle(color: Colors.grey));
              }

              final loadedComments = commentsSnapshot.data!.docs;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: loadedComments.length,
                itemBuilder: (ctx, index) {
                  final commentData = loadedComments[index].data() as Map<String, dynamic>;
                  final String username = commentData['username'] ?? 'Anonymous';
                  final String commentText = commentData['text'] ?? '';
                  final Timestamp? createdAt = commentData['createdAt'] as Timestamp?;

                  String formattedDate = '';
                  if (createdAt != null) {
                    formattedDate = DateFormat('MMM d,EEEE \'at\' h:mm a').format(createdAt.toDate());
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.blueGrey,
                          child: Icon(Icons.person, size: 14, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$username • $formattedDate',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Text(
                                commentText,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
