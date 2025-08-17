import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// This screen handles both Login and Sign Up.
class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen> {
  // State variables
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isPasswordVisible = false; // --- NEW: For password visibility toggle ---
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // This function is called when the user presses the main button.
  void _trySubmit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    // Hide keyboard
    FocusScope.of(context).unfocus();

    if (!isValid) {
      return;
    }
    _formKey.currentState!.save();

    setState(() { _isLoading = true; });

    try {
      if (_isLogin) {
        // If in login mode, sign the user in.
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // If in signup mode, create a new user.
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      // The AuthWrapper will handle navigation automatically.
    } on FirebaseAuthException catch (e) {
      // Guard against using context after the widget is disposed.
      if (!mounted) return;
      // --- MODIFIED: Show error in a themed SnackBar ---
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Authentication failed.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('An unexpected error occurred.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }

    if (mounted) {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- MODIFIED: Complete UI Overhaul ---
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400), // Constrain width for larger screens
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. App Icon/Logo
                    Icon(
                      Icons.child_care,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),

                    // 2. Title and Subtitle
                    Text(
                      _isLogin ? 'Welcome Back!' : 'Create Your Account',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin ? 'Log in to continue to Playgroup Pals.' : 'Get started with your classroom manager.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150)),
                    ),
                    const SizedBox(height: 40),

                    // 3. Email Field
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => (value == null || !value.contains('@')) ? 'Please enter a valid email.' : null,
                    ),
                    const SizedBox(height: 16),

                    // 4. Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        // --- NEW: Password visibility toggle ---
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) => (value == null || value.length < 6) ? 'Password must be at least 6 characters long.' : null,
                    ),
                    const SizedBox(height: 32),

                    // 5. Submit Button
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _trySubmit,
                            child: Text(_isLogin ? 'Login' : 'Create Account'),
                          ),
                    const SizedBox(height: 16),

                    // 6. Toggle Button
                    TextButton(
                      onPressed: () {
                        setState(() { _isLogin = !_isLogin; });
                      },
                      child: Text(
                        _isLogin ? 'Don\'t have an account? Sign Up' : 'Already have an account? Login',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
