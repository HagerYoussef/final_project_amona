import 'package:final_project_amona/post_card.dart';
import 'package:final_project_amona/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_post_screen.dart';
import 'auth_screen.dart'; // Import UserProfileScreen

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the current authenticated user
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SocialSphere Feed'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Profile Button: Added to navigate to UserProfileScreen
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const UserProfileScreen()),
              );
            },
          ),
          // Logout Button
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
      body: StreamBuilder<QuerySnapshot>(
        // Listen to changes in the 'posts' collection, ordered by creation time
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true) // Newest posts first
            .snapshots(),
        builder: (ctx, AsyncSnapshot<QuerySnapshot> postsSnapshot) {
          if (postsSnapshot.connectionState == ConnectionState.waiting) {
            // Show a loading indicator while data is being fetched
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (postsSnapshot.hasError) {
            // Display an error message if something went wrong
            return Center(
              child: Text('Error: ${postsSnapshot.error}'),
            );
          }
          if (!postsSnapshot.hasData || postsSnapshot.data!.docs.isEmpty) {
            // Display a message if there are no posts yet
            return const Center(
              child: Text(
                'No posts yet! Be the first to share something.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            );
          }

          // If data is available, build a ListView of PostCards
          final loadedPosts = postsSnapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: loadedPosts.length,
            itemBuilder: (ctx, index) {
              final postData = loadedPosts[index].data() as Map<String, dynamic>;
              final postId = loadedPosts[index].id;

              // Pass post data and current user ID to PostCard
              return PostCard(
                postId: postId,
                postData: postData,
                currentUserId: currentUser?.uid,
              );
            },
          );
        },
      ),
      // Floating action button for creating new posts
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the AddPostScreen
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddPostScreen()),
          );
        },
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}