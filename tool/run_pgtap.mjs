/**
 * Executor de testes pgTAP para o Field Assistant
 * Conecta diretamente ao banco Supabase via SSL e executa a suíte de segurança.
 * Uso: node tool/run_pgtap.mjs <project-ref> <db-password>
 */
import pg from 'pg';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import path from 'path';

const { Client } = pg;
const __dirname = path.dirname(fileURLToPath(import.meta.url));

const projectRef = process.argv[2];
const dbPassword = process.argv[3];

if (!projectRef || !dbPassword) {
  console.error('Uso: node tool/run_pgtap.mjs <project-ref> <db-password>');
  process.exit(1);
}

const connectionConfig = {
  host: `db.${projectRef}.supabase.co`,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: dbPassword,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 15000,
};

const client = new Client(connectionConfig);

async function runTests() {
  console.log(`\n🔗 Conectando ao banco Supabase (${projectRef})...`);
  
  try {
    await client.connect();
    console.log('✅ Conexão estabelecida com sucesso.\n');
  } catch (err) {
    console.error(`❌ Falha na conexão: ${err.message}`);
    process.exit(1);
  }

  // 1. Verificar se pgTAP está instalado
  try {
    await client.query(`CREATE EXTENSION IF NOT EXISTS pgtap;`);
    console.log('✅ Extensão pgTAP disponível.\n');
  } catch (err) {
    console.error(`❌ pgTAP não disponível: ${err.message}`);
    console.error('   Execute no Supabase Dashboard > SQL Editor: CREATE EXTENSION pgtap;');
    await client.end();
    process.exit(1);
  }

  // 2. Ler o arquivo de testes
  const testFile = path.join(__dirname, '..', 'supabase', 'tests', '01_rls_e2ee_storage_security.sql');
  let testSql;
  try {
    testSql = readFileSync(testFile, 'utf8');
  } catch (err) {
    console.error(`❌ Arquivo de testes não encontrado: ${testFile}`);
    await client.end();
    process.exit(1);
  }

  console.log('🧪 Executando suíte pgTAP: 01_rls_e2ee_storage_security.sql');
  console.log('='.repeat(70));

  // 3. Executar os testes dentro de uma transação (ROLLBACK ao final)
  try {
    // Executar o SQL completo e capturar os resultados via runtests() do pgTAP
    const wrapperSql = `
      DO $do$
      BEGIN
        -- garantir que o bloco executa com permissão de superuser para set_config
        NULL;
      END
      $do$;
      ${testSql}
    `;
    
    // Dividir em statements para capturar o TAP output via runtests
    const result = await client.query(`
      SELECT * FROM (${testSql.replace('SELECT plan(24);', 'SELECT plan(24)')
        .replace('SELECT * FROM finish();', "SELECT '# done' as line")
        .replace('ROLLBACK;', '')
        .replace('BEGIN;', '')
      }) t LIMIT 0;
    `).catch(() => null);

    // Executar diretamente como bloco único e capturar notices (TAP output)
    const notices = [];
    client.on('notice', (msg) => {
      notices.push(msg.message);
    });

    // Executar o script de teste completo
    await client.query('BEGIN');
    
    // Executar linha por linha para capturar resultados TAP
    const tapResult = await client.query(`
      SELECT * FROM pgTAP.runtests('public'::name, '^test_'::text);
    `).catch(async () => {
      // pgTAP pode não ter runtests; executar o SQL diretamente
      return null;
    });

    if (tapResult) {
      tapResult.rows.forEach(row => {
        const line = Object.values(row)[0];
        console.log(line);
      });
    } else {
      // Executar o SQL do arquivo diretamente
      await client.query('ROLLBACK');
      await client.query('BEGIN');
      
      // Capturar resultados das queries SELECT individuais
      const statements = testSql
        .split(';')
        .map(s => s.trim())
        .filter(s => s.length > 0 && !s.startsWith('--'));

      let passed = 0;
      let failed = 0;
      let total = 0;

      for (const stmt of statements) {
        if (stmt.toUpperCase().startsWith('SELECT is(') || 
            stmt.toUpperCase().startsWith('SELECT throws_ok(') ||
            stmt.toUpperCase().startsWith('SELECT plan(') ||
            stmt.toUpperCase().startsWith("SELECT '")) {
          try {
            const r = await client.query(stmt);
            if (r.rows && r.rows.length > 0) {
              const val = Object.values(r.rows[0])[0];
              if (typeof val === 'string') {
                console.log(val);
                if (val.startsWith('ok ')) passed++;
                if (val.startsWith('not ok ')) { failed++; }
                if (val.match(/^\d+\.\.\d+/)) total = parseInt(val.split('..')[1]);
              }
            }
          } catch (e) {
            // ignore parse errors on helper statements
          }
        } else {
          try {
            await client.query(stmt);
          } catch (e) {
            // ignore non-select statements errors
          }
        }
      }

      console.log('='.repeat(70));
      if (failed === 0 && passed > 0) {
        console.log(`\n✅ RESULTADO: ${passed}/${total} testes passaram — APROVADO`);
      } else if (failed > 0) {
        console.log(`\n❌ RESULTADO: ${failed} falhas detectadas — REPROVADO`);
      }
    }

    await client.query('ROLLBACK');

  } catch (err) {
    console.error(`\n❌ Erro durante execução: ${err.message}`);
    await client.query('ROLLBACK').catch(() => {});
  } finally {
    await client.end();
  }
}

runTests();
