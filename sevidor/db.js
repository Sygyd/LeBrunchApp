const { Pool } = require("pg");

// Obtener configuración de la base de datos desde variables de entorno
const dbHost = process.env.DB_HOST || 'localhost';
const dbPort = process.env.DB_PORT || 5432;
const dbUser = process.env.DB_USER || 'postgres';
const dbPassword = process.env.DB_PASSWORD || 'monito';
const dbName = process.env.DB_NAME || 'postgres';

// Configurar la conexión a la base de datos
const pool = new Pool({
  user: dbUser,
  host: dbHost,
  database: dbName,
  password: dbPassword,
  port: dbPort,
});

// Intentar conectar a la base de datos
pool.connect()
  .then(() => console.log(`Conectado a PostgreSQL en ${dbHost}:${dbPort}`))
  .catch(err => console.error("Error de conexión a PostgreSQL:", err));

// Log para depuración
console.log(`Configuración de BD: ${dbHost}:${dbPort} (${dbUser}@${dbName})`);

module.exports = pool;
