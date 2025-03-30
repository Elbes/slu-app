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
  static const String baseUrl = 'http://localhost:80'; // Ajuste para a porta correta do servidor Laravel
  static bool _isSynchronizing = false; // Flag para evitar sincronizações simultâneas

  static Future<void> sincronizarDados() async {
    if (_isSynchronizing) {
      print('Sincronização já em andamento. Aguardando conclusão...');
      return;
    }

    _isSynchronizing = true;
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        print('Sem conexão com a internet. Sincronização adiada.');
        return;
      }

      final db = await DatabaseHelper.instance.database;
      final prefs = await SharedPreferences.getInstance();

      // Sincronizar RAs
      await _sincronizarRA();

      // Sincronizar Tipos de Resíduos
      await _sincronizarTiposResiduo();

      // Sincronizar EmpresasSaidas
      final lastEmpresasSync = prefs.getString('last_empresas_saidas_sync') ?? '';
      if (lastEmpresasSync.isEmpty) {
        print('Sincronizando EmpresasSaidas pela primeira vez...');
        try {
          final response = await http.get(
            Uri.parse('$baseUrl/api/empresas-saidas'),
            headers: {'Content-Type': 'application/json'},
          );

          if (response.statusCode == 200) {
            final List<dynamic> empresas = jsonDecode(response.body);
            print('Dados recebidos do servidor: $empresas');

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

            final now = DateTime.now().toIso8601String();
            await prefs.setString('last_empresas_saidas_sync', now);
            print('EmpresasSaidas sincronizadas com sucesso em $now!');
          } else {
            print('Erro ao sincronizar EmpresasSaidas: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          print('Erro ao sincronizar EmpresasSaidas: $e');
        }
      } else {
        print('EmpresasSaidas já sincronizadas em $lastEmpresasSync. Pulando sincronização.');
      }

      // Sincronizar Usuários (apenas id_perfil = 2)
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/users'),
          headers: {'Content-Type': 'application/json'},
        );
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
          print('Usuários sincronizados com sucesso.');
        } else {
          print('Erro ao sincronizar usuários: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('Erro ao sincronizar usuários: $e');
      }

      // Sincronizar Unidades
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/unidades'),
          headers: {'Content-Type': 'application/json'},
        );
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
          print('Unidades sincronizadas com sucesso.');
        } else {
          print('Erro ao sincronizar unidades: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('Erro ao sincronizar unidades: $e');
      }

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
        );

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
        );

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
    } finally {
      _isSynchronizing = false;
    }
  }

  static Future<void> _sincronizarRA() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/regioes-administrativas'));
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
        print('RAs sincronizadas com sucesso.');
      } else {
        print('Erro ao sincronizar RAs: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Erro ao sincronizar RAs: $e');
    }
  }

  static Future<void> _sincronizarTiposResiduo() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/tipos-residuo'));
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
        print('Tipos de resíduos sincronizados com sucesso.');
      } else {
        print('Erro ao sincronizar tipos de resíduos: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Erro ao sincronizar tipos de resíduos: $e');
    }
  }
}