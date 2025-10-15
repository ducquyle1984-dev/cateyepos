import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateye_pos/provider/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController(
    text: 'ducle84@gmail.com',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: 'Open4408',
  );

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Login failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Card(
                    elevation: 16,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    color: Colors.white.withOpacity(0.95),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 40.0,
                        horizontal: 32.0,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2575FC),
                                    Color(0xFF6A11CB),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: const Icon(
                                Icons.point_of_sale,
                                size: 56,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'POS Login',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2575FC),
                                  ),
                            ),
                            const SizedBox(height: 28),
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(
                                  Icons.email,
                                  color: Color(0xFF2575FC),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) =>
                                  value != null && value.contains('@')
                                  ? null
                                  : 'Enter a valid email',
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  FocusScope.of(context).nextFocus(),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(
                                  Icons.lock,
                                  color: Color(0xFF2575FC),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              obscureText: true,
                              validator: (value) =>
                                  value != null && value.length >= 6
                                  ? null
                                  : 'Password must be at least 6 characters',
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (_formKey.currentState!.validate() &&
                                    !authProvider.isLoading) {
                                  _login();
                                }
                              },
                            ),
                            const SizedBox(height: 28),
                            if (authProvider.error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Text(
                                  authProvider.error!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  backgroundColor: const Color(0xFF2575FC),
                                  elevation: 0,
                                ),
                                onPressed: authProvider.isLoading
                                    ? null
                                    : () {
                                        if (_formKey.currentState!.validate()) {
                                          _login();
                                        }
                                      },
                                child: authProvider.isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              ),
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
      },
    );
  }
}
