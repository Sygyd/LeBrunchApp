require('dotenv').config();
const express = require('express');
const cors = require('cors');
const pool = require('./db');  // Conexión a PostgreSQL desde db.js
const userRoutes = require("./login_register");
const bodyParser = require("body-parser");
const menuRoutes = require("./menu");
const chatRoutes = require("./chat");


const ip = '192.168.1.121';
const port = 3000;

const app = express();

app.use(cors());
app.use(express.json());
app.use(bodyParser.json());
app.use(userRoutes);
app.use(menuRoutes);
app.use(chatRoutes);

(async () => {
  try {
    const result = await pool.query("SELECT NOW()");
    console.log("Conexión a PostgreSQL funcionando:", result.rows[0]);
  } catch (error) {
    console.error("Error en la conexión a PostgreSQL:", error);
  }
})();

app.listen(port, ip, () => {
  console.log(`Servidor corriendo en http://${ip}:${port}`);
});


