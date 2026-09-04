import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  
  bool _carregando = false;
  bool _ocultarSenha = true;
  String? _erroMensagem;

  Future<void> _fazerLogin() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      setState(() => _erroMensagem = 'Preencha o e-mail e a senha.');
      return;
    }

    setState(() {
      _carregando = true;
      _erroMensagem = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
      
      if (mounted) {
        context.go('/');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _erroMensagem = 'E-mail ou senha incorretos.';
        } else if (e.code == 'invalid-email') {
          _erroMensagem = 'Formato de e-mail inválido.';
        } else {
          _erroMensagem = 'Erro de autenticação: ${e.message}';
        }
      });
    } catch (e) {
      setState(() => _erroMensagem = 'Ocorreu um erro inesperado.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.purple.shade800;
    final lightPurple = Colors.purple.shade50;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FA), // Fundo em tom suave roxo-cinza
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 3,
                shadowColor: Colors.purple.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.purple.shade100, width: 1),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ÍCONE E LOGO
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: lightPurple,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.water_drop, size: 40, color: primaryColor),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'BeautyConnect',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'BY STUDIO CONDEZA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // MENSAGEM DE ERRO
                      if (_erroMensagem != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            _erroMensagem!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // CAMPO E-MAIL
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'E-mail',
                          labelStyle: TextStyle(color: Colors.grey.shade700),
                          prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        onSubmitted: (_) => _fazerLogin(),
                      ),
                      const SizedBox(height: 16),

                      // CAMPO SENHA
                      TextField(
                        controller: _senhaController,
                        obscureText: _ocultarSenha,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          labelStyle: TextStyle(color: Colors.grey.shade700),
                          prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _ocultarSenha ? Icons.visibility : Icons.visibility_off,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        onSubmitted: (_) => _fazerLogin(),
                      ),
                      const SizedBox(height: 28),

                      // BOTÃO ENTRAR
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _carregando ? null : _fazerLogin,
                          child: _carregando
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text(
                                  'ENTRAR',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
    );
  }
}
