import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'theme.dart';

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
  //           builder: (context) => HomePage(username: name, role: "General People"),
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

    if (!(_formKey.currentState?.validate() ?? false)) {
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
            builder:
                (context) => HomePage(username: name, role: "General People"),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffix,
        ),
      ),
    );
  }

  Widget _groupLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create account")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Join Smart Citizen to report issues in your area and follow them until they are resolved.",
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _groupLabel("Personal details"),
                        _field(
                          controller: _nameController,
                          label: "Full name",
                          icon: Icons.person_outline,
                          validator:
                              (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? "Please enter your name"
                                      : null,
                        ),
                        _field(
                          controller: _addressController,
                          label: "Address",
                          icon: Icons.home_outlined,
                          validator:
                              (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? "Please enter your address"
                                      : null,
                        ),
                        _field(
                          controller: _pincodeController,
                          label: "Pincode",
                          icon: Icons.pin_drop_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return "Please enter your pincode";
                            }
                            if (v.length != 6 || int.tryParse(v) == null) {
                              return "Enter a valid 6-digit pincode";
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _groupLabel("Account"),
                        _field(
                          controller: _emailController,
                          label: "Email address",
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return "Please enter your email";
                            }
                            final re = RegExp(
                              r'^[\w\-.+]+@([\w-]+\.)+[\w-]{2,}$',
                            );
                            return re.hasMatch(v.trim())
                                ? null
                                : "Enter a valid email address";
                          },
                        ),
                        _field(
                          controller: _passwordController,
                          label: "Password",
                          icon: Icons.lock_outline,
                          obscure: _obscurePassword,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed:
                                () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return "Please enter a password";
                            }
                            return v.length < 6
                                ? "Password must be at least 6 characters"
                                : null;
                          },
                        ),
                        _field(
                          controller: _confirmPasswordController,
                          label: "Confirm password",
                          icon: Icons.lock_outline,
                          obscure: _obscureConfirmPassword,
                          suffix: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed:
                                () => setState(
                                  () =>
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                ),
                          ),
                          validator:
                              (v) =>
                                  v != _passwordController.text
                                      ? "Passwords do not match"
                                      : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _isLoading ? null : _registerUser,
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                          : const Text("Create account"),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed:
                      () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      ),
                  child: const Text("Already have an account? Sign in"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
