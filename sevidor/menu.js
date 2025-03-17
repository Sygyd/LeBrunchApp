const express = require("express");
const pool = require("./db");
const multer = require("multer");
const path = require("path");
const router = express.Router();

// Configuración de multer para guardar archivos en la carpeta "uploads"
const storage = multer.diskStorage({
  destination: "./uploads",
  filename: (req, file, cb) => {
    cb(null, Date.now() + path.extname(file.originalname)); // Nombre único para el archivo
  },
});
const upload = multer({ storage: storage });

// Obtener todos los platos del menú
router.get("/menu", async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM menu");
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Agregar un nuevo plato al menú
router.post("/menu", upload.single("imagen"), async (req, res) => {
  const { nombre, categoria, precio, disponibilidad, ingredientes } = req.body;
  const imagen_url = req.file ? `http://localhost:3000/uploads/${req.file.filename}` : null;

  try {
    const result = await pool.query(
      "INSERT INTO menu (nombre, categoria, precio, disponibilidad, ingredientes, imagen_url) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *",
      [nombre, categoria, precio, disponibilidad, ingredientes, imagen_url]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});



// Ruta para obtener un plato específico por ID
router.get('/menu/:id', async (req, res) => {
  try {
      const { id } = req.params;
      const result = await pool.query('SELECT * FROM menu WHERE idplato = $1', [id]);

      if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Plato no encontrado' });
      }

      res.json(result.rows[0]);
  } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Error al obtener el plato' });
  }
});

// Servir archivos de imagen
router.use("/uploads", express.static("uploads"));

module.exports = router;