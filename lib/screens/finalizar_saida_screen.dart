import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show File, Platform;
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../sync_helper.dart';
import 'custom_app_bar.dart';
import 'home_screen.dart';

class FinalizarSaidaScreen extends StatefulWidget {
  final int idSaida;

  const FinalizarSaidaScreen({Key? key, required this.idSaida}) : super(key: key);

  @override
  _FinalizarSaidaScreenState createState() => _FinalizarSaidaScreenState();
}

class _FinalizarSaidaScreenState extends State<FinalizarSaidaScreen> {
  final _picker = ImagePicker();
  String? _sitLimpeza;
  File? _fotoFinal;
  String? _nomeEmpresa;
  String? _dhsCadastro;
  bool _isLoading = false;

  final List<String> _opcoesLimpeza = ['COMPLETA', 'INCOMPLETA'];

  @override
  void initState() {
    super.initState();
    _carregarDadosSaida();
  }

  Future<void> _carregarDadosSaida() async {
    final db = await DatabaseHelper.instance.database;
    final saidas = await db.query(
      'saidas_offline',
      where: 'id_saida = ?',
      whereArgs: [widget.idSaida],
    );

    if (saidas.isNotEmpty) {
      final saida = saidas.first;
      final idEmpresaSaida = saida['id_empresa_saida'] as int;
      final dhsCadastro = DateTime.parse(saida['dhs_cadastro'] as String);
      final formattedDate = DateFormat('dd/MM/yyyy HH:mm:ss').format(dhsCadastro);

      final empresas = await db.query(
        'empresas_saida_offline',
        where: 'id_empresa_saida = ?',
        whereArgs: [idEmpresaSaida],
      );

      setState(() {
        _dhsCadastro = formattedDate;
        if (empresas.isNotEmpty) {
          _nomeEmpresa = empresas[0]['nom_empresa'] as String;
        } else {
          _nomeEmpresa = 'Empresa não encontrada';
        }
      });
    } else {
      setState(() {
        _dhsCadastro = 'Data não encontrada';
        _nomeEmpresa = 'Empresa não encontrada';
      });
    }
  }

  Future<void> _tirarFoto() async {
    if (_fotoFinal != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Já existe uma foto final. Remova a atual para adicionar uma nova.')),
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
              _fotoFinal = File(pickedFile.path);
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
            _fotoFinal = File(result.files.single.path!);
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
      _fotoFinal = null;
    });
  }

  Future<void> _finalizarSaida() async {
    final db = await DatabaseHelper.instance.database;

    if (_sitLimpeza == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a situação da limpeza.')),
      );
      return;
    }

    if (_fotoFinal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('É necessário tirar uma foto final.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final updatedRows = await db.update(
        'saidas_offline',
        {
          'sit_saida': 2,
          'foto_final': _fotoFinal!.path,
          'sit_limpeza': _sitLimpeza,
          'dhs_atualizacao': now.toIso8601String(),
          'sincronizado': 0,
        },
        where: 'id_saida = ?',
        whereArgs: [widget.idSaida],
      );

      if (updatedRows > 0) {
        print('Saída ${widget.idSaida} atualizada com sucesso: sit_saida=2, foto_final=${_fotoFinal!.path}, sit_limpeza=$_sitLimpeza, dhs_atualizacao=${now.toIso8601String()}');
      } else {
        print('Erro: Nenhuma linha atualizada para id_saida=${widget.idSaida}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao finalizar saída. Tente novamente.')),
        );
        return;
      }

      final saidaAtualizada = await db.query(
        'saidas_offline',
        where: 'id_saida = ?',
        whereArgs: [widget.idSaida],
      );
      print('Saída após atualização no banco local: $saidaAtualizada');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saída finalizada com sucesso!')),
      );

      // Sincronizar saídas pendentes em background
      print('Iniciando sincronização de saídas pendentes em background após finalização...');
      SyncHelper.sincronizarSaidasPendentes().then((_) {
        print('Sincronização de saídas pendentes concluída após finalizar saída.');
      }).catchError((e) {
        print('Erro ao sincronizar saídas pendentes após finalizar saída: $e');
        // O SyncHelper já está configurado para tentar novamente quando houver conexão
      });

      // Redirecionar para a HomeScreen imediatamente
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao finalizar saída: $e')),
      );
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
    String tirarFotoTexto = Platform.isAndroid || Platform.isIOS ? 'Tirar Foto' : 'Selecionar Foto';

    return Stack(
      children: [
        Scaffold(
          appBar: CustomAppBar(
            showLogoutButton: true,
            onBackPressed: _isLoading
                ? null
                : () {
                    Navigator.pop(context);
                  },
          ),
          body: Padding(
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
                    const Text(
                      'Finalizar Saída dos Recicláveis',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Início da retirada:\nDia: ${_dhsCadastro ?? 'Carregando...'}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Responsável: ${_nomeEmpresa ?? 'Carregando...'}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Situação da Limpeza Após a Coleta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: _sitLimpeza,
                      hint: const Text('Selecione...'),
                      items: _opcoesLimpeza.map((opcao) {
                        return DropdownMenuItem<String>(
                          value: opcao,
                          child: Text(opcao),
                        );
                      }).toList(),
                      onChanged: _isLoading
                          ? null
                          : (String? newValue) {
                              setState(() => _sitLimpeza = newValue);
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
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.5,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _tirarFoto,
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
                    if (_fotoFinal != null) ...[
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
                                _fotoFinal!,
                                width: MediaQuery.of(context).size.width * 0.6,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _removerFoto,
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
                        onPressed: _isLoading ? null : _finalizarSaida,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Finalizar',
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
        if (_isLoading)
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
                    'Finalizando saída e sincronizando dados...\nVocê será redirecionado em breve.',
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