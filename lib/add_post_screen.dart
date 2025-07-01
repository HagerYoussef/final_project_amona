import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_screen.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _postTextController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _postTextController.dispose();
    super.dispose();
  }
  Future<void> _submitPost() async {
    final isValid = _formKey.currentState?.validate();
    FocusScope.of(context).unfocus();

    if (isValid == null || !isValid) {
      return;
    }

    _formKey.currentState?.save();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessageBox('Error', 'You must be logged in to create a post.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userData = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final username = userData.data()?['username'] ?? user.email?.split('@')[0] ?? 'Anonymous';
      final userEmail = user.email ?? 'No Email';

      await FirebaseFirestore.instance.collection('posts').add({
        'text': _postTextController.text.trim(),
        'imageUrl': null,
        'createdAt': Timestamp.now(),
        'userId': user.uid,
        'username': username,
        'userEmail': userEmail,
        'likes': 0,
        'likedBy': [],
        'commentCount': 0,
      });

      _showMessageBox('Success', 'Post created successfully!');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on FirebaseException catch (e) {
      _showMessageBox('Error', 'Failed to create post: ${e.message}');
    } catch (e) {
      _showMessageBox('Error', 'An unexpected error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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
        title: const Text('Create New Post'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _postTextController,
                decoration: const InputDecoration(
                  labelText: 'What\'s on your mind?',
                  hintText: 'Share your thoughts...',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.edit),
                ),
                maxLines: 5,
                maxLength: 500,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Post cannot be empty.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _submitPost,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('POST'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
