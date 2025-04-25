import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'entrada_screen.dart';
import 'saidas_screen.dart';
import 'saida_intermediaria_screen.dart';
import 'custom_app_bar.dart';
import '../database_helper.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  Future<Map<String, dynamic>?> _verificarSaidaIniciada() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? idUnidade = prefs.getInt('id_unidade');
      if (idUnidade == null) {
        print('ID da unidade não encontrado em SharedPreferences.');
        return null;
      }

      final db = await DatabaseHelper.instance.database;
      final saidas = await db.query(
        'saidas_offline',
        where: 'id_unidade = ? AND sit_saida = ?',
        whereArgs: [idUnidade, 1], // sit_saida = 1 (Iniciada)
        limit: 1,
      );

      if (saidas.isNotEmpty) {
        final saida = saidas.first;
        print('Saída encontrada: $saida'); // Log para depuração

        final idSaida = saida['id_saida'] as int?;
        final idEmpresaSaida = saida['id_empresa_saida'] as int?;
        final dhsCadastro = saida['dhs_cadastro'] as String?;

        if (idSaida == null || idEmpresaSaida == null || dhsCadastro == null) {
          print('Dados incompletos na saída: id=$idSaida, id_empresa_saida=$idEmpresaSaida, dhs_cadastro=$dhsCadastro');
          return null;
        }

        final dataHora = DateTime.parse(dhsCadastro);
        final dataFormatada = DateFormat('dd/MM/yyyy').format(dataHora);
        final horaFormatada = DateFormat('HH:mm:ss').format(dataHora);

        final empresas = await db.query(
          'empresas_saida_offline',
          where: 'id_empresa_saida = ?',
          whereArgs: [idEmpresaSaida],
        );

        if (empresas.isNotEmpty) {
          final empresa = empresas[0]['nom_empresa'] as String?;
          if (empresa == null) {
            print('Nome da empresa não encontrado para id_empresa_saida=$idEmpresaSaida');
            return null;
          }

          return {
            'idSaida': idSaida,
            'data': dataFormatada,
            'hora': horaFormatada,
            'empresa': empresa,
          };
        } else {
          print('Empresa não encontrada para id_empresa_saida=$idEmpresaSaida');
        }
      } else {
        print('Nenhuma saída iniciada encontrada para id_unidade=$idUnidade');
      }
      return null;
    } catch (e) {
      print('Erro ao verificar saída iniciada: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Construindo HomeScreen'); // Log para depuração
    return Scaffold(
      appBar: CustomAppBar(
        showLogoutButton: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0), // Reduzido o padding vertical
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Centraliza verticalmente
            crossAxisAlignment: CrossAxisAlignment.center, // Centraliza horizontalmente
            children: [
              _buildButton(
                context: context,
                iconPath: 'assets/entrada_logo.png',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EntradaScreen()),
                  );
                },
              ),
              const SizedBox(height: 16.0), // Reduzido o espaço entre os botões
              _buildButton(
                context: context,
                iconPath: 'assets/saida_logo.png',
                onTap: () async {
                  final saidaPendente = await _verificarSaidaIniciada();
                  if (saidaPendente != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SaidaIntermediariaScreen(
                          idSaida: saidaPendente['idSaida'],
                          data: saidaPendente['data'],
                          hora: saidaPendente['hora'],
                          empresa: saidaPendente['empresa'],
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SaidasScreen()),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String iconPath,
    required VoidCallback onTap,
  }) {
    final double buttonWidth = MediaQuery.of(context).size.width * 0.8; // 80% da largura da tela
    final double buttonHeight = buttonWidth * 0.25; // Ajustada a proporção para evitar overflow

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        width: buttonWidth,
        height: buttonHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Image.asset(
            iconPath,
            width: buttonWidth,
            height: buttonHeight,
            fit: BoxFit.fill, // Preenche todo o espaço do botão
          ),
        ),
      ),
    );
  }
}