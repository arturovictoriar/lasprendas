import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'verification_screen.dart';
import 'forgot_password_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _acceptedTerms = false;
  bool _obscurePassword = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    bool success;

    if (_isLogin) {
      success = await auth.login(_emailController.text, _passwordController.text);
    } else {
      success = await auth.register(
        _emailController.text,
        _passwordController.text,
        _nameController.text,
      );
      if (success && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationScreen(email: _emailController.text),
          ),
        );
        return;
      }
    }

    if (!success && mounted) {
      String message = _isLogin ? 'Login failed' : 'Registration failed';
      
      // Manejo específico para cuenta no verificada
      if (_isLogin && auth.lastError?.contains('Account not verified') == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationScreen(email: _emailController.text),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.lastError ?? message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background-lasprendas.png'),
              fit: BoxFit.cover,
              opacity: 0.7, // Add opacity to ensure form readability
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'LAS PRENDAS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 48),
                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Name'),
                            validator: (v) => v!.isEmpty ? 'Enter name' : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Email'),
                          keyboardType: TextInputType.emailAddress,
                          textCapitalization: TextCapitalization.none,
                          autofillHints: const [AutofillHints.email],
                          validator: (v) => v!.isEmpty ? 'Enter email' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Password').copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white70,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          textCapitalization: TextCapitalization.none,
                          autofillHints: const [AutofillHints.password],
                          validator: (v) => v!.isEmpty ? 'Enter password' : null,
                        ),
                        if (!_isLogin) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _acceptedTerms,
                                  activeColor: Colors.white,
                                  checkColor: Colors.black,
                                  side: const BorderSide(color: Colors.white24),
                                  onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                                    children: [
                                      const TextSpan(text: 'Acepto los '),
                                      TextSpan(
                                        text: 'Términos y Condiciones',
                                        style: const TextStyle(
                                          color: Colors.blueAccent,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                        recognizer: TapGestureRecognizer()..onTap = _showTermsModal,
                                      ),
                                      const TextSpan(
                                        text: ', autorizando el procesamiento de mis fotos mediante IA para generar imágenes derivadas y reconociendo el acceso administrativo a mi contenido para fines de soporte y mejora del servicio.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 32),
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) => ElevatedButton(
                            onPressed: auth.isLoading || (!_isLogin && !_acceptedTerms) ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: auth.isLoading
                                ? const CircularProgressIndicator(color: Colors.black)
                                : Text(_isLogin ? 'LOGIN' : 'REGISTER'),
                          ),
                        ),
                        if (_isLogin)
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                            ),
                            child: const Text('Forgot Password?', style: TextStyle(color: Colors.white70)),
                          ),
                        TextButton(
                          onPressed: () => setState(() {
                            _isLogin = !_isLogin;
                            _acceptedTerms = false;
                          }),
                          child: Text(
                            _isLogin ? 'Need an account? Register' : 'Have an account? Login',
                            style: const TextStyle(color: Colors.white70),
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
  }

  void _showTermsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'TÉRMINOS Y CONDICIONES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const Divider(color: Colors.white10, height: 24),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: const [
                  Text(
                    'Última actualización: 07 de febrero de 2026\n\n'
                    'Al crear una cuenta en la aplicación Las Prendas, usted (el "Usuario") acepta los siguientes términos:\n\n'
                    '1. NATURALEZA DEL SERVICIO\n'
                    'Las Prendas es una plataforma de probador virtual que permite a los usuarios subir imágenes de prendas de vestir y fotografías personales para visualizar combinaciones de ropa mediante procesamiento digital.\n\n'
                    '2. CONTENIDO GENERADO POR EL USUARIO\n'
                    'El Usuario es el único responsable de las imágenes, fotografías y cualquier material (el "Contenido") que suba a la plataforma. El Usuario garantiza que tiene los derechos legales sobre dicho contenido y que no infringe derechos de terceros ni contiene material ilegal u ofensivo.\n\n'
                    '3. ACCESO ADMINISTRATIVO Y PRIVACIDAD\n'
                    'El Usuario reconoce y acepta que los administradores de la plataforma tienen acceso total al Contenido subido y generado dentro de la aplicación. Este acceso se utiliza exclusivamente para: Mantenimiento técnico, soporte al Usuario, moderación de contenido y mejora de algoritmos.\n\n'
                    '4. PROCESAMIENTO DE IMÁGENES Y OBRAS DERIVADAS\n'
                    'Al usar Las Prendas, el Usuario otorga una licencia expresa a la plataforma para: Procesamiento mediante IA para analizar fotos subidas y creación de nuevas imágenes que resulten de la combinación del contenido del Usuario.\n\n'
                    '5. PROPIEDAD INTELECTUAL\n'
                    'El Usuario conserva la propiedad de sus fotos originales. Las Prendas otorga al Usuario una licencia de uso personal sobre las imágenes generadas dentro de la app.\n\n'
                    '6. USO ACEPTABLE\n'
                    'Queda terminantemente prohibido subir contenido que incluya desnudez, contenido sexual explícito, imágenes de terceros sin consentimiento o material que incite al odio.\n\n'
                    '7. LIMITACIÓN DE RESPONSABILIDAD\n'
                    'Las Prendas no se hace responsable por el uso indebido que terceros puedan hacer de las imágenes si el usuario decide compartirlas fuera de la aplicación.',
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.black.withOpacity(0.6),
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
