const express = require("express");
const pool = require("./db");
const multer = require("multer");
const path = require("path");
const router = express.Router();

// Obtener URL del servidor desde variables de entorno
const serverIP = process.env.NODE_SERVER_IP || '192.168.1.121';
const serverPort = process.env.NODE_SERVER_PORT || 3000;
const serverUrl = `http://${serverIP}:${serverPort}`;

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
  const imagen_url = req.file ? `${serverUrl}/uploads/${req.file.filename}` : null;

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

// Actualizar un plato existente
router.put("/menu/:id", upload.single("imagen"), async (req, res) => {
  const { id } = req.params;
  const { nombre, categoria, precio, disponibilidad, ingredientes } = req.body;
  const imagen_url = req.file
    ? `${serverUrl}/uploads/${req.file.filename}`
    : null;

  try {
    const result = await pool.query(
      "UPDATE menu SET nombre = $1, categoria = $2, precio = $3, disponibilidad = $4, ingredientes = $5, imagen_url = COALESCE($6, imagen_url) WHERE idplato = $7 RETURNING *",
      [nombre, categoria, precio, disponibilidad, ingredientes, imagen_url, id]
    );
    res.status(200).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Eliminar un plato existente
router.delete("/menu/:id", async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query("DELETE FROM menu WHERE idplato = $1 RETURNING *", [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Plato no encontrado" });
    }

    res.status(200).json({ message: "Plato eliminado exitosamente", deletedDish: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Verificar si un plato existe en la base de datos
router.get('/menu/exists/:nombrePlato', async (req, res) => {
  try {
    const { nombrePlato } = req.params;
    
    if (!nombrePlato) {
      return res.status(400).json({ 
        error: 'Se requiere el nombre del plato' 
      });
    }
    
    // Buscar platos con nombre similar (insensible a mayúsculas/minúsculas)
    const query = `
      SELECT * FROM menu 
      WHERE LOWER(nombre) LIKE LOWER($1)
    `;
    
    const result = await pool.query(query, [`%${nombrePlato}%`]);
    
    return res.status(200).json({
      exists: result.rows.length > 0,
      count: result.rows.length,
      matches: result.rows,
    });
  } catch (err) {
    console.error('Error al verificar existencia de plato:', err);
    res.status(500).json({ error: err.message });
  }
});

// Servir archivos de imagen
router.use("/uploads", express.static("uploads"));

module.exports = router;