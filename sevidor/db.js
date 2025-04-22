const { Pool } = require("pg");
require('dotenv').config();

// Usar variables de entorno con valores por defecto como respaldo
const pool = new Pool({
  user: process.env.PGUSER || 'postgres',
  host: process.env.PGHOST || 'localhost',
  database: process.env.PGDATABASE || 'le_brunch',
  password: process.env.PGPASSWORD || 'postgres',
  port: process.env.PGPORT || 5432,
});

pool.connect()
  .then(() => console.log(`Conectado a PostgreSQL en ${process.env.PGHOST || 'localhost'}`))
  .catch(err => console.error("Error de conexión a PostgreSQL:", err));

module.exports = pool;
