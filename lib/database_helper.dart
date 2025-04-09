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
    print('Caminho do banco de dados: $path'); // Adicione este log

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    print('Criando tabela users'); // Adicione este log
    // Tabela de usuários
    await db.execute('''
      CREATE TABLE users (
        id_usuario INTEGER PRIMARY KEY,
        nom_usuario TEXT NOT NULL,
        num_cpf TEXT,
        dat_nascimento TEXT ,
        id_unidade INTEGER NOT NULL,
        id_perfil INTEGER NOT NULL,
        dsc_email TEXT NOT NULL,
        pws_senha TEXT NOT NULL,
        dhs_cadastro TEXT
      )
    ''');

    // Tabela de unidades
    await db.execute('''
      CREATE TABLE unidades (
        id_unidade INTEGER PRIMARY KEY,
        nome TEXT NOT NULL,
        id_ra INTEGER NOT NULL,
        endereco TEXT ,
        dhs_cadastro TEXT,
        dhs_atualizacao TEXT
      )
    ''');

    // Tabela de Regiões Administrativas (RA)
    await db.execute('''
      CREATE TABLE ra_offline (
        id_ra INTEGER PRIMARY KEY,
        nome_ra TEXT NOT NULL,
        numero_ra INTEGER NOT NULL,
        dhs_cadastro TEXT
      )
    ''');

    // Tabela de tipos de resíduo
    await db.execute('''
      CREATE TABLE tipos_residuo_offline (
        id_residuo INTEGER PRIMARY KEY,
        nome_residuo TEXT NOT NULL,
        dsc_residuo TEXT,
        dhs_cadastro TEXT
      )
    ''');

    // Tabela de entradas offline
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

    // Tabela de resíduos associados às entradas
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

    // Tabela de fotos das entradas
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

    // Nova tabela empresas_saida_offline
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

    // Nova tabela saidas_offline
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

    // Inserções iniciais

    // Usuário Administrador
    final hashedPassword = BCrypt.hashpw('1010', BCrypt.gensalt());
    await db.insert('users', {
      'id_usuario': 1,
      'nom_usuario': 'ADMINISTRADOR',
      'dsc_email': 'elbes2009@gmail.com',
      'num_cpf': '1315236155',
      'dat_nascimento': '1990-09-09',
      'id_unidade': 16,
      'id_perfil': 3,
      'pws_senha': hashedPassword,
      'dhs_cadastro': '2024-11-28 09:42:53',
    });
    print('Usuário de teste inserido: elbes2009@gmail.com, senha: 1010');

    // Unidades
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

    // Regiões Administrativas (RAs)
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

    // Tipos de resíduo
    await db.insert('tipos_residuo_offline', {'id_residuo': 1, 'nome_residuo': 'RCC', 'dsc_residuo': null, 'dhs_cadastro': '2024-11-28 09:42:53'});
    await db.insert('tipos_residuo_offline', {'id_residuo': 2, 'nome_residuo': 'PODAS', 'dsc_residuo': null, 'dhs_cadastro': '2024-11-28 09:42:53'});
    await db.insert('tipos_residuo_offline', {'id_residuo': 3, 'nome_residuo': 'VOLUMOSOS', 'dsc_residuo': null, 'dhs_cadastro': '2024-11-28 09:42:53'});
    await db.insert('tipos_residuo_offline', {'id_residuo': 4, 'nome_residuo': 'RECICLÁVEIS', 'dsc_residuo': null, 'dhs_cadastro': '2024-11-28 09:42:53'});
    await db.insert('tipos_residuo_offline', {'id_residuo': 5, 'nome_residuo': 'ÓLEO DE COZINHA', 'dsc_residuo': null, 'dhs_cadastro': '2024-11-28 09:42:53'});

    // Empresas de Saída (empresas_saida_offline)
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
  }

  Future close() async {
    final db = await instance.database;
    await db.close();
  }
}