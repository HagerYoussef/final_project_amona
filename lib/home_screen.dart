import 'package:final_project_amona/post_card.dart';
import 'package:final_project_amona/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_post_screen.dart';
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false; // To control visibility of search bar

  @override
  void initState() {
    super.initState();
    // Listen for changes in the search input
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search posts or users...',
            hintStyle: TextStyle(color: Colors.black),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: Colors.black),
          ),
          style: const TextStyle(color: Colors.black, fontSize: 18),
          cursorColor: Colors.black,
        )
            : const Text('SocialSphere Feed'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Toggle Search Bar Visibility
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Close Search' : 'Search Posts',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear(); // Clear search text when closing
                  FocusScope.of(context).unfocus(); // Dismiss keyboard
                } else {
                  FocusScope.of(context).requestFocus(); // Request focus to open keyboard
                }
              });
            },
          ),
          // Profile Button
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
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AuthScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Conditionally build the query based on search input
        stream: _searchQuery.isEmpty
            ? FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots()
            : FirebaseFirestore.instance
            .collection('posts')
        // Search by 'text' field (prefix match)
            .where('text', isGreaterThanOrEqualTo: _searchQuery)
            .where('text', isLessThanOrEqualTo: _searchQuery + '\uf8ff')
        // Note: Firestore does not support OR queries directly across different fields
        // For comprehensive search, you'd combine results from multiple queries
        // or use a dedicated search service (e.g., Algolia, ElasticSearch).
        // For now, this will prioritize text search. If you need to search both
        // text and username, consider a combined field or client-side filtering
        // on a broader initial fetch (less efficient for large datasets).
            .orderBy('text', descending: true) // Must order by the field in where clause
            .snapshots(),
        builder: (ctx, AsyncSnapshot<QuerySnapshot> postsSnapshot) {
          if (postsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (postsSnapshot.hasError) {
            return Center(
              child: Text('Error: ${postsSnapshot.error}'),
            );
          }
          if (!postsSnapshot.hasData || postsSnapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                _searchQuery.isEmpty
                    ? 'No posts yet! Be the first to share something.'
                    : 'No posts found matching "$_searchQuery".',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            );
          }

          final loadedPosts = postsSnapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: loadedPosts.length,
            itemBuilder: (ctx, index) {
              final postData = loadedPosts[index].data() as Map<String, dynamic>;
              final postId = loadedPosts[index].id;

              return PostCard(
                postId: postId,
                postData: postData,
                currentUserId: currentUser?.uid,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
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