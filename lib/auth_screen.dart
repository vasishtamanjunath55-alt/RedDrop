import 'package:flutter/material.dart';

import 'app_state.dart';
import 'models.dart';
import 'widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  bool isLogin = true;
  bool hide = true;
  bool busy = false;
  String city = cities.first;
  String group = 'O+';
  String role = 'both';
  String? error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final String? err;
    if (isLogin) {
      err = await app.login(_email.text, _password.text);
    } else {
      err = await app.register(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        phone: _phone.text,
        city: city,
        bloodGroup: group,
        role: role,
      );
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kRed, kDarkRed],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.water_drop, size: 64, color: Colors.white),
                  SizedBox(height: 8),
                  Text('RedDrop',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Every drop can save a life',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Login')),
                        ButtonSegment(value: false, label: Text('Sign up')),
                      ],
                      selected: {isLogin},
                      onSelectionChanged: (s) => setState(() {
                        isLogin = s.first;
                        error = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    if (!isLogin) ...[
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder()),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: hide,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                              hide ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => hide = !hide),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'At least 6 characters'
                          : null,
                    ),
                    if (!isLogin) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                            labelText: 'Phone number',
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder()),
                        validator: (v) => (v == null ||
                                v.replaceAll(RegExp(r'[^0-9]'), '').length < 10)
                            ? 'Enter a 10 digit number'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Pick(
                                label: 'Blood group',
                                value: group,
                                items: bloodGroups,
                                onChanged: (v) => setState(() => group = v)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Pick(
                                label: 'City',
                                value: city,
                                items: cities,
                                onChanged: (v) => setState(() => city = v)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('I want to'),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'donor', label: Text('Donate')),
                          ButtonSegment(
                              value: 'requester', label: Text('Request')),
                          ButtonSegment(value: 'both', label: Text('Both')),
                        ],
                        selected: {role},
                        onSelectionChanged: (s) =>
                            setState(() => role = s.first),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: kRed)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: busy ? null : _submit,
                      style: FilledButton.styleFrom(
                          backgroundColor: kRed,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isLogin ? 'Login' : 'Create account'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isLogin
                          ? 'New here? Switch to Sign up to create your account.'
                          : 'Your phone number is shown to people you are matched with.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
