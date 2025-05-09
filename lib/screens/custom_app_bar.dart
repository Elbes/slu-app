import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../sync_helper.dart'; // Importe o SyncHelper

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onBackPressed;
  final bool showLogoutButton;

  const CustomAppBar({
    Key? key,
    this.onBackPressed,
    this.showLogoutButton = false,
  }) : super(key: key);

  // Função para realizar o logout
  Future<void> _logout(BuildContext context) async {
    // Parar o monitoramento de conectividade e aguardar a conclusão de sincronizações
    await SyncHelper.stopConnectivityMonitoring();

    // Limpar as preferências
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Limpa todas as preferências, incluindo o estado de login

    // Verificar se o widget ainda está montado antes de navegar
    if (!context.mounted) return;

    // Redirecionar para a tela de login
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: onBackPressed != null // Mostra apenas o botão de voltar, se fornecido
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBackPressed,
            )
          : null, // Remove o leading completamente se não houver botão de voltar
      leadingWidth: onBackPressed != null ? 56 : 0, // Ajusta a largura apenas se o botão de voltar estiver presente
      title: Image.asset(
        'assets/slu_logo.png', // Substitua pelo caminho da sua imagem
        height: 40, // Ajuste a altura conforme necessário
      ),
      centerTitle: true,
      backgroundColor: const Color(0xFF1E3A8A),
      elevation: 0,
      actions: [
        if (showLogoutButton) // Mostra o botão de logout apenas se showLogoutButton for true
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
            tooltip: 'Sair',
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}