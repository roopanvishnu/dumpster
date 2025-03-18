import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'home_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;
  

  // Password visibility toggle
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
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

//   Future<void> _registerUser() async {
//   final String email = _emailController.text.trim();
//   final String password = _passwordController.text.trim();
//   final String name = _nameController.text.trim();
  
//   if (email.isEmpty || password.isEmpty || name.isEmpty) {
//     _showErrorDialog("All fields are required.");
//     return;
//   }

//   try {
//     setState(() {
//       _isLoading = true;
//     });

//     // Create user in Firebase Authentication
//     UserCredential userCredential = await FirebaseAuth.instance
//         .createUserWithEmailAndPassword(email: email, password: password);
    
//     User? user = userCredential.user;

//     if (user != null) {
//       // Store user details in Firestore
//       await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
//         "name": name,
//         "email": email,
//         "role": "General People", // Role from dropdown
//         // "role": "Corporation Official",
//         "createdAt": FieldValue.serverTimestamp(),
//       });

//       if (!mounted) return;
      
//       // Navigate to Home Page
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (context) => HomePage(username: email, role: "General People"),
//         ),
//       );
//     }
//   } on FirebaseAuthException catch (e) {
//     String errorMessage = "Registration failed";
//     if (e.code == 'email-already-in-use') {
//       errorMessage = "Email is already in use.";
//     } else if (e.code == 'weak-password') {
//       errorMessage = "Password should be at least 6 characters.";
//     } else if (e.code == 'invalid-email') {
//       errorMessage = "Invalid email address.";
//     } else if (e.message != null) {
//       errorMessage = e.message!;
//     }

//     _showErrorDialog(errorMessage);
//   } catch (e) {
//     _showErrorDialog("An error occurred: $e");
//   } finally {
//     if (mounted) {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
// }
Future<void> _registerUser() async {
  final String email = _emailController.text.trim();
  final String password = _passwordController.text.trim();
  final String name = _nameController.text.trim();
  final String address = _addressController.text.trim();
  final String pincode = _pincodeController.text.trim();
  
  if (email.isEmpty || password.isEmpty || name.isEmpty || address.isEmpty || pincode.isEmpty) {
    _showErrorDialog("All fields are required.");
    return;
  }

  try {
    setState(() {
      _isLoading = true;
    });

    // Create user in Firebase Authentication
    UserCredential userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    
    User? user = userCredential.user;

    if (user != null) {
      // Store user details in Firestore
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "name": name,
        "email": email,
        "address": address,
        "pincode": pincode,
        "role": "General People", // Role from dropdown
        // "role": "Corporation Official",
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      // Navigate to Home Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(username: email, role: "General People"),
        ),
      );
    }
  } on FirebaseAuthException catch (e) {
    String errorMessage = "Registration failed";
    if (e.code == 'email-already-in-use') {
      errorMessage = "Email is already in use.";
    } else if (e.code == 'weak-password') {
      errorMessage = "Password should be at least 6 characters.";
    } else if (e.code == 'invalid-email') {
      errorMessage = "Invalid email address.";
    } else if (e.message != null) {
      errorMessage = e.message!;
    }

    _showErrorDialog(errorMessage);
  } catch (e) {
    _showErrorDialog("An error occurred: $e");
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
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text(
          "Sign Up",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Create an Account",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: "Full Name",
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please enter your name";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: "Address",
                            prefixIcon: Icon(Icons.home),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please enter your address";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _pincodeController,
                          decoration: const InputDecoration(
                            labelText: "Pincode",
                            prefixIcon: Icon(Icons.pin_drop),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please enter your pincode";
                            }
                            // Basic validation for 6-digit pincode (for India)
                            if (value.length != 6 ||
                                int.tryParse(value) == null) {
                              return "Please enter a valid 6-digit pincode";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please enter your email";
                            }
                            // Basic email validation
                            final emailRegex = RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            );
                            if (!emailRegex.hasMatch(value)) {
                              return "Please enter a valid email address";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please enter a password";
                            }
                            if (value.length < 6) {
                              return "Password must be at least 6 characters";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: "Confirm Password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please confirm your password";
                            }
                            if (value != _passwordController.text) {
                              return "Passwords do not match";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _registerUser,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child:
                              _isLoading
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : const Text(
                                    "Sign Up",
                                    style: TextStyle(fontSize: 16),
                                  ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            );
                          },
                          child: const Text("Already have an account? Login"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
