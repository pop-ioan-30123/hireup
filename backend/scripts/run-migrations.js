const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

async function run() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error('DATABASE_URL is required');
  }

  const migrationsDir = path.resolve(__dirname, '../../db/migrations');
  const files = fs
    .readdirSync(migrationsDir)
    .filter((name) => name.endsWith('.sql'))
    .sort();

  const client = new Client({ connectionString });
  await client.connect();

  try {
    for (const file of files) {
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
      process.stdout.write(`Running migration ${file}...\n`);
      await client.query(sql);
    }
    process.stdout.write('All migrations completed.\n');
  } finally {
    await client.end();
  }
}

run().catch((error) => {
  process.stderr.write(`Migration error: ${error.message}\n`);
  process.exit(1);
});