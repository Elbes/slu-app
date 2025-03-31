import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';
import '../database_helper.dart';
import '../sync_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _empresasSaidas = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Carregar empresas do banco local antes de tentar sincronizar
      await _carregarEmpresasLocais();

      // Sincronizar todos os dados apenas na primeira inicialização ou se a tabela de empresas estiver vazia
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString('last_full_sync') ?? '';
      final db = await DatabaseHelper.instance.database;
      final empresasAtuais = await db.query('empresas_saida_offline');
      print('Empresas atualmente no banco local antes da sincronização: ${empresasAtuais.length}');

      if (lastSync.isEmpty || empresasAtuais.isEmpty) {
        print('Realizando sincronização completa... (lastSync: $lastSync, empresas no banco: ${empresasAtuais.length})');
        await SyncHelper.sincronizarDados();
        final now = DateTime.now().toIso8601String();
        await prefs.setString('last_full_sync', now);
        print('Sincronização completa realizada em $now.');
      } else {
        print('Sincronização completa já realizada em $lastSync. Pulando sincronização inicial.');
      }

      // Recarregar empresas após a sincronização para garantir que temos os dados mais recentes
      await _carregarEmpresasLocais();

      // Verificar se as empresas foram carregadas com sucesso
      if (_empresasSaidas.isEmpty) {
        setState(() {
          _errorMessage = 'Nenhuma empresa de saída disponível. Verifique sua conexão e tente novamente.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Falha ao sincronizar dados iniciais: $e. Verifique sua conexão e tente novamente.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _carregarEmpresasLocais() async {
    final db = await DatabaseHelper.instance.database;
    final empresas = await db.query('empresas_saida_offline');
    setState(() {
      _empresasSaidas = empresas;
    });
    print('Empresas carregadas do banco local: $_empresasSaidas');
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Por favor, preencha todos os campos.';
      });
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'users',
        where: 'dsc_email = ?',
        whereArgs: [email],
      );

      if (result.isEmpty) {
        setState(() {
          _errorMessage = 'Email não encontrado.';
        });
        return;
      }

      final user = result.first;
      final storedPassword = user['pws_senha'] as String?;

      if (storedPassword == null) {
        setState(() {
          _errorMessage = 'Erro: Senha não encontrada no banco de dados.';
        });
        return;
      }

      if (!BCrypt.checkpw(password, storedPassword)) {
        setState(() {
          _errorMessage = 'Senha inválida.';
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('id_usuario', user['id_usuario'] as int);
      await prefs.setInt('id_unidade', user['id_unidade'] as int);
      await prefs.setInt('id_perfil', user['id_perfil'] as int);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erro ao realizar login: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo do SLU
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Image.asset(
                  'assets/slu_logo.png',
                  height: 100,
                ),
              ),
              Container(
                width: 300,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Senha',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE3342F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                            : const Text(
                                'Login',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}