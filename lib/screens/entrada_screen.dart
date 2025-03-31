import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show File, Platform;
import 'package:http/http.dart' as http;
import 'dart:convert'; // Importa jsonEncode/jsonDecode
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path; // Adicionado para manipulação de caminhos
import '../database_helper.dart';
import '../sync_helper.dart';
import 'custom_app_bar.dart'; // Importa a CustomAppBar
import 'home_screen.dart'; // Importa a HomeScreen para navegação

class EntradaScreen extends StatefulWidget {
  const EntradaScreen({Key? key}) : super(key: key);

  @override
  _EntradaScreenState createState() => _EntradaScreenState();
}

class _EntradaScreenState extends State<EntradaScreen> {
  final _picker = ImagePicker();
  String? _placaVeiculo = '';
  bool _semPlaca = false;
  String _raOrigem = '';
  List<Map<String, dynamic>> _regioes = [];
  List<Map<String, dynamic>> _tiposResiduo = [];
  List<int> _tiposSelecionados = [];
  bool _alertaIrregularidade = false;
  int? _idTipoIrregularidade;
  File? _foto;
  int? _idUnidade;
  int? _idUsuario;
  String? _unidadeUsuario;

  final _placaController = TextEditingController();

  final List<Map<String, dynamic>> _tiposIrregularidade = [
    {'id': 1, 'descricao': 'Resíduos que não podem ser descartados nos PEVs'},
    {'id': 2, 'descricao': 'Resíduos com quantidades maiores que 1 metro cúbico por descarte'},
    {'id': 3, 'descricao': 'Descarte em grandes veículos (caminhões, carretas)'},
    {'id': 4, 'descricao': 'Outro'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _carregarRegioesLocal();
    _carregarTiposResiduoLocal();
    _carregarUnidadesLocal();
    _placaController.text = _placaVeiculo ?? '';
  }

  @override
  void dispose() {
    _placaController.dispose();
    super.dispose();
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

  Future<void> _carregarRegioesLocal() async {
    final db = await DatabaseHelper.instance.database;
    final regioes = await db.query('ra_offline');
    setState(() {
      _regioes = regioes;
      if (_regioes.isNotEmpty) _raOrigem = _regioes[0]['id_ra'].toString();
    });
  }

  Future<void> _carregarTiposResiduoLocal() async {
    final db = await DatabaseHelper.instance.database;
    final tipos = await db.query('tipos_residuo_offline');
    setState(() {
      _tiposResiduo = tipos;
    });
  }

  Future<void> _carregarUnidadesLocal() async {
    final db = await DatabaseHelper.instance.database;
    final unidades = await db.query('unidades', where: 'id_unidade = ?', whereArgs: [_idUnidade]);
    if (unidades.isNotEmpty) {
      setState(() {
        _raOrigem = unidades[0]['id_ra'].toString();
      });
    }
  }

  Future<void> _tirarFoto() async {
    if (_foto != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Já existe uma foto para esta entrada. Remova a atual para adicionar uma nova.')),
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
              _foto = File(pickedFile.path);
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
            _foto = File(result.files.single.path!);
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

  // Método para remover a foto
  void _removerFoto() {
    setState(() {
      _foto = null;
    });
  }

  Future<void> _salvarEntradaOffline() async {
    final db = await DatabaseHelper.instance.database;
    if (_idUnidade == null || _idUsuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário ou unidade não definidos.')),
      );
      return;
    }

    // Validar se a foto foi fornecida
    if (_foto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('É necessário tirar uma foto para registrar a entrada.')),
      );
      return;
    }

    final now = DateTime.now().toIso8601String();
    final idEntrada = await db.insert('entradas_offline', {
      'placa_veiculo': _semPlaca ? null : _placaVeiculo,
      'id_ra': _raOrigem,
      'id_unidade': _idUnidade!,
      'alerta_irregularidade': _alertaIrregularidade ? 1 : 0,
      'id_tipo_irregularidade': _idTipoIrregularidade,
      'id_usuario': _idUsuario!,
      'dhs_cadastro': now,
      'sincronizado': 0,
    });

    for (var idResiduo in _tiposSelecionados) {
      await db.insert('residuo_entrada_offline', {
        'id_entrada': idEntrada,
        'id_residuo': idResiduo,
        'dhs_cadastro': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      });
    }

    // Como a foto é obrigatória, não precisamos do if (_foto != null)
    final fileName = path.basename(_foto!.path);
    await db.insert('fotos_entrada_offline', {
      'nome_foto': fileName,
      'file_path': _foto!.path,
      'id_entrada': idEntrada,
      'dhs_cadastro': now,
      'sincronizado': 0,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrada salva offline!')),
    );
    setState(() {
      _placaVeiculo = '';
      _placaController.text = '';
      _semPlaca = false;
      _foto = null;
      _tiposSelecionados.clear();
      _alertaIrregularidade = false;
      _idTipoIrregularidade = null;
    });

    await SyncHelper.sincronizarDados();
  }

  String _normalizeText(String text) {
    return text
        .toUpperCase()
        .replaceAll('á', 'Á')
        .replaceAll('ã', 'Ã')
        .replaceAll('â', 'Â')
        .replaceAll('é', 'É')
        .replaceAll('ê', 'Ê')
        .replaceAll('í', 'Í')
        .replaceAll('ó', 'Ó')
        .replaceAll('ô', 'Ô')
        .replaceAll('õ', 'Õ')
        .replaceAll('ú', 'Ú')
        .replaceAll('ç', 'Ç');
  }

  @override
  Widget build(BuildContext context) {
    String tirarFotoTexto = Platform.isAndroid || Platform.isIOS ? 'Tirar Foto' : 'Selecionar Foto';

    return Scaffold(
      appBar: CustomAppBar(
        showLogoutButton: true, // Exibe o botão de logout
        onBackPressed: () {
          // Navega de volta para a HomeScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
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
                Text(
                  _unidadeUsuario != null ? 'Entradas - $_unidadeUsuario' : 'Entradas PEV',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tipo de Resíduo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Wrap(
                  children: _tiposResiduo.map((tipo) {
                    final idResiduo = tipo['id_residuo'] as int;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _tiposSelecionados.contains(idResiduo),
                          onChanged: (val) {
                            setState(() {
                              if (val!) _tiposSelecionados.add(idResiduo);
                              else _tiposSelecionados.remove(idResiduo);
                            });
                          },
                        ),
                        Text(tipo['nome_residuo']),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'RA Origem',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: _raOrigem.isNotEmpty ? _raOrigem : null,
                  hint: const Text('Selecione a RA'),
                  items: _regioes.map((regiao) {
                    return DropdownMenuItem<String>(
                      value: regiao['id_ra'].toString(),
                      child: Text(_normalizeText(regiao['nome_ra'] as String)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() => _raOrigem = newValue!);
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
                const Text(
                  'Placa Veículo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        enabled: !_semPlaca,
                        controller: _placaController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          hintText: 'Digite a Placa (ex.: ABC-1D23 ou ABC-1234)',
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
                        onChanged: (value) {
                          value = value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
                          value = value.toUpperCase();
                          if (value.length > 3) {
                            value = '${value.substring(0, 3)}-${value.substring(3, value.length > 7 ? 7 : value.length)}';
                          }
                          setState(() {
                            _placaVeiculo = value;
                            _placaController.value = _placaController.value.copyWith(
                              text: value,
                              selection: TextSelection.collapsed(offset: value.length),
                            );
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                    Switch(
                      value: _semPlaca,
                      onChanged: (val) {
                        setState(() {
                          _semPlaca = val;
                          if (val) {
                            _placaVeiculo = '';
                            _placaController.clear();
                          }
                        });
                      },
                    ),
                    const Text('Sem Placa'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Switch(
                      value: _alertaIrregularidade,
                      onChanged: (val) {
                        setState(() {
                          _alertaIrregularidade = val;
                          if (!val) _idTipoIrregularidade = null;
                        });
                      },
                      activeColor: const Color(0xFF1E3A8A),
                    ),
                    const Text(
                      'Irregularidade',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (_alertaIrregularidade) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Tipo de Irregularidade',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  DropdownButtonFormField<int>(
                    value: _idTipoIrregularidade,
                    hint: const Text('Selecione o tipo'),
                    items: _tiposIrregularidade.map((tipo) {
                      return DropdownMenuItem<int>(
                        value: tipo['id'] as int,
                        child: Text(tipo['descricao'] as String),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      setState(() {
                        _idTipoIrregularidade = newValue;
                      });
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
                ],
                const SizedBox(height: 16),
                Center( // Centraliza o botão horizontalmente
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5, // 50% da largura da tela
                    child: ElevatedButton(
                      onPressed: _tirarFoto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16, // Aumenta o padding horizontal para evitar corte
                        ),
                      ),
                      child: Text(
                        tirarFotoTexto,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14, // Ajusta o tamanho da fonte para caber no botão
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                if (_foto != null) ...[
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
                            _foto!,
                            width: MediaQuery.of(context).size.width * 0.6, // 60% da largura da tela
                            height: 300, // Altura fixa para a prévia
                            fit: BoxFit.cover, // Ajusta a imagem para preencher o espaço
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _removerFoto,
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
                    onPressed: _salvarEntradaOffline,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Salvar',
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
    );
  }
}