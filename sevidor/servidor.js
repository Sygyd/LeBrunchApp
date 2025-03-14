require('dotenv').config();
const express = require('express');
const cors = require('cors');
const pool = require('./db');  // Conexión a PostgreSQL desde db.js
const userRoutes = require("./login_register");
const bodyParser = require("body-parser");
const menuRoutes = require("./menu");
const router = require('./login_register');



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

router.post('/add-dish', async (req, res) => {
  const { nombre, categoria, precio, disponibilidad, ingredientes, imagen_url } = req.body;

  try {
    const result = await pool.query(
      'INSERT INTO menu (nombre, categoria, precio, disponibilidad, ingredientes, imagen_url) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [
        nombre,
        categoria,
        precio,
        disponibilidad,
        JSON.stringify(ingredientes), // Guardar como JSON
        imagen_url
      ]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error al insertar el plato:', err);
    res.status(500).json({ message: 'Error interno del servidor' });
  }
});

