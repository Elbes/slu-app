import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show File, Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../sync_helper.dart';
import 'custom_app_bar.dart';
import 'home_screen.dart';
import 'finalizar_saida_screen.dart';
import 'saida_intermediaria_screen.dart';

class SaidasScreen extends StatefulWidget {
  const SaidasScreen({Key? key}) : super(key: key);

  @override
  _SaidasScreenState createState() => _SaidasScreenState();
}

class _SaidasScreenState extends State<SaidasScreen> {
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _empresasSaida = [];
  String? _idEmpresaSaida;
  File? _fotoInicial;
  int? _idUnidade;
  int? _idUsuario;
  String? _unidadeUsuario;
  bool _isLoading = true;
  bool _isSaving = false; // Nova variável para controlar o estado de salvamento

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _carregarEmpresasSaidaLocal();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _idUnidade = prefs.getInt('id_unidade');
      _idUsuario = prefs.getInt('id_usuario');
    });
    await _carregarUnidadeUsuario();
  }

  Future<void> _carregarUnidadeUsuario() async {
    if (_idUnidade != null) {
      final db = await DatabaseHelper.instance.database;
      final unidades = await db.query('unidades', where: 'id_unidade = ?', whereArgs: [_idUnidade]);
      if (unidades.isNotEmpty) {
        setState(() {
          _unidadeUsuario = unidades[0]['nome'] as String;
        });
      }
    }
  }

  Future<void> _carregarEmpresasSaidaLocal() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final empresas = await db.query('empresas_saida_offline');
      print('Empresas carregadas do banco local: $empresas');
      setState(() {
        _empresasSaida = empresas;
        if (_empresasSaida.isNotEmpty) {
          _idEmpresaSaida = _empresasSaida[0]['id_empresa_saida'].toString();
        } else {
          _idEmpresaSaida = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar empresas: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _tirarFoto() async {
    if (_fotoInicial != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Já existe uma foto inicial. Remova a atual para adicionar uma nova.')),
      );
      return;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      PermissionStatus status = await Permission.camera.request();
      if (status.isGranted) {
        try {
          final pickedFile = await _picker.pickImage(source: ImageSource.camera);
          if (pickedFile != null) {
            setState(() {
              _fotoInicial = File(pickedFile.path);
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Nenhuma foto foi capturada.')),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao capturar foto: $e')),
          );
        }
      } else if (status.isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão para câmera negada.')),
        );
      } else if (status.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão permanentemente negada.')),
        );
        await openAppSettings();
      }
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
        if (result != null && result.files.single.path != null) {
          setState(() {
            _fotoInicial = File(result.files.single.path!);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum arquivo selecionado.')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar arquivo: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleção de fotos na web não suportada.')),
      );
    }
  }

  void _removerFoto() {
    setState(() {
      _fotoInicial = null;
    });
  }

  Future<void> _salvarSaidaOffline() async {
    final db = await DatabaseHelper.instance.database;
    if (_idUnidade == null || _idUsuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário ou unidade não definidos.')),
      );
      return;
    }

    if (_idEmpresaSaida == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma empresa de saída.')),
      );
      return;
    }

    if (_fotoInicial == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('É necessário tirar uma foto inicial.')),
      );
      return;
    }

    setState(() {
      _isSaving = true; // Ativar o estado de salvamento
    });

    try {
      final now = DateTime.now();
      final dataFormatada = DateFormat('dd/MM/yyyy').format(now);
      final horaFormatada = DateFormat('HH:mm:ss').format(now);
      final empresaSelecionada = _empresasSaida.firstWhere((empresa) => empresa['id_empresa_saida'].toString() == _idEmpresaSaida)['nom_empresa'] as String;

      final dadosSaida = {
        'id_empresa_saida': int.parse(_idEmpresaSaida!),
        'id_unidade': _idUnidade!,
        'sit_saida': 1, // Iniciada
        'foto_inicial': _fotoInicial!.path,
        'foto_final': null,
        'sit_limpeza': null,
        'id_usuario': _idUsuario!,
        'dhs_cadastro': now.toIso8601String(),
        'sincronizado': 0,
      };

      print('Salvando saída com os dados: $dadosSaida'); // Log para depuração

      final result = await db.insert('saidas_offline', dadosSaida);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saída iniciada com sucesso!')),
      );

      setState(() {
        _idEmpresaSaida = _empresasSaida.isNotEmpty ? _empresasSaida[0]['id_empresa_saida'].toString() : null;
        _fotoInicial = null;
      });

      // Sincronizar dados em background
      SyncHelper.sincronizarDados().timeout(const Duration(seconds: 30), onTimeout: () {
        print('Sincronização atingiu o timeout de 30 segundos. Continuando em background...');
        return;
      }).then((_) {
        print('Sincronização concluída após registrar saída inicial.');
      }).catchError((e) {
        print('Erro ao sincronizar após registrar saída inicial: $e');
      });

      // Redirecionar para a tela intermediária
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SaidaIntermediariaScreen(
            idSaida: result,
            data: dataFormatada,
            hora: horaFormatada,
            empresa: empresaSelecionada,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao registrar saída: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false; // Desativar o estado de salvamento
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Construindo SaidasScreen - _empresasSaida: $_empresasSaida, _idEmpresaSaida: $_idEmpresaSaida, _isLoading: $_isLoading');
    String tirarFotoTexto = Platform.isAndroid || Platform.isIOS ? 'Tirar Foto' : 'Selecionar Foto';

    return Stack(
      children: [
        Scaffold(
          appBar: CustomAppBar(
            showLogoutButton: true,
            onBackPressed: _isSaving
                ? null // Desabilitar o botão de voltar durante o salvamento
                : () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Container(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _unidadeUsuario != null ? 'Saídas - $_unidadeUsuario' : 'Saídas PEV',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Quem está realizando a coleta',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          _empresasSaida.isNotEmpty
                              ? DropdownButtonFormField<String>(
                                  value: _idEmpresaSaida,
                                  hint: const Text('Selecione a empresa'),
                                  items: _empresasSaida.map((empresa) {
                                    return DropdownMenuItem<String>(
                                      value: empresa['id_empresa_saida'].toString(),
                                      child: Text(empresa['nom_empresa'] as String),
                                    );
                                  }).toList(),
                                  onChanged: _isSaving
                                      ? null // Desabilitar o dropdown durante o salvamento
                                      : (String? newValue) {
                                          setState(() => _idEmpresaSaida = newValue);
                                        },
                                  decoration: InputDecoration(
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
                                )
                              : const Text(
                                  'Nenhuma empresa de saída disponível.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.red,
                                  ),
                                ),
                          const SizedBox(height: 16),
                          Center(
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.5,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _tirarFoto, // Desabilitar o botão durante o salvamento
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade700,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                ),
                                child: Text(
                                  tirarFotoTexto,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          if (_fotoInicial != null) ...[
                            const SizedBox(height: 16),
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: Image.file(
                                      _fotoInicial!,
                                      width: MediaQuery.of(context).size.width * 0.6,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: _isSaving ? null : _removerFoto, // Desabilitar o botão durante o salvamento
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 16,
                                      ),
                                    ),
                                    child: const Text(
                                      'Remover Foto',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _salvarSaidaOffline, // Desabilitar o botão durante o salvamento
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text(
                                'Registrar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
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
        if (_isSaving) // Exibir o overlay de loading durante o salvamento
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Registrando saída inicial...\nVocê será redirecionado em breve.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}