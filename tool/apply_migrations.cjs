'use strict';
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const client = new Client({
  host: 'db.pchwrcwrvnbiywrdsvum.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD || (process.argv.length > 3 ? process.argv[3] : ''),
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 20000,
});

const PENDING_MIGRATIONS = [
  '20261116190000_experimental_encrypted_records.sql',
  '20261116190100_experimental_recovery_vault.sql',
  '20261116200000_production_e2ee_tables_and_rpcs.sql',
  '20261117000000_e2ee_server_seq_pull_and_hardening.sql',
  '20261118000000_revoke_legacy_sync_upsert.sql',
];

async function main() {
  await client.connect();
  console.log('Conectado ao banco Supabase.\n');

  for (const migFile of PENDING_MIGRATIONS) {
    const version = migFile.replace(/_.*/, '');
    // Verificar se já foi aplicada
    const check = await client.query(
      'SELECT 1 FROM supabase_migrations.schema_migrations WHERE version = $1',
      [version]
    ).catch(() => ({ rows: [] }));

    if (check.rows.length > 0) {
      console.log(`SKIP  ${version} — ja aplicada`);
      continue;
    }

    const filePath = path.join(__dirname, '..', 'supabase', 'migrations', migFile);
    const sql = fs.readFileSync(filePath, 'utf8');

    console.log(`APPLY ${version} — ${migFile}`);
    try {
      await client.query('BEGIN');
      await client.query(sql);
      // Registrar na tabela de migrações do Supabase
      await client.query(
        'INSERT INTO supabase_migrations.schema_migrations (version) VALUES ($1) ON CONFLICT DO NOTHING',
        [version]
      );
      await client.query('COMMIT');
      console.log(`  OK\n`);
    } catch (err) {
      await client.query('ROLLBACK');
      console.error(`  ERRO: ${err.message.split('\n')[0]}`);
      console.error(`  Continuando com próxima migração...\n`);
    }
  }

  // Verificar estado final
  console.log('\n=== Estado final das funções E2EE ===');
  const fns = await client.query(
    "SELECT proname, pronargs FROM pg_proc WHERE proname IN ('encrypted_record_cas','encrypted_records_pull_since','recovery_vault_create','sync_upsert') ORDER BY proname"
  );
  fns.rows.forEach(r => console.log(` - ${r.proname} (${r.pronargs} args)`));

  await client.end();
}

main().catch(async e => {
  console.error('ERRO FATAL:', e.message);
  await client.end().catch(() => {});
  process.exit(1);
});
