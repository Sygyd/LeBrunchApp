require('dotenv').config();
const express = require('express');
const cors = require('cors');
const pool = require('./db');  // Conexión a PostgreSQL desde db.js
const userRoutes = require("./login_register");
const bodyParser = require("body-parser");
const menuRoutes = require("./menu");



const app = express();
app.use(cors());
app.use(express.json());
app.use(bodyParser.json());
app.use(userRoutes);
app.use(menuRoutes);

(async () => {
  try {
    const result = await pool.query("SELECT NOW()");
    console.log("Conexión a PostgreSQL funcionando:", result.rows[0]);
  } catch (error) {
    console.error("Error en la conexión a PostgreSQL:", error);
  }
})();

app.listen(3000, '0.0.0.0', () => {
  console.log("Servidor corriendo en http://0.0.0.0:3000");
});
