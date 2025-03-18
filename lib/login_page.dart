import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:garbage1/home_page.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'signupPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _selectedRole = "General People"; // Changed default role to General People
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Error"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  // Add Google Sign In method
  Future<void> _signInWithGoogle() async {
  try {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      print("Google Sign-In canceled by user");
      return;
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in with Firebase
    final UserCredential userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);

    final User? user = userCredential.user;

    if (user != null) {
      // Check if user exists in Firestore
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
          "name": user.displayName ?? "Google User",
          "email": user.email,
          "role": "General People",
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      final userData = (await FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .get())
          .data();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(
            username: user.email ?? "Google User",
            role: userData?["role"] ?? "General People",
          ),
        ),
      );
    }
  } catch (e) {
    print("Google Sign-In Error: $e");
    _showErrorDialog("Google Sign-In failed: $e");
  }
}


  // Modified login function to make it more robust
  Future<void> _login() async {
  final String username = _usernameController.text.trim();
  final String password = _passwordController.text.trim();

  if (username.isEmpty || password.isEmpty) {
    _showErrorDialog("Please enter a valid email and password.");
    return;
  }

  try {
    setState(() {
      _isLoading = true;
    });

    print("Attempting to login with Email: $username");

    final UserCredential userCredential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: username, password: password);

    final User? user = userCredential.user;

    if (user != null) {
      print("User authenticated: ${user.uid}");

      // Get user data from Firestore
      final DocumentSnapshot userDoc = 
          await FirebaseFirestore.instance.collection("users").doc(user.uid).get();

      if (!userDoc.exists) {
        print("Error: User document does not exist in Firestore.");
        _showErrorDialog("User data not found. Contact support.");
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) {
        print("Error: User data is null.");
        _showErrorDialog("User data is null. Contact support.");
        return;
      }

      final String? role = userData["role"] as String?;
      print("User role from Firestore: $role");

      if (role == null) {
        print("Error: Role is null in user data.");
        _showErrorDialog("Role information is missing. Contact support.");
        return;
      }

      if (!mounted) return;

      // Navigate to HomePage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(
            username: username,
            role: role,
          ),
        ),
      );
    }
  } on FirebaseAuthException catch (e) {
    print("FirebaseAuthException: ${e.code} - ${e.message}");
    String errorMessage = "Authentication failed";
    
    if (e.code == 'user-not-found') {
      errorMessage = "No user found with this email.";
    } else if (e.code == 'wrong-password') {
      errorMessage = "Wrong password provided.";
    } else if (e.code == 'invalid-email') {
      errorMessage = "The email address is not valid.";
    } else if (e.message != null) {
      errorMessage = e.message!;
    }

    _showErrorDialog(errorMessage);
  } catch (e) {
    print("Unexpected error occurred: $e");
    _showErrorDialog("An unexpected error occurred: $e");
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        title: const Text(
          "Login",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value!;
                    });
                  },
                  items: [
                    "Corporation Official",
                    "General People",
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  decoration: const InputDecoration(
                    labelText: "Role",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Login", style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),
                // Add Google Sign-In button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  
                  label: const Text(
                    "Sign in with Google",
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("New user?"),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpPage(),
                          ),
                        );
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}