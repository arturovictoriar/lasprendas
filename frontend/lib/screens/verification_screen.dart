import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/auth_provider.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  final bool isResetPassword;

  const VerificationScreen({
    super.key, 
    required this.email, 
    this.isResetPassword = false
  });
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late Timer _timer;
  int _secondsRemaining = 600; // 10 minutes
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _codeController.dispose();
    super.dispose();
  }

  String get _timerText {
    final minutes = (_secondsRemaining / 60).floor();
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    if (widget.isResetPassword) {
      final success = await auth.validateResetCode(widget.email, _codeController.text);
      if (success && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(
              email: widget.email,
              code: _codeController.text,
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.lastError ?? 'Invalid or expired code')),
        );
      }
    } else {
      final success = await auth.verifyAccount(widget.email, _codeController.text);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account verified and logged in successfully!')),
        );
        // Al estar logueado, el main.dart detectará auth.isAuthenticated y nos llevará al Home.
        // Solo necesitamos cerrar esta pantalla.
        Navigator.pop(context);
      } else if (mounted) {
        setState(() => _failedAttempts++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_failedAttempts >= 3 
            ? 'Too many failed attempts. Please resend the code.' 
            : (auth.lastError ?? 'Verification failed'))),
        );
      }
    }
  }

  Future<void> _resend() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    final success = widget.isResetPassword 
      ? await auth.requestPasswordReset(widget.email)
      : await auth.resendVerificationCode(widget.email);
    
    if (success && mounted) {
      setState(() {
        _secondsRemaining = 600;
        _failedAttempts = 0;
      });
      _timer.cancel(); // Cancel current timer before starting new one
      _startTimer();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Code resent successfully!' : (auth.lastError ?? 'Failed to resend code'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'VERIFICATION',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter the code sent to\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 24),
                Text(
                  _timerText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _secondsRemaining < 60 ? Colors.redAccent : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _codeController,
                  style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enableInteractiveSelection: false, // Prevents RenderEditable crash on long press
                  decoration: InputDecoration(
                    counterText: '',
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Enter 6-digit code' : null,
                ),
                const SizedBox(height: 32),
                Consumer<AuthProvider>(
                  builder: (context, auth, _) => ElevatedButton(
                    onPressed: (auth.isLoading || _failedAttempts >= 3) ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: auth.isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Text(_failedAttempts >= 3 ? 'CODE INVALIDATED' : (widget.isResetPassword ? 'CONTINUE' : 'VERIFY')),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _secondsRemaining > 0 ? null : _resend,
                  child: Text(
                    _secondsRemaining > 0 
                      ? 'Resend available in $_timerText' 
                      : 'Resend Code',
                    style: TextStyle(
                      color: _secondsRemaining > 0 ? Colors.white24 : Colors.white70
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Sub-screen for Reset Password after code verification
class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String code;

  const ResetPasswordScreen({super.key, required this.email, required this.code});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late Timer _timer;
  int _secondsRemaining = 600; // Fresh 10 minutes after verification
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _timerText {
    final minutes = (_secondsRemaining / 60).floor();
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.resetPassword(widget.email, widget.code, _passwordController.text);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successful! Please login.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reset password.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'NEW PASSWORD',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                _timerText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _secondsRemaining < 60 ? Colors.redAccent : Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('New Password').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                textCapitalization: TextCapitalization.none,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Confirm Password').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70,
                    ),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                textCapitalization: TextCapitalization.none,
                validator: (v) => v!.isEmpty ? 'Confirm your password' : null,
              ),
              const SizedBox(height: 32),
              Consumer<AuthProvider>(
                builder: (context, auth, _) => ElevatedButton(
                  onPressed: auth.isLoading ? null : _reset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: auth.isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('RESET PASSWORD'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
