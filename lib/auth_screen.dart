import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  String _email = '';
  // Use TextEditingControllers for password fields for real-time validation
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  String _username = '';
  String _firstName = '';
  String _lastName = '';
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Function to show a custom message box instead of alert()
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

  Future<void> _submitAuthForm() async {
    final isValid = _formKey.currentState?.validate();
    FocusScope.of(context).unfocus(); // Close keyboard

    if (isValid == null || !isValid) {
      return;
    }

    _formKey.currentState?.save(); // Save the form fields for email and other registration fields

    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous errors
    });

    try {
      if (_isLogin) {
        // Login Logic
        await _auth.signInWithEmailAndPassword(
          email: _email,
          password: _passwordController.text, // Use controller text
        );
      } else {
        // Registration Logic
        if (_passwordController.text != _confirmPasswordController.text) {
          setState(() {
            _errorMessage = 'Passwords do not match.';
            _isLoading = false;
          });
          return;
        }

        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _passwordController.text, // Use controller text
        );

        // Store additional user data in Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'username': _username,
          'email': _email,
          'firstName': _firstName,
          'lastName': _lastName,
          'createdAt': Timestamp.now(),
          'profileImageUrl': null, // Placeholder for profile picture
        });

        // Update user display name (optional but good for initial setup)
        await userCredential.user?.updateDisplayName(_username);
      }

      // If successful, navigate to HomeScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred, please check your credentials!';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
      } else if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided for that user.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      }
      setState(() {
        _errorMessage = message;
      });
      _showMessageBox('Authentication Error', message); // Show message box
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      _showMessageBox('Error', e.toString()); // Show message box
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true; // Show loading indicator
      _errorMessage = null; // Clear any previous error messages
    });

    try {
      // Initialize GoogleSignIn with the webClientId for web platforms.
      // You get this webClientId from your Firebase project settings -> Project settings -> General -> Your apps -> Web app.
      // It's usually found under 'Web API Key' or 'Web client ID'
      // IMPORTANT: Replace 'YOUR_WEB_CLIENT_ID_HERE' with your actual Web client ID.
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: '1:590116494094:web:01231cc9d7f00f6149555f', // <--- ADD THIS LINE FOR WEB
      );

      // 1. Begin the interactive Google Sign-In process.
      // This will open a browser or a system dialog for the user to choose their Google account.
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn(); // Use the initialized instance

      // If googleUser is null, the user canceled the sign-in process.
      if (googleUser == null) {
        setState(() {
          _isLoading = false; // Hide loading indicator
        });
        return; // Exit the function
      }

      // 2. Obtain the authentication details (accessToken and idToken) from the Google Sign-In result.
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create a new Firebase credential using the Google ID Token and Access Token.
      // This credential will be used to sign in to Firebase.
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase Authentication with the Google credential.
      // This links the Google account to a Firebase user.
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // 5. Check if this is a new user signing in for the first time via Google.
      // If it's a new user, save their basic profile data to your Firestore 'users' collection.
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        final User? user = userCredential.user;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'username': user.displayName ?? user.email?.split('@')[0] ?? 'Google User',
            'email': user.email,
            'firstName': user.displayName?.split(' ').first ?? '',
            'lastName': user.displayName?.split(' ').last ?? '',
            'profileImageUrl': user.photoURL, // Save Google profile picture URL
            'createdAt': Timestamp.now(),
          });
        }
      }

      // 6. If the sign-in is successful, navigate the user to the HomeScreen.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      // Handle Firebase Authentication specific errors.
      String message = 'Google Sign-In failed: ${e.message}';
      if (e.code == 'account-exists-with-different-credential') {
        message = 'An account already exists with the same email address but different sign-in credentials. Please sign in using your existing method (e.g., Email/Password).';
      }
      setState(() {
        _errorMessage = message; // Set error message to display
      });
      _showMessageBox('Google Sign-In Error', message); // Show error in a dialog
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred during Google Sign-In: $e';
      });
      _showMessageBox('Error', 'An unexpected error occurred: $e'); // Show error in a dialog
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo/Icon
              Icon(
                Icons.connect_without_contact,
                size: 100,
                color: Colors.white.withOpacity(0.9),
              ),
              const SizedBox(height: 20),
              Text(
                _isLogin ? 'Welcome Back!' : 'Join SocialSphere',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              Card(
                margin: const EdgeInsets.all(8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          key: const ValueKey('email'),
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.email),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty || !value.contains('@')) {
                              return 'Please enter a valid email address.';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            _email = value!;
                          },
                        ),
                        const SizedBox(height: 12),
                        if (!_isLogin) ...[
                          // Registration fields (at least 5 inputs)
                          TextFormField(
                            key: const ValueKey('username'),
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty || value.length < 4) {
                                return 'Please enter at least 4 characters.';
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _username = value!;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey('firstName'),
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your first name.';
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _firstName = value!;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey('lastName'),
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your last name.';
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _lastName = value!;
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          key: const ValueKey('password'),
                          controller: _passwordController, // Assign controller
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty || value.length < 6) {
                              return 'Password must be at least 6 characters long.';
                            }
                            return null;
                          },
                          // No onSaved needed here as we use controller.text directly
                        ),
                        if (!_isLogin) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey('confirmPassword'),
                            controller: _confirmPasswordController, // Assign controller
                            decoration: const InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: Icon(Icons.lock_reset),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password.';
                              }
                              // Compare directly with the text from the password controller
                              if (value != _passwordController.text) {
                                return 'Passwords do not match.';
                              }
                              return null;
                            },
                            // No onSaved needed here as we use controller.text directly
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (_isLoading)
                          const CircularProgressIndicator()
                        else
                          ElevatedButton(
                            onPressed: _submitAuthForm,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50), // Full width button
                              backgroundColor: Theme.of(context).primaryColor, // Use primary color
                              foregroundColor: Colors.white,
                            ),
                            child: Text(_isLogin ? 'LOGIN' : 'SIGN UP'),
                          ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _errorMessage = null; // Clear error when toggling
                              // Clear password fields when toggling between login/register
                              _passwordController.clear();
                              _confirmPasswordController.clear();
                            });
                          },
                          child: Text(
                            _isLogin
                                ? 'Create new account'
                                : 'I already have an account',
                            style: TextStyle(color: Theme.of(context).primaryColor),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _signInWithGoogle, // This calls the Google Sign-In logic
                          icon: Image.network(
                            'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/2048px-Google_%22G%22_logo.svg.png',
                            height: 24,
                            width: 24,
                          ),
                          label: const Text('Sign in with Google'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.grey),
                            ),
                            elevation: 3,
                            shadowColor: Colors.grey.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
