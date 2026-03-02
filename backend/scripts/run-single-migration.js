const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

async function run() {
  const file = process.argv[2];
  if (!file) {
    throw new Error('Usage: node run-single-migration.js <relative-migration-file>');
  }

  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error('DATABASE_URL is required');
  }

  const migrationPath = path.resolve(__dirname, '../../db/migrations', file);
  if (!fs.existsSync(migrationPath)) {
    throw new Error(`Migration not found: ${migrationPath}`);
  }

  const sql = fs.readFileSync(migrationPath, 'utf8');
  const client = new Client({ connectionString });

  await client.connect();
  try {
    await client.query(sql);
    process.stdout.write(`Applied migration ${file}.\n`);
  } finally {
    await client.end();
  }
}

run().catch((error) => {
  process.stderr.write(`Migration error: ${error.message}\n`);
  process.exit(1);
});
