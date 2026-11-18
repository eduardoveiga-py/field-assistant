'use strict';
const { Client } = require('pg');

const client = new Client({
  host: 'db.pchwrcwrvnbiywrdsvum.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD || (process.argv.length > 3 ? process.argv[3] : ''),
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 20000,
});

async function main() {
  await client.connect();
  console.log('Conectado.\n');

  // 1. Migrações já aplicadas
  const migrations = await client.query(
    'SELECT version FROM supabase_migrations.schema_migrations ORDER BY version'
  ).catch(() => null);

  if (migrations) {
    console.log('=== Migrações aplicadas no banco ===');
    migrations.rows.forEach(r => console.log(' -', r.version));
  } else {
    console.log('Tabela supabase_migrations nao encontrada.');
  }

  // 2. Funções E2EE presentes
  const fns = await client.query(
    "SELECT proname, pronargs FROM pg_proc WHERE proname IN ('encrypted_record_cas','encrypted_records_pull_since','recovery_vault_create','sync_upsert') ORDER BY proname"
  );
  console.log('\n=== Funções E2EE no banco ===');
  if (fns.rows.length === 0) {
    console.log('  NENHUMA — migrações E2EE não foram aplicadas');
  } else {
    fns.rows.forEach(r => console.log(` - ${r.proname} (${r.pronargs} args)`));
  }

  // 3. Tabelas E2EE presentes
  const tbls = await client.query(
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('encrypted_records','recovery_vaults','people') ORDER BY table_name"
  );
  console.log('\n=== Tabelas E2EE no banco ===');
  tbls.rows.forEach(r => console.log(' -', r.table_name));

  // 4. Buckets de Storage
  const buckets = await client.query(
    "SELECT id, public FROM storage.buckets WHERE id IN ('voice_notes','ticuna_audio','knowledge_vault','person_photos') ORDER BY id"
  );
  console.log('\n=== Buckets de Storage ===');
  buckets.rows.forEach(r => console.log(` - ${r.id}: public=${r.public}`));

  await client.end();
}

main().catch(async e => {
  console.error('ERRO:', e.message);
  await client.end().catch(() => {});
  process.exit(1);
});
