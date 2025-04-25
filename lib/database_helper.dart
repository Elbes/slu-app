import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:bcrypt/bcrypt.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_entradas.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    print('Caminho do banco de dados: $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    print('Iniciando criação do banco de dados...');

    // Criando as tabelas
    try {
      print('Criando tabela users');
      await db.execute('''
        CREATE TABLE users (
          id_usuario INTEGER PRIMARY KEY,
          nom_usuario TEXT NOT NULL,
          num_cpf TEXT,
          dat_nascimento TEXT,
          id_unidade INTEGER NOT NULL,
          id_perfil INTEGER NOT NULL,
          dsc_email TEXT NOT NULL,
          pws_senha TEXT NOT NULL,
          dhs_cadastro TEXT
        )
      ''');

      print('Criando tabela unidades');
      await db.execute('''
        CREATE TABLE unidades (
          id_unidade INTEGER PRIMARY KEY,
          nome TEXT NOT NULL,
          id_ra INTEGER NOT NULL,
          endereco TEXT,
          dhs_cadastro TEXT,
          dhs_atualizacao TEXT
        )
      ''');

      print('Criando tabela ra_offline');
      await db.execute('''
        CREATE TABLE ra_offline (
          id_ra INTEGER PRIMARY KEY,
          nome_ra TEXT NOT NULL,
          numero_ra INTEGER NOT NULL,
          dhs_cadastro TEXT
        )
      ''');

      print('Criando tabela tipos_residuo_offline');
      await db.execute('''
        CREATE TABLE tipos_residuo_offline (
          id_residuo INTEGER PRIMARY KEY,
          nome_residuo TEXT NOT NULL,
          dsc_residuo TEXT,
          dhs_cadastro TEXT
        )
      ''');

      print('Criando tabela entradas_offline');
      await db.execute('''
        CREATE TABLE entradas_offline (
          id_entrada INTEGER PRIMARY KEY AUTOINCREMENT,
          id_entrada_servidor INTEGER,
          placa_veiculo TEXT,
          id_ra TEXT,
          id_unidade INTEGER NOT NULL,
          alerta_irregularidade INTEGER NOT NULL,
          id_tipo_irregularidade INTEGER,
          id_usuario INTEGER NOT NULL,
          dhs_cadastro TEXT,
          sincronizado INTEGER DEFAULT 0
        )
      ''');

      print('Criando tabela residuo_entrada_offline');
      await db.execute('''
        CREATE TABLE residuo_entrada_offline (
          id_residuo_entrada INTEGER PRIMARY KEY AUTOINCREMENT,
          id_residuo_entrada_servidor INTEGER,
          id_entrada INTEGER NOT NULL,
          id_residuo INTEGER NOT NULL,
          dhs_cadastro TEXT,
          sincronizado INTEGER DEFAULT 0,
          FOREIGN KEY (id_entrada) REFERENCES entradas_offline (id_entrada),
          FOREIGN KEY (id_residuo) REFERENCES tipos_residuo_offline (id_residuo)
        )
      ''');

      print('Criando tabela fotos_entrada_offline');
      await db.execute('''
        CREATE TABLE fotos_entrada_offline (
          id_foto INTEGER PRIMARY KEY AUTOINCREMENT,
          nome_foto TEXT NOT NULL,
          file_path TEXT NOT NULL,
          id_entrada INTEGER NOT NULL,
          dhs_cadastro TEXT,
          sincronizado INTEGER DEFAULT 0,
          FOREIGN KEY (id_entrada) REFERENCES entradas_offline (id_entrada)
        )
      ''');

      print('Criando tabela empresas_saida_offline');
      await db.execute('''
        CREATE TABLE empresas_saida_offline (
          id_empresa_saida INTEGER PRIMARY KEY,
          nom_empresa TEXT,
          dsc_empresa TEXT,
          dhs_cadastro TEXT,
          dhs_atualizacao TEXT,
          dhs_exclusao TEXT
        )
      ''');

      print('Criando tabela saidas_offline');
      await db.execute('''
        CREATE TABLE saidas_offline (
          id_saida INTEGER PRIMARY KEY AUTOINCREMENT,
          id_empresa_saida INTEGER,
          id_unidade INTEGER,
          sit_saida INTEGER, -- 1: Iniciada, 2: Finalizada
          foto_inicial TEXT,
          foto_final TEXT,
          sit_limpeza TEXT,
          id_usuario INTEGER,
          dhs_cadastro TEXT,
          dhs_atualizacao TEXT,
          sincronizado INTEGER,
          id_saida_servidor INTEGER
        )
      ''');
    } catch (e) {
      print('Erro ao criar tabelas: $e');
      rethrow;
    }

    // Inserções iniciais

    // 1. Inserir Regiões Administrativas (RAs) primeiro
    try {
      print('Inserindo RAs...');
      await db.insert('ra_offline', {'id_ra': 1, 'nome_ra': 'ASA NORTE', 'numero_ra': 1, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 2, 'nome_ra': 'GAMA', 'numero_ra': 2, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 3, 'nome_ra': 'TAGUATINGA', 'numero_ra': 3, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 4, 'nome_ra': 'BRAZLÂNDIA', 'numero_ra': 4, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 5, 'nome_ra': 'SOBRADINHO', 'numero_ra': 5, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 6, 'nome_ra': 'PLANALTINA', 'numero_ra': 6, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 7, 'nome_ra': 'PARANOÁ', 'numero_ra': 7, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 9, 'nome_ra': 'CEILÂNDIA', 'numero_ra': 9, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 10, 'nome_ra': 'GUARÁ', 'numero_ra': 10, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 12, 'nome_ra': 'SAMAMBAIA', 'numero_ra': 12, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 13, 'nome_ra': 'SANTA MARIA', 'numero_ra': 13, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 14, 'nome_ra': 'SÃO SEBASTIÃO', 'numero_ra': 14, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 15, 'nome_ra': 'RECANTO DAS EMAS', 'numero_ra': 15, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 16, 'nome_ra': 'SOBRADINHO II', 'numero_ra': 16, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 17, 'nome_ra': 'SCIA', 'numero_ra': 17, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 18, 'nome_ra': 'GRANJA DO TORTO', 'numero_ra': 18, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 20, 'nome_ra': 'ÁGUAS CLARAS', 'numero_ra': 20, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('ra_offline', {'id_ra': 32, 'nome_ra': 'PÔR DO SOL', 'numero_ra': 32, 'dhs_cadastro': '2024-11-28 09:42:53'});
      print('RAs inseridos com sucesso.');
    } catch (e) {
      print('Erro ao inserir RAs: $e');
      rethrow;
    }

    // 2. Inserir as unidades após as RAs
    try {
      print('Inserindo unidades...');
      await db.insert('unidades', {
        'id_unidade': 1,
        'nome': 'PEV BRAZLÂNDIA 1',
        'id_ra': 4,
        'endereco': 'NÚCLEO DE LIMPEZA DO SUL DE BRAZLÂNDIA',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 2,
        'nome': 'PEV BRAZLÂNDIA 2',
        'id_ra': 4,
        'endereco': 'QUADRA 33, VILA SÃO JOSÉ',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 3,
        'nome': 'PEV PLANALTINA',
        'id_ra': 6,
        'endereco': 'ÁREA ESPECIAL 02',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 4,
        'nome': 'PEV SOBRADINHO I',
        'id_ra': 5,
        'endereco': 'QUADRA 10',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 5,
        'nome': 'PEV SOBRADINHO II',
        'id_ra': 5,
        'endereco': 'AE 3 PARA INDÚSTRIA LT 7/10 - ADM',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 6,
        'nome': 'PEV SOBRADINHO II',
        'id_ra': 16,
        'endereco': 'QUADRA 4, BURITIS',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 7,
        'nome': 'PEV PARANOÁ',
        'id_ra': 7,
        'endereco': 'QUADRA 05',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 8,
        'nome': 'PEV SÃO SEBASTIÃO I',
        'id_ra': 14,
        'endereco': 'QUADRA 305 (PRÓXIMO CAESB E SLU)',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 9,
        'nome': 'PEV SÃO SEBASTIÃO II',
        'id_ra': 14,
        'endereco': 'BAIRRO CRICIÁ, RUA 33',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 10,
        'nome': 'PEV SANTA MARIA I',
        'id_ra': 13,
        'endereco': 'AE 99 (NORTE)',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 11,
        'nome': 'PEV SANTA MARIA II',
        'id_ra': 13,
        'endereco': 'AC 105 (SUL)',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 12,
        'nome': 'PEV GAMA I',
        'id_ra': 2,
        'endereco': 'NÚCLEO DE LIMPEZA DO SLU NO GAMA',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 13,
        'nome': 'PEV GAMA II',
        'id_ra': 2,
        'endereco': 'ENTRE A Q 6 E 12 - SETOR SUL',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 14,
        'nome': 'PEV ASA SUL',
        'id_ra': 1,
        'endereco': 'DL SUL SLU',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 15,
        'nome': 'PEV GUARÁ I',
        'id_ra': 10,
        'endereco': 'SRIA II QE 25 CAVE',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 16,
        'nome': 'PEV GUARÁ II',
        'id_ra': 10,
        'endereco': 'SRIA II AE 10 LT A PM',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 17,
        'nome': 'PEV RECANTO DAS EMAS',
        'id_ra': 15,
        'endereco': 'AE 2 QD 206/300',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 18,
        'nome': 'PEV ÁGUAS CLARAS',
        'id_ra': 20,
        'endereco': 'AVENIDA JACARANDÁ, LOTE 24',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 19,
        'nome': 'PEV SAMAMBAIA',
        'id_ra': 12,
        'endereco': 'QR 608',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 20,
        'nome': 'PEV CEILÂNDIA I',
        'id_ra': 9,
        'endereco': 'NÚCLEO DE LIMPEZA DO SLU DE CEILÂNDIA (QNN 29)',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 21,
        'nome': 'PEV CEILÂNDIA II',
        'id_ra': 9,
        'endereco': 'QNN 27',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 22,
        'nome': 'PEV TAGUATINGA',
        'id_ra': 3,
        'endereco': 'NÚCLEO DE LIMPEZA DO SLU DE TAGUATINGA',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 23,
        'nome': 'PEV PÔR DO SOL',
        'id_ra': 32,
        'endereco': 'ÁREA DA USINA DO SLU (QNP 28)',
        'dhs_cadastro': '2024-11-28 09:42:53',
        'dhs_atualizacao': null,
      });
      await db.insert('unidades', {
        'id_unidade': 24,
        'nome': 'PEV GRANJA DO TORTO',
        'id_ra': 18,
        'endereco': 'GRANJA DO TORTO',
        'dhs_cadastro': '2025-01-06 08:05:46',
        'dhs_atualizacao': '2025-01-06 08:05:46',
      });
      print('Unidades inseridas com sucesso.');
    } catch (e) {
      print('Erro ao inserir unidades: $e');
      rethrow;
    }

    // 3. Inserir usuários após as unidades
    try {
      print('Inserindo usuários...');

      // Usuário Administrador
      await db.insert('users', {
        'id_usuario': 1,
        'nom_usuario': 'ADMINISTRADOR',
        'num_cpf': '15315236155',
        'dat_nascimento': '1990-09-09',
        'id_unidade': 1,
        'id_perfil': 1,
        'dsc_email': 'elbes2009@gmail.com',
        'pws_senha': '\$2y\$10\$27FH8WIlGDY6VieY/oRneOsHrwhhJ3/ohJbyBZdvXEvJIuuZO0dfG',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 1 (ADMINISTRADOR) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 2,
        'nom_usuario': 'FRANCILIO JUNIOR',
        'num_cpf': '15315236155',
        'dat_nascimento': '1990-09-09',
        'id_unidade': 12,
        'id_perfil': 3,
        'dsc_email': 'francilio.junior@slu.df.gov.br',
        'pws_senha': '\$2y\$10\$iSRTg63jRZ0O3rGx167HNeTWNoTgP07SBh83ctx4rApO.Q0.vakvC',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 2 (FRANCILIO JUNIOR) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 3,
        'nom_usuario': 'ELBES ALVES',
        'num_cpf': '15315236155',
        'dat_nascimento': '1985-09-09',
        'id_unidade': 1,
        'id_perfil': 4,
        'dsc_email': 'elbes.souza@slu.df.gov.br',
        'pws_senha': '\$2y\$10\$wGK/Vt0BPaG1EJYffjEhW.QwOSJ7uz.n6AGtRf1usi08Yka54wL4C',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 3 (ELBES ALVES) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 4,
        'nom_usuario': 'Kaleb Silva Mourão',
        'num_cpf': '050.648.911-64',
        'dat_nascimento': '1995-08-26',
        'id_unidade': 16,
        'id_perfil': 3,
        'dsc_email': 'kaleb.mourao@noresa.com.br',
        'pws_senha': '\$2y\$10\$OldrM0xO531HZgJ8UjtkS.9QQSOCMh5WAut1AdFSOzvfzWMtCUp6K',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 4 (Kaleb Silva Mourão) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 8,
        'nom_usuario': 'Paulo Sérgio Alves Silva',
        'num_cpf': '194.002.762-49',
        'dat_nascimento': '1967-11-15',
        'id_unidade': 15,
        'id_perfil': 3,
        'dsc_email': 'paulo.silva@noresa.com.br',
        'pws_senha': '\$2y\$10\$iBczsbbuomUkOSabvtLrH.J7IhD0HM71YKne/3Y8kItwyojsaq4JC',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 8 (Paulo Sérgio Alves Silva) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 13,
        'nom_usuario': 'Everaldo Araújo',
        'num_cpf': '24846198120',
        'dat_nascimento': '1966-01-14',
        'id_unidade': 16,
        'id_perfil': 3,
        'dsc_email': 'everaldomilll@yahoo.com.br',
        'pws_senha': '\$2y\$10\$2yYwUk//OtW0Yop6mCEag.WBDESsY/fRhwNSrWUiDGv9gcbtB0Tj6',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 13 (Everaldo Araújo) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 14,
        'nom_usuario': 'Wanderley Chagas',
        'num_cpf': '99376091000',
        'dat_nascimento': '1982-09-20',
        'id_unidade': 10,
        'id_perfil': 3,
        'dsc_email': 'wanderley.chagas@slu.df.gov.br',
        'pws_senha': '\$2y\$10\$mnO5.JuIjzFdyRoF8u5.8unku0DtoRjAg5acrqa0b2jT7RLAo2KQ.',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 14 (Wanderley Chagas) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 42,
        'nom_usuario': 'Nelson Gonçalves Pires Filho',
        'num_cpf': '261.139.106-87',
        'dat_nascimento': '1965-01-01',
        'id_unidade': 18,
        'id_perfil': 3,
        'dsc_email': 'nel.gon777@gmail.com',
        'pws_senha': '\$2y\$10\$H64Ov3gtdKJyBicVOMpEt.xF6y4/prc4YtyDSMPKrG0BONi5RQuIq',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 42 (Nelson Gonçalves Pires Filho) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 43,
        'nom_usuario': 'Mayara Menezes',
        'num_cpf': '037.404.561-59',
        'dat_nascimento': '1990-11-16',
        'id_unidade': 1,
        'id_perfil': 3,
        'dsc_email': 'mayara.alves@adasa.df.gov.br',
        'pws_senha': '\$2y\$10\$LbSaagZDfy3VJzSMIayfCeV/7V4pQFIxFTHcDEhsD02ypreiKa74G',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 43 (Mayara Menezes) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 44,
        'nom_usuario': 'ligia.lopes@adasa.df.gov.br',
        'num_cpf': '00000000000',
        'dat_nascimento': '1954-08-11',
        'id_unidade': 15,
        'id_perfil': 3,
        'dsc_email': 'ligia.lopes@adasa.df.gov.br',
        'pws_senha': '\$2y\$10\$tqeuJlI3VmtXjLqHJ03a/.DmtshbRdSY38QMvSo8vdv8Cw9Xyh3lm',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 44 (ligia.lopes@adasa.df.gov.br) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 105,
        'nom_usuario': 'Pev Gama Norte',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 12,
        'id_perfil': 2,
        'dsc_email': 'pevgamanorte@gmail.com',
        'pws_senha': '\$2y\$10\$7xWocPzTcv5xvtWJaQH.ReCk4cR7.qeaIYI518Pw7OqTFYCepREO2',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 105 (Pev Gama Norte) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 106,
        'nom_usuario': 'Pev Gama Sul',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 13,
        'id_perfil': 2,
        'dsc_email': 'pevgamasul@gmail.com',
        'pws_senha': '\$2y\$10\$JvYXTsW/uoE6OdfIYPeI6e8vAtdF/6AzqW5g1ohiL8KS2PKlNTxMy',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 106 (Pev Gama Sul) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 107,
        'nom_usuario': 'Pev Brazlandia 01_Núcleo',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 1,
        'id_perfil': 2,
        'dsc_email': 'pevbrazlandia01@gmail.com',
        'pws_senha': '\$2y\$10\$VtSx8D7Ygds0NOy8SvM9o.SQR4INzBeFnsaasZzoIvf45pU4tudL.',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 107 (Pev Brazlandia 01_Núcleo) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 108,
        'nom_usuario': 'Pev Brazlandia 02_Capão',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 2,
        'id_perfil': 2,
        'dsc_email': 'pevbrazlandia02@gmail.com',
        'pws_senha': '\$2y\$10\$XxWzmnrbovJwgwX00hcj/OGCiz8Xvlp8MdUPFRfsqCfogLSOgtfQm',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 108 (Pev Brazlandia 02_Capão) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 109,
        'nom_usuario': 'Pev Planaltina',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 3,
        'id_perfil': 2,
        'dsc_email': 'pevplanaltina@gmail.com',
        'pws_senha': '\$2y\$10\$sgy39atupNkg5U0n9lL.BuKkdz3OlPiKmgvNWlhy2nhslF3t.90RK',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 109 (Pev Planaltina) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 110,
        'nom_usuario': 'Pev Sobradinho 01_Dia a Dia',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 4,
        'id_perfil': 2,
        'dsc_email': 'pevsobradinho01@gmail.com',
        'pws_senha': '\$2y\$10\$auvxIlTJD05au1n4jc5A5.1jAoXPE8pKDiNHj71x4mzmq7Ppt6Teq',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 110 (Pev Sobradinho 01_Dia a Dia) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 111,
        'nom_usuario': 'Pev Sobradinho QD. 10',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 5,
        'id_perfil': 2,
        'dsc_email': 'pevsobradinhoqd10@gmail.com',
        'pws_senha': '\$2y\$10\$v20ohHFZkSirOdfrWfF7qOxGlPTx1YNsuQANJIyvszNgDOD4A51jy',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 111 (Pev Sobradinho QD. 10) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 112,
        'nom_usuario': 'PEV Sobradinho II',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 6,
        'id_perfil': 2,
        'dsc_email': 'pevsobradinho2@gmail.com',
        'pws_senha': '\$2y\$10\$pPSZrfqIThSEUUrh9j7aful1LCUbCUGVEYEnNxbcLxRbr0fwiW45K',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 112 (PEV Sobradinho II) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 113,
        'nom_usuario': 'Pev Paranoá',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 7,
        'id_perfil': 2,
        'dsc_email': 'pevparanoa@gmail.com',
        'pws_senha': '\$2y\$10\$5VPkBV04cCLdCniUzlv8DuBONdmqBxw0KyMKn28UsvQfxTZXDo6Si',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 113 (Pev Paranoá) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 114,
        'nom_usuario': 'PEV São Sebastião QD. 305',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 8,
        'id_perfil': 2,
        'dsc_email': 'pevsaosebastiao1@gmail.com',
        'pws_senha': '\$2y\$10\$suU66otdfNWdkFvRJsDz8unbfOp11.eMgbG9WXfazC3VntgsDoLwi',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 114 (PEV São Sebastião QD. 305) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 115,
        'nom_usuario': 'Pev São Sebastião Crixá',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 9,
        'id_perfil': 2,
        'dsc_email': 'pevsaosebastiao2@gmail.com',
        'pws_senha': '\$2y\$10\$vS1ZcMEIKRzEE.P16vEXXuHRWtjXDIIhMceUsX/2nvrSmpgLTzbUC',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 115 (Pev São Sebastião Crixá) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 116,
        'nom_usuario': 'Pev Santa Maria Norte',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 10,
        'id_perfil': 2,
        'dsc_email': 'pevsantamarianorte@gmail.com',
        'pws_senha': '\$2y\$10\$tVc8aG93x6oYs1Nh3pZVruhh/DqlU.ftmYPvhVpk9cZ7yDTbGEjiy',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 116 (Pev Santa Maria Norte) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 117,
        'nom_usuario': 'Pev Santa Maria Sul',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 11,
        'id_perfil': 2,
        'dsc_email': 'pevsantamariasul@gmail.com',
        'pws_senha': '\$2y\$10\$.remHOusezslOwg4Vqmptul8jC9i2sx40s53eqKaaSKP6IogpI3RG',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 117 (Pev Santa Maria Sul) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 118,
        'nom_usuario': 'Pev Asa Sul',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 14,
        'id_perfil': 2,
        'dsc_email': 'pevasasul@gmail.com',
        'pws_senha': '\$2y\$10\$igERajK7EwqKbUjd9hpO0e73yhHZ.5s37Qp07EqRpJ52nRNzNwAwu',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 118 (Pev Asa Sul) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 119,
        'nom_usuario': 'Pev Guará Feira_Cave',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 15,
        'id_perfil': 2,
        'dsc_email': 'pevguara1@gmail.com',
        'pws_senha': '\$2y\$10\$zSseIOlh004BTUME1sXasuEIcSR/3Ig/ftuC63EKVnFCdZ77zbJ2q',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 119 (Pev Guará Feira_Cave) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 120,
        'nom_usuario': 'Pev Guará PM',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 16,
        'id_perfil': 2,
        'dsc_email': 'pevguara2@gmail.com',
        'pws_senha': '\$2y\$10\$IzMNzJcjhsLTG2IoSbm1yugzH0yhf2submGq9aAH2wUC6drIMJrfK',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 120 (Pev Guará PM) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 121,
        'nom_usuario': 'Pev Recanto das Emas',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 17,
        'id_perfil': 2,
        'dsc_email': 'pevrecantodasemas@gmail.com',
        'pws_senha': '\$2y\$10\$k2WTzalRKSxR/f7H0H0DOe6MpsMlF6TSich2v2qZuuhzDQexq4h2G',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 121 (Pev Recanto das Emas) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 122,
        'nom_usuario': 'Pev Águas Claras',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 18,
        'id_perfil': 2,
        'dsc_email': 'pevaguasclaras@gmail.com',
        'pws_senha': '\$2y\$10\$IIlMgHNmtBZ0S2CJ2Ew6kO7Z6/v.Fz72xmiodrce6kzbO2M4VOrqe',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 122 (Pev Águas Claras) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 123,
        'nom_usuario': 'Pev Samambaia',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 19,
        'id_perfil': 2,
        'dsc_email': 'pevsamambaia@gmail.com',
        'pws_senha': '\$2y\$10\$vC0qGEAOJ2TlKIIQvDko4OCNNy7jQaDtl6c1Fh1jvH2GcDYAmwe/2',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 123 (Pev Samambaia) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 124,
        'nom_usuario': 'Pev Ceilândia Norte',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 20,
        'id_perfil': 2,
        'dsc_email': 'pevceilandia1@gmail.com',
        'pws_senha': '\$2y\$10\$lbk08VK5xJFBvbobW9Z8MubUdNEVoRWHLX7yfUNKTkyvLA4T2u/XK',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 124 (Pev Ceilândia Norte) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 125,
        'nom_usuario': 'Pev Ceilandia Sul',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 21,
        'id_perfil': 2,
        'dsc_email': 'pevceilandia2@gmail.com',
        'pws_senha': '\$2y\$10\$soRBKKFwZe0V7WWgxBnFF.WX8rTLXY1k0DmBFzGHm5YjbKUOVkaZu',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 125 (Pev Ceilandia Sul) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 126,
        'nom_usuario': 'Pev Por do Sol',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 23,
        'id_perfil': 2,
        'dsc_email': 'pevpordosol@gmail.com',
        'pws_senha': '\$2y\$10\$vt9cuJoQGqpFCB5hwzk7.uX9/K4fRxxEJ9s15mpHvaScwgMHEk/da',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 126 (Pev Por do Sol) inserido com sucesso.');

      await db.insert('users', {
        'id_usuario': 127,
        'nom_usuario': 'Pev Taguatinga',
        'num_cpf': '000.000.000-00',
        'dat_nascimento': '2000-01-01',
        'id_unidade': 22,
        'id_perfil': 2,
        'dsc_email': 'pevtaguatinga@gmail.com',
        'pws_senha': '\$2y\$10\$0RBRJtzQei90Lr/D4kHrlOzu.it0EUzx3.5Ws70DCwhU7m1RJrfMe',
        'dhs_cadastro': '2024-11-28 09:42:53',
      });
      print('Usuário 127 (Pev Taguatinga) inserido com sucesso.');

      print('Todos os usuários foram inseridos com sucesso.');
    } catch (e) {
      print('Erro ao inserir usuários: $e');
      rethrow;
    }

    // 4. Inserir Tipos de Resíduo
    try {
      print('Inserindo tipos de resíduo...');
      await db.insert('tipos_residuo_offline', {'id_residuo': 1, 'nome_residuo': 'RCC', 'dsc_residuo': null, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('tipos_residuo_offline', {'id_residuo': 2, 'nome_residuo': 'PODAS', 'dsc_residuo': null, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('tipos_residuo_offline', {'id_residuo': 3, 'nome_residuo': 'VOLUMOSOS', 'dsc_residuo': null, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('tipos_residuo_offline', {'id_residuo': 4, 'nome_residuo': 'RECICLÁVEIS', 'dsc_residuo': null, 'dhs_cadastro': '2024-11-28 09:42:53'});
      await db.insert('tipos_residuo_offline', {'id_residuo': 5, 'nome_residuo': 'ÓLEO DE COZINHA', 'dsc_residuo': null, 'dhs_cadastro': '2024-11-28 09:42:53'});
      print('Tipos de resíduo inseridos com sucesso.');
    } catch (e) {
      print('Erro ao inserir tipos de resíduo: $e');
      rethrow;
    }

    // 5. Inserir Empresas de Saída
    try {
      print('Inserindo empresas de saída...');
      await db.insert('empresas_saida_offline', {
        'id_empresa_saida': 1,
        'nom_empresa': 'ACOBRAZ_CRB',
        'dsc_empresa': null,
        'dhs_cadastro': '2025-01-14 15:12:22',
        'dhs_atualizacao': null,
        'dhs_exclusao': null,
      });
      await db.insert('empresas_saida_offline', {
        'id_empresa_saida': 2,
        'nom_empresa': 'COOPATIVA',
        'dsc_empresa': null,
        'dhs_cadastro': '2025-01-14 15:12:22',
        'dhs_atualizacao': null,
        'dhs_exclusao': null,
      });
      await db.insert('empresas_saida_offline', {
        'id_empresa_saida': 3,
        'nom_empresa': 'COOPERDIFE',
        'dsc_empresa': null,
        'dhs_cadastro': '2025-01-14 15:12:22',
        'dhs_atualizacao': null,
        'dhs_exclusao': null,
      });
      await db.insert('empresas_saida_offline', {
        'id_empresa_saida': 4,
        'nom_empresa': 'COOPERLIMPO',
        'dsc_empresa': null,
        'dhs_cadastro': '2025-01-14 15:12:22',
        'dhs_atualizacao': null,
        'dhs_exclusao': null,
      });
      await db.insert('empresas_saida_offline', {
        'id_empresa_saida': 5,
        'nom_empresa': 'ECOLIMPO',
        'dsc_empresa': null,
        'dhs_cadastro': '2025-01-14 15:12:22',
        'dhs_atualizacao': null,
        'dhs_exclusao': null,
      });
      await db.insert('empresas_saida_offline', {
        'id_empresa_saida': 6,
        'nom_empresa': 'FLOR DO CERRADO',
        'dsc_empresa': null,
        'dhs_cadastro': '2025-01-14 15:12:22',
        'dhs_atualizacao': null,
        'dhs_exclusao': null,
      });
      await db.insert('empresas_saida_offline', {
        'id_empresa_saida': 7,
        'nom_empresa': 'PLANALTO',
        'dsc_empresa': null,
        'dhs_cadastro': '2025-01-14 15:12:22',
        'dhs_atualizacao': null,
        'dhs_exclusao': null,
      });
      await db.insert('empresas_saida_offline', {
        'id_empresa_saida': 8,
        'nom_empresa': 'PLASFERRRO',
        'dsc_empresa': null,
        'dhs_cadastro': '2025-01-14 15:12:22',
        'dhs_atualizacao': null,
        'dhs_exclusao': null,
      });
      await db.insert('empresas_saida_offline', {
        'id_empresa_saida': 9,
        'nom_empresa': 'R3',
        'dsc_empresa': null,
        'dhs_cadastro': '2025-01-14 15:12:22',
        'dhs_atualizacao': null,
        'dhs_exclusao': null,
      });
      await db.insert('empresas_saida_offline', {
        'id_empresa_saida': 10,
        'nom_empresa': 'RECICLE A VIDA',
        'dsc_empresa': null,
        'dhs_cadastro': '2025-01-14 15:12:22',
        'dhs_atualizacao': null,
        'dhs_exclusao': null,
      });
      await db.insert('empresas_saida_offline', {
        'id_empresa_saida': 11,
        'nom_empresa': 'RENOVE',
        'dsc_empresa': null,
        'dhs_cadastro': '2025-01-14 15:12:22',
        'dhs_atualizacao': null,
        'dhs_exclusao': null,
      });
      await db.insert('empresas_saida_offline', {
        'id_empresa_saida': 12,
        'nom_empresa': 'SUMA BRASIL',
        'dsc_empresa': null,
        'dhs_cadastro': '2025-01-14 15:12:22',
        'dhs_atualizacao': null,
        'dhs_exclusao': null,
      });
      await db.insert('empresas_saida_offline', {
        'id_empresa_saida': 13,
        'nom_empresa': 'VALOR AMBIENTAL',
        'dsc_empresa': null,
        'dhs_cadastro': '2025-01-14 15:12:22',
        'dhs_atualizacao': null,
        'dhs_exclusao': null,
      });
      await db.insert('empresas_saida_offline', {
        'id_empresa_saida': 14,
        'nom_empresa': 'SUSTENTARE SANEAMENTO',
        'dsc_empresa': null,
        'dhs_cadastro': '2025-01-14 15:12:22',
        'dhs_atualizacao': null,
        'dhs_exclusao': null,
      });
      print('Empresas de saída inseridas com sucesso.');
    } catch (e) {
      print('Erro ao inserir empresas de saída: $e');
      rethrow;
    }

    print('Banco de dados criado e populado com sucesso.');
  }

  Future close() async {
    final db = await instance.database;
    await db.close();
  }
}