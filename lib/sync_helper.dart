import 'dart:async'; // Adicionado para StreamSubscription
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:html';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'database_helper.dart';

class SyncHelper {
  static const String baseUrl = 'https://papaentulho.slu.df.gov.br'; // Ajuste para a porta correta do servidor Laravel
  static bool _isFullSyncRunning = false; // Flag para sincronização completa
  static bool _isEntrySyncRunning = false; // Flag para sincronização de entradas
  static bool _isSaidaSyncRunning = false; // Flag para sincronização de saídas
  static Connectivity _connectivity = Connectivity();
  static bool _isMonitoringConnectivity = false;
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Inicializar o monitoramento de conectividade
  static void startConnectivityMonitoring() {
    if (_isMonitoringConnectivity) return;
    _isMonitoringConnectivity = true;

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      print('Conectividade alterada: $results');
      if (!results.contains(ConnectivityResult.none)) {
        print('Conexão restabelecida. Iniciando sincronização de entradas e saídas pendentes...');
        await sincronizarEntradasPendentes();
        await sincronizarSaidasPendentes();
      } else {
        print('Conexão perdida. Sincronização será adiada até a conexão ser restabelecida.');
      }
    });
  }

  // Parar o monitoramento de conectividade
  static Future<void> stopConnectivityMonitoring() async {
    if (_isMonitoringConnectivity) {
      await _connectivitySubscription?.cancel();
      _connectivitySubscription = null;
      _isMonitoringConnectivity = false;
      print('Monitoramento de conectividade parado.');
    }

    // Aguardar a conclusão de qualquer sincronização em andamento
    while (_isFullSyncRunning || _isEntrySyncRunning || _isSaidaSyncRunning) {
      print('Aguardando conclusão das sincronizações em andamento...');
      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  static Future<void> sincronizarDados({bool forceFullSync = false}) async {
    if (_isFullSyncRunning) {
      print('Sincronização completa já em andamento. Aguardando conclusão...');
      return;
    }

    _isFullSyncRunning = true;
    try {
      var connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        print('Sem conexão com a internet. Sincronização completa adiada.');
        return; // Continua em modo offline
      }

      final db = await DatabaseHelper.instance.database;
      final prefs = await SharedPreferences.getInstance();

      // Verificar se é o primeiro acesso ou se foi solicitado um sincronismo completo
      final lastFullSync = prefs.getString('last_full_sync') ?? '';
      if (forceFullSync || lastFullSync.isEmpty) {
        print('Realizando sincronização completa... (forceFullSync: $forceFullSync, lastFullSync: $lastFullSync)');

        // Sincronizar RAs
        try {
          await _sincronizarRA();
        } catch (e) {
          print('Falha ao sincronizar RAs: $e. Continuando com dados locais...');
        }

        // Sincronizar Tipos de Resíduos
        try {
          await _sincronizarTiposResiduo();
        } catch (e) {
          print('Falha ao sincronizar Tipos de Resíduos: $e. Continuando com dados locais...');
        }

        // Sincronizar EmpresasSaidas
        print('Sincronizando EmpresasSaidas...');
        try {
          final response = await http.get(
            Uri.parse('$baseUrl/api/empresas-saida'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 30));

          print('Resposta da API /empresas-saida: Status ${response.statusCode}');
          if (response.statusCode == 200) {
            final List<dynamic> empresas = jsonDecode(response.body);
            print('Dados recebidos do servidor: $empresas');

            if (empresas.isEmpty) {
              print('Aviso: Nenhuma empresa retornada pela API. Verifique o servidor.');
            } else {
              await db.delete('empresas_saida_offline');
              for (var empresa in empresas) {
                await db.insert('empresas_saida_offline', {
                  'id_empresa_saida': empresa['id_empresa_saida'],
                  'nom_empresa': empresa['nom_empresa'],
                  'dsc_empresa': empresa['dsc_empresa'],
                  'dhs_cadastro': empresa['dhs_cadastro'],
                  'dhs_atualizacao': empresa['dhs_atualizacao'],
                  'dhs_exclusao': empresa['dhs_exclusao'],
                });
              }
              print('EmpresasSaidas sincronizadas com sucesso! Total de empresas: ${empresas.length}');
            }
          } else {
            print('Erro ao sincronizar EmpresasSaidas: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          print('Falha ao sincronizar EmpresasSaidas: $e. Continuando com dados locais...');
        }

        // Sincronizar Usuários (apenas id_perfil = 2)
        try {
          final response = await http.get(
            Uri.parse('$baseUrl/api/users'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 30));
          if (response.statusCode == 200) {
            final List<dynamic> users = jsonDecode(response.body);
            final filteredUsers = users.where((user) => user['id_perfil'] == 2).toList();
            await db.delete('users', where: 'id_usuario != ?', whereArgs: [1]);
            for (var user in filteredUsers) {
              print('Sincronizando usuário ${user['id_usuario']}: num_cpf = ${user['num_cpf']}');
              await db.insert('users', {
                'id_usuario': user['id_usuario'],
                'nom_usuario': user['nom_usuario'],
                'num_cpf': user['num_cpf'] ?? '',
                'dat_nascimento': user['dat_nascimento'],
                'id_unidade': user['id_unidade'],
                'id_perfil': user['id_perfil'],
                'dsc_email': user['dsc_email'],
                'pws_senha': user['pws_senha'],
                'dhs_cadastro': user['dhs_cadastro'],
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            print('Usuários sincronizados com sucesso. Total de usuários: ${filteredUsers.length}');
          } else {
            print('Erro ao sincronizar usuários: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          print('Falha ao sincronizar usuários: $e. Continuando com dados locais...');
        }

        // Sincronizar Unidades
        try {
          final response = await http.get(
            Uri.parse('$baseUrl/api/unidades'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 30));
          if (response.statusCode == 200) {
            final List<dynamic> unidades = jsonDecode(response.body);
            await db.delete('unidades');
            for (var unidade in unidades) {
              await db.insert('unidades', {
                'id_unidade': unidade['id_unidade'],
                'nome': unidade['nome'],
                'id_ra': unidade['id_ra'],
                'endereco': unidade['endereco'],
                'dhs_cadastro': unidade['dhs_cadastro'],
                'dhs_atualizacao': unidade['dhs_atualizacao'],
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            print('Unidades sincronizadas com sucesso. Total de unidades: ${unidades.length}');
          } else {
            print('Erro ao sincronizar unidades: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          print('Falha ao sincronizar unidades: $e. Continuando com dados locais...');
        }

        // Atualizar o timestamp de sincronização completa
        final now = DateTime.now().toIso8601String();
        await prefs.setString('last_full_sync', now);
        print('Sincronização completa realizada em $now.');
      } else {
        print('Sincronização completa já realizada em $lastFullSync. Pulando sincronização de dados estáticos.');
      }

      // Sincronizar dados pendentes (entradas, resíduos, fotos, saídas)
      await sincronizarEntradasPendentes();
      await sincronizarSaidasPendentes();
    } catch (e) {
      print('Erro geral na sincronização completa: $e. Continuando em modo offline...');
    } finally {
      _isFullSyncRunning = false;
    }
  }

  static Future<void> sincronizarEntradasPendentes() async {
    if (_isEntrySyncRunning) {
      print('Sincronização de entradas já em andamento. Aguardando conclusão...');
      return;
    }

    _isEntrySyncRunning = true;
    try {
      var connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        print('Sem conexão com a internet. Sincronização de entradas adiada.');
        return;
      }

      final db = await DatabaseHelper.instance.database;

      // Sincronizar Entradas
      final entradasPendentes = await db.query(
        'entradas_offline',
        where: 'sincronizado = ?',
        whereArgs: [0],
      );
      print('Entradas pendentes para sincronizar: ${entradasPendentes.length}');
      if (entradasPendentes.isEmpty) {
        print('Nenhuma entrada pendente para sincronizar. Verifique a tabela entradas_offline.');
      }

      for (var entrada in entradasPendentes) {
        final idEntradaLocal = entrada['id_entrada'] as int;
        print('Sincronizando entrada $idEntradaLocal: ${entrada['placa_veiculo']}');
        print('Dados da entrada: $entrada');
        final requestBody = {
          'placa_veiculo': entrada['placa_veiculo'],
          'id_ra': entrada['id_ra'],
          'id_unidade': entrada['id_unidade'],
          'alerta_irregularidade': entrada['alerta_irregularidade'] == 1,
          'id_tipo_irregularidade': entrada['id_tipo_irregularidade'],
          'id_usuario': entrada['id_usuario'],
          'dhs_cadastro': entrada['dhs_cadastro'],
        };
        print('Enviando requisição para o servidor: ${jsonEncode(requestBody)}');
        final response = await http.post(
          Uri.parse('$baseUrl/api/entradas/sincronizar'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        ).timeout(const Duration(seconds: 30));

        print('Status Code (Entrada): ${response.statusCode}');
        print('Response (Entrada): ${response.body}');
        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = jsonDecode(response.body);
          final idEntradaServidor = responseData['id_entrada'] as int?;
          if (idEntradaServidor != null) {
            await db.update(
              'entradas_offline',
              {'sincronizado': 1, 'id_entrada_servidor': idEntradaServidor},
              where: 'id_entrada = ?',
              whereArgs: [idEntradaLocal],
            );
            print('Entrada $idEntradaLocal sincronizada com ID servidor: $idEntradaServidor');
          } else {
            print('Erro: API não retornou id_entrada na resposta: ${response.body}');
          }
        } else {
          print('Erro ao sincronizar entrada $idEntradaLocal: ${response.statusCode} - ${response.body}');
        }
      }

      // Sincronizar ResiduoEntrada
      final residuosPendentes = await db.query(
        'residuo_entrada_offline',
        where: 'sincronizado = ?',
        whereArgs: [0],
      );
      print('Resíduos pendentes para sincronizar: ${residuosPendentes.length}');

      for (var residuo in residuosPendentes) {
        final entrada = await db.query(
          'entradas_offline',
          where: 'id_entrada = ?',
          whereArgs: [residuo['id_entrada']],
        );
        if (entrada.isEmpty || entrada.first['id_entrada_servidor'] == null) {
          print('Resíduo ${residuo['id_residuo_entrada']} não sincronizado: entrada ${residuo['id_entrada']} não possui id_entrada_servidor');
          continue;
        }

        final idEntradaServidor = entrada.first['id_entrada_servidor'] as int;
        final response = await http.post(
          Uri.parse('$baseUrl/api/residuo-entrada/sincronizar'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'residuo_entradas': [{
              'id_entrada': idEntradaServidor,
              'id_residuo': residuo['id_residuo'],
              'dhs_cadastro': residuo['dhs_cadastro'],
            }]
          }),
        ).timeout(const Duration(seconds: 30));

        print('Status Code (Resíduo): ${response.statusCode}');
        print('Response (Resíduo): ${response.body}');
        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = jsonDecode(response.body);
          final idResiduoEntradaServidor = responseData['id_residuo_entrada'] as int?;
          if (idResiduoEntradaServidor != null) {
            await db.update(
              'residuo_entrada_offline',
              {'sincronizado': 1, 'id_residuo_entrada_servidor': idResiduoEntradaServidor},
              where: 'id_residuo_entrada = ?',
              whereArgs: [residuo['id_residuo_entrada']],
            );
            print('Resíduo sincronizado com ID servidor: $idResiduoEntradaServidor');
          } else {
            print('Erro: API não retornou id_residuo_entrada na resposta: ${response.body}');
          }
        } else {
          print('Erro ao sincronizar resíduo: ${response.statusCode} - ${response.body}');
        }
      }

      // Sincronizar Fotos
      Future<http.MultipartRequest> createMultipartRequest(String filePath, String fileName, int idEntradaServidor, String dhsCadastro) async {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/fotos/sincronizar'),
        );

        request.files.add(await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: fileName,
        ));

        request.fields['fotos'] = jsonEncode([{
          'nome_foto': fileName,
          'id_entrada': idEntradaServidor.toString(),
          'dhs_cadastro': dhsCadastro,
        }]);

        return request;
      }

      Future<http.StreamedResponse> sendWithRetry(String filePath, String fileName, int idEntradaServidor, String dhsCadastro, {int retries = 3, Duration delay = const Duration(seconds: 5)}) async {
        for (int attempt = 1; attempt <= retries; attempt++) {
          try {
            print('Tentativa $attempt de $retries para enviar a requisição');
            var request = await createMultipartRequest(filePath, fileName, idEntradaServidor, dhsCadastro);
            return await request.send().timeout(Duration(seconds: 120));
          } catch (e) {
            if (attempt == retries) rethrow;
            print('Erro na tentativa $attempt: $e. Tentando novamente em ${delay.inSeconds} segundos...');
            await Future.delayed(delay);
          }
        }
        throw Exception('Falha ao enviar a requisição após $retries tentativas');
      }

      final fotosPendentes = await db.query(
        'fotos_entrada_offline',
        where: 'sincronizado = ?',
        whereArgs: [0],
      );
      print('Fotos pendentes para sincronizar: ${fotosPendentes.length}');

      for (var foto in fotosPendentes) {
        final entrada = await db.query(
          'entradas_offline',
          where: 'id_entrada = ?',
          whereArgs: [foto['id_entrada']],
        );
        if (entrada.isEmpty || entrada.first['id_entrada_servidor'] == null) {
          print('Foto ${foto['id_foto']} não sincronizada: entrada ${foto['id_entrada']} não possui id_entrada_servidor');
          continue;
        }

        final idEntradaServidor = entrada.first['id_entrada_servidor'] as int;
        print('Sincronizando foto ${foto['id_foto']} para id_entrada_servidor: $idEntradaServidor');

        if (Platform.isAndroid || Platform.isIOS || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          File? tempFile;
          try {
            if (foto['file_path'] != null && File(foto['file_path'] as String).existsSync()) {
              final originalFile = File(foto['file_path'] as String);
              final image = img.decodeImage(originalFile.readAsBytesSync());
              if (image != null) {
                final resizedImage = img.copyResize(image, width: 800);
                final fileName = path.basename(foto['nome_foto'] as String? ?? 'foto.jpg');
                tempFile = File('${originalFile.parent.path}/temp_$fileName');
                tempFile.writeAsBytesSync(img.encodeJpg(resizedImage, quality: 85));

                final fileSizeInBytes = tempFile.lengthSync();
                final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
                print('Tamanho do arquivo redimensionado: ${fileSizeInMB.toStringAsFixed(2)} MB');

                print('Arquivo redimensionado e adicionado: ${tempFile.path} com nome $fileName');

                final response = await sendWithRetry(
                  tempFile.path,
                  fileName,
                  idEntradaServidor,
                  (foto['dhs_cadastro'] ?? DateTime.now().toIso8601String()).toString(),
                  retries: 3,
                  delay: Duration(seconds: 5),
                );
                final responseBody = await response.stream.bytesToString();
                print('Status Code (Foto): ${response.statusCode}');
                print('Response (Foto): $responseBody');
                if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 409) {
                  final responseData = jsonDecode(responseBody);
                  final idFotoServidor = responseData['id_foto'] as int?;
                  if (idFotoServidor != null) {
                    await db.update(
                      'fotos_entrada_offline',
                      {'sincronizado': 1},
                      where: 'id_foto = ?',
                      whereArgs: [foto['id_foto']],
                    );
                    print('Foto sincronizada com sucesso: ${foto['nome_foto']} (id_foto: $idFotoServidor)');
                  } else {
                    print('Erro: API não retornou id_foto na resposta: $responseBody');
                  }
                } else {
                  print('Erro na sincronização da foto: ${response.statusCode} - $responseBody');
                }
              } else {
                print('Erro ao decodificar a imagem para id_foto ${foto['id_foto']}');
                continue;
              }
            } else {
              print('Arquivo ${foto['file_path']} não encontrado ou inválido para id_foto ${foto['id_foto']}');
              continue;
            }
          } catch (e) {
            print('Exceção ao sincronizar foto ${foto['id_foto']}: $e');
          } finally {
            if (tempFile != null && tempFile.existsSync()) {
              tempFile.deleteSync();
              print('Arquivo temporário deletado: ${tempFile.path}');
            }
          }
        } else {
          print('Sincronização de fotos na web não implementada.');
        }
      }
    } catch (e) {
      print('Erro ao sincronizar entradas pendentes: $e');
    } finally {
      _isEntrySyncRunning = false;
    }
  }

  static Future<void> sincronizarSaidasPendentes() async {
    if (_isSaidaSyncRunning) {
      print('Sincronização de saídas já em andamento. Aguardando conclusão...');
      return;
    }

    _isSaidaSyncRunning = true;
    try {
      var connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        print('Sem conexão com a internet. Sincronização de saídas adiada.');
        return;
      }

      final db = await DatabaseHelper.instance.database;

      // Sincronizar Saídas Pendentes
      final saidasPendentes = await db.query(
        'saidas_offline',
        where: 'sincronizado = ?',
        whereArgs: [0],
      );
      print('Saídas pendentes para sincronizar: ${saidasPendentes.length}');
      if (saidasPendentes.isEmpty) {
        print('Nenhuma saída pendente para sincronizar. Verifique a tabela saidas_offline.');
        return;
      }

      for (var saida in saidasPendentes) {
        final idSaidaLocal = saida['id_saida'] as int;
        final idSaidaServidor = saida['id_saida_servidor'] as int?;
        final sitSaida = saida['sit_saida'] as int?;
        print('Sincronizando saída $idSaidaLocal (id_saida_servidor: $idSaidaServidor, sit_saida: $sitSaida)');

        // Usar POST em ambos os casos
        final isUpdate = idSaidaServidor != null && sitSaida == 2;
        print('Operação: ${isUpdate ? 'Atualização (POST)' : 'Criação (POST)'}');

        var request = http.MultipartRequest(
          'POST',
          Uri.parse(isUpdate
              ? '$baseUrl/api/saidas/sincronizar/$idSaidaServidor'
              : '$baseUrl/api/saidas/sincronizar'),
        );

        // Adicionar cabeçalhos
        request.headers['Content-Type'] = 'multipart/form-data';
        request.headers['Accept'] = 'application/json';

        // Lista para rastrear arquivos temporários
        List<String> tempFilePaths = [];

        // Função para redimensionar e adicionar foto à requisição
        Future<void> addPhotoToRequest(String? photoPath, String fieldName) async {
          if (photoPath != null && File(photoPath).existsSync()) {
            final originalFile = File(photoPath);
            final image = img.decodeImage(originalFile.readAsBytesSync());
            if (image != null) {
              final resizedImage = img.copyResize(image, width: 800);
              final fileName = path.basename(photoPath);
              final tempFile = File('${originalFile.parent.path}/temp_$fileName');
              tempFile.writeAsBytesSync(img.encodeJpg(resizedImage, quality: 85));

              final fileSizeInBytes = tempFile.lengthSync();
              final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
              print('Tamanho do arquivo $fieldName redimensionado: ${fileSizeInMB.toStringAsFixed(2)} MB');

              request.files.add(await http.MultipartFile.fromPath(
                fieldName,
                tempFile.path,
                filename: fileName,
              ));
              tempFilePaths.add(tempFile.path);
              print('Arquivo $fieldName adicionado à requisição: ${tempFile.path}');
            } else {
              print('Erro ao decodificar a imagem $fieldName para saída $idSaidaLocal');
            }
          } else {
            print('Arquivo $fieldName não encontrado ou inválido para saída $idSaidaLocal');
          }
        }

        // Adicionar dados da saída
        if (!isUpdate) {
          // Criação
          request.fields.addAll({
            'saida[id_empresa_saida]': saida['id_empresa_saida'].toString(),
            'saida[id_unidade]': saida['id_unidade'].toString(),
            'saida[sit_saida]': saida['sit_saida'].toString(),
            'saida[id_usuario]': saida['id_usuario'].toString(),
            'saida[dhs_cadastro]': saida['dhs_cadastro'] as String,
          });
          await addPhotoToRequest(saida['foto_inicial'] as String?, 'foto_inicial');
        } else {
          // Atualização
          request.fields.addAll({
            'saida[sit_saida]': saida['sit_saida'].toString(),
            'saida[sit_limpeza]': saida['sit_limpeza'] as String? ?? '',
            'saida[dhs_atualizacao]': saida['dhs_atualizacao'] as String? ?? DateTime.now().toIso8601String(),
          });
          await addPhotoToRequest(saida['foto_final'] as String?, 'foto_final');
        }

        // Enviar a requisição
        print('Enviando requisição para o servidor (POST)...');
        print('URL: ${request.url}');
        print('Método: ${request.method}');
        print('Campos: ${request.fields}');
        print('Arquivos: ${request.files.length}');
        final response = await request.send().timeout(const Duration(seconds: 120));
        final responseBody = await response.stream.bytesToString();

        // Deletar arquivos temporários
        for (var tempFilePath in tempFilePaths) {
          final tempFile = File(tempFilePath);
          if (tempFile.existsSync()) {
            tempFile.deleteSync();
            print('Arquivo temporário deletado: $tempFilePath');
          }
        }

        print('Status Code (Saída): ${response.statusCode}');
        print('Response (Saída): $responseBody');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = jsonDecode(responseBody);
          final idSaidaServidorResponse = responseData['id_saida'] as int?;
          if (idSaidaServidorResponse != null) {
            await db.update(
              'saidas_offline',
              {
                'sincronizado': 1,
                if (!isUpdate) 'id_saida_servidor': idSaidaServidorResponse,
              },
              where: 'id_saida = ?',
              whereArgs: [idSaidaLocal],
            );
            print('Saída $idSaidaLocal ${isUpdate ? 'atualizada' : 'criada'} com sucesso (ID servidor: $idSaidaServidorResponse)');
          } else {
            print('Erro: API não retornou id_saida na resposta: $responseBody');
          }
        } else {
          print('Erro ao sincronizar saída $idSaidaLocal: ${response.statusCode} - $responseBody');
        }
      }
    } catch (e) {
      print('Erro ao sincronizar saídas pendentes: $e');
    } finally {
      _isSaidaSyncRunning = false;
      print('Sincronização de saídas pendentes concluída.');
    }
  }

  static Future<void> _sincronizarRA() async {
    try {
      print('Tentando sincronizar RAs... URL: $baseUrl/api/regioes-administrativas');
      final response = await http.get(Uri.parse('$baseUrl/api/regioes-administrativas')).timeout(const Duration(seconds: 30));
      print('Resposta recebida. Status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final db = await DatabaseHelper.instance.database;
        final novasRegioes = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        await db.delete('ra_offline');
        for (var regiao in novasRegioes) {
          await db.insert('ra_offline', {
            'id_ra': regiao['id_ra'],
            'numero_ra': regiao['numero_ra'],
            'nome_ra': regiao['nome_ra'],
            'dhs_cadastro': regiao['dhs_cadastro'],
          });
        }
        print('RAs sincronizadas com sucesso. Total de RAs: ${novasRegioes.length}');
      } else {
        print('Erro ao sincronizar RAs: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Erro ao sincronizar RAs: $e');
      rethrow; // Propaga o erro para ser tratado no método chamador
    }
  }

  static Future<void> _sincronizarTiposResiduo() async {
    try {
      print('Tentando sincronizar Tipos de Resíduos... URL: $baseUrl/api/tipos-residuo');
      final response = await http.get(Uri.parse('$baseUrl/api/tipos-residuo')).timeout(const Duration(seconds: 30));
      print('Resposta recebida. Status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final db = await DatabaseHelper.instance.database;
        final novosTipos = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        await db.delete('tipos_residuo_offline');
        for (var tipo in novosTipos) {
          await db.insert('tipos_residuo_offline', {
            'id_residuo': tipo['id_residuo'],
            'nome_residuo': tipo['nome_residuo'],
            'dsc_residuo': tipo['dsc_residuo'],
            'dhs_cadastro': tipo['dhs_cadastro'],
          });
        }
        print('Tipos de resíduos sincronizados com sucesso. Total de tipos: ${novosTipos.length}');
      } else {
        print('Erro ao sincronizar tipos de resíduos: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Erro ao sincronizar tipos de resíduos: $e');
      rethrow;
    }
  }
}