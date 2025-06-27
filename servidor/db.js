const { Pool } = require("pg");

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'lebrunchAPP',
  password: 'mimi0422',
  port: 5432,
});

// Asegurar que PostgreSQL use la zona horaria de Venezuela (GMT-4)
pool.on('connect', client => {
  client.query('SET timezone = "America/Caracas"');
  console.log("🕒 Configuración de zona horaria de PostgreSQL establecida a America/Caracas");
});

pool.connect()
  .then(() => console.log("Conectado a PostgreSQL"))
  .catch(err => console.error("Error de conexión a PostgreSQL:", err));

module.exports = pool;
