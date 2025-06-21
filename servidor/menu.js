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

// Obtener todos los platos del menú (solo los no eliminados)
router.get("/menu", async (req, res) => {
  try {
    const { disponibilidad } = req.query;
    
    let query = "SELECT * FROM menu WHERE isDelete = FALSE";
    const queryParams = [];
    
    // Si se especifica el parámetro disponibilidad, agregarlo al filtro
    if (disponibilidad !== undefined) {
      const isAvailable = disponibilidad === 'true';
      query += " AND disponibilidad = $1";
      queryParams.push(isAvailable);
    }
    
    query += " ORDER BY nombre";
    
    const result = await pool.query(query, queryParams);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Agregar un nuevo plato al menú
router.post("/menu", upload.single("imagen"), async (req, res) => {
  const { nombre, categoria, precio, disponibilidad, ingredientes } = req.body;
  const config = require('./config');
  const imagen_url = req.file ? `${config.getServerUrl()}/uploads/${req.file.filename}` : null;

  try {
    const result = await pool.query(
      "INSERT INTO menu (nombre, categoria, precio, disponibilidad, ingredientes, imagen_url, isDelete) VALUES ($1, $2, $3, $4, $5, $6, FALSE) RETURNING *",
      [nombre, categoria, precio, disponibilidad, ingredientes, imagen_url]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Ruta para obtener un plato específico por ID (solo si no está eliminado)
router.get('/menu/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT * FROM menu WHERE idplato = $1 AND isDelete = FALSE', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Plato no encontrado o ha sido eliminado' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener el plato' });
  }
});

// Actualizar un plato existente (solo si no está eliminado)
router.put("/menu/:id", upload.single("imagen"), async (req, res) => {
  const { id } = req.params;
  const { nombre, categoria, precio, disponibilidad, ingredientes } = req.body;
  const config = require('./config');
  const imagen_url = req.file
    ? `${config.getServerUrl()}/uploads/${req.file.filename}`
    : null;

  try {
    const result = await pool.query(
      "UPDATE menu SET nombre = $1, categoria = $2, precio = $3, disponibilidad = $4, ingredientes = $5, imagen_url = COALESCE($6, imagen_url) WHERE idplato = $7 AND isDelete = FALSE RETURNING *",
      [nombre, categoria, precio, disponibilidad, ingredientes, imagen_url, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Plato no encontrado o ha sido eliminado" });
    }
    
    res.status(200).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Eliminar un plato existente (SOFT DELETE)
router.delete("/menu/:id", async (req, res) => {
  const { id } = req.params;

  try {
    // Obtener información del usuario que está eliminando (si está disponible en el token)
    let deletedBy = null;
    const authHeader = req.headers.authorization;
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const jwt = require('jsonwebtoken');
        const token = authHeader.substring(7);
        const decoded = jwt.verify(token, 'monito');
        deletedBy = decoded.id;
        console.log(`🗑️ Usuario ${deletedBy} eliminando plato ${id}`);
      } catch (tokenError) {
        console.log('⚠️ No se pudo obtener el usuario del token, continuando sin deleted_by');
      }
    }

    // Verificar que el plato existe y no está ya eliminado
    const checkResult = await pool.query(
      "SELECT * FROM menu WHERE idplato = $1 AND isDelete = FALSE", 
      [id]
    );

    if (checkResult.rows.length === 0) {
      return res.status(404).json({ error: "Plato no encontrado o ya ha sido eliminado" });
    }

    // Realizar soft delete
    const result = await pool.query(
      `UPDATE menu 
       SET isDelete = TRUE, 
           deleted_at = NOW(), 
           deleted_by = $2 
       WHERE idplato = $1 AND isDelete = FALSE 
       RETURNING *`,
      [id, deletedBy]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Plato no encontrado" });
    }

    console.log(`✅ Plato ${id} eliminado lógicamente por usuario ${deletedBy || 'desconocido'}`);
    res.status(200).json({ 
      message: "Plato eliminado exitosamente", 
      deletedDish: {
        id: result.rows[0].idplato,
        nombre: result.rows[0].nombre,
        deletedAt: result.rows[0].deleted_at,
        deletedBy: result.rows[0].deleted_by
      }
    });
  } catch (err) {
    console.error('❌ Error al eliminar plato:', err);
    res.status(500).json({ error: err.message });
  }
});

// Verificar si un plato existe en la base de datos (solo los no eliminados)
router.get('/menu/exists/:nombrePlato', async (req, res) => {
  try {
    const { nombrePlato } = req.params;
    
    if (!nombrePlato) {
      return res.status(400).json({ 
        error: 'Se requiere el nombre del plato' 
      });
    }
    
    // Buscar platos con nombre similar (insensible a mayúsculas/minúsculas) que no estén eliminados
    const query = `
      SELECT * FROM menu 
      WHERE LOWER(nombre) LIKE LOWER($1) AND isDelete = FALSE
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

// NUEVO: Endpoint para restaurar un plato eliminado (solo para administradores)
router.patch("/menu/:id/restore", async (req, res) => {
  const { id } = req.params;

  try {
    console.log(`🔄 Iniciando restauración de plato con ID: ${id}`);

    // Verificar que el plato existe y está eliminado
    const checkResult = await pool.query(
      "SELECT * FROM menu WHERE idplato = $1 AND isDelete = TRUE", 
      [id]
    );

    console.log(`🔍 Platos encontrados con isDelete = TRUE: ${checkResult.rows.length}`);
    if (checkResult.rows.length > 0) {
      console.log(`📝 Plato encontrado: ${JSON.stringify(checkResult.rows[0], null, 2)}`);
    }

    if (checkResult.rows.length === 0) {
      // Verificar también si el plato existe pero ya está restaurado
      const alreadyRestoredCheck = await pool.query(
        "SELECT * FROM menu WHERE idplato = $1 AND isDelete = FALSE", 
        [id]
      );
      
      if (alreadyRestoredCheck.rows.length > 0) {
        console.log(`⚠️ Plato ${id} ya está restaurado`);
        return res.status(400).json({ 
          error: "El plato ya está restaurado",
          dish: alreadyRestoredCheck.rows[0]
        });
      }
      
      return res.status(404).json({ error: "Plato no encontrado en elementos eliminados" });
    }

    // Restaurar el plato y establecer disponibilidad como true
    const result = await pool.query(
      `UPDATE menu 
       SET isDelete = FALSE, 
           deleted_at = NULL, 
           deleted_by = NULL,
           disponibilidad = TRUE
       WHERE idplato = $1 
       RETURNING *`,
      [id]
    );

    console.log(`✅ Restauración completada. Filas afectadas: ${result.rowCount}`);
    if (result.rows.length > 0) {
      console.log(`📋 Plato restaurado: ${JSON.stringify(result.rows[0], null, 2)}`);
    }

    // Verificar que el plato ahora aparece en consultas normales
    const verifyResult = await pool.query(
      "SELECT * FROM menu WHERE idplato = $1 AND isDelete = FALSE", 
      [id]
    );
    
    console.log(`🔍 Verificación post-restauración: ${verifyResult.rows.length} platos encontrados`);

    res.status(200).json({ 
      message: "Plato restaurado exitosamente", 
      restoredDish: result.rows[0],
      verification: {
        found: verifyResult.rows.length > 0,
        dish: verifyResult.rows[0]
      }
    });
  } catch (err) {
    console.error('❌ Error al restaurar plato:', err);
    res.status(500).json({ error: err.message });
  }
});

// NUEVO: Endpoint para obtener platos eliminados (solo para administradores)
router.get("/menu/deleted/list", async (req, res) => {
  try {
    console.log('🗑️ Obteniendo lista de platos eliminados...');
    
    const result = await pool.query(
      `SELECT m.*, p.nombre as deleted_by_name, p.apellido as deleted_by_lastname
       FROM menu m
       LEFT JOIN personas p ON m.deleted_by = p.idpersonas
       WHERE m.isDelete = TRUE
       ORDER BY m.deleted_at DESC`
    );
    
    console.log(`📊 Platos eliminados encontrados: ${result.rows.length}`);
    
    // Log adicional para debug
    if (result.rows.length > 0) {
      console.log('📝 Primeros 3 platos eliminados:');
      result.rows.slice(0, 3).forEach((dish, index) => {
        console.log(`  ${index + 1}. ID: ${dish.idplato}, Nombre: ${dish.nombre}, isDelete: ${dish.isdelete}, deleted_at: ${dish.deleted_at}`);
      });
    }
    
    res.json({
      deletedItems: result.rows,
      count: result.rows.length
    });
  } catch (err) {
    console.error('❌ Error al obtener platos eliminados:', err);
    res.status(500).json({ error: err.message });
  }
});

// TEMPORAL: Endpoint de debug para verificar estado de platos
router.get("/menu/debug/:id", async (req, res) => {
  const { id } = req.params;
  
  try {
    console.log(`🔍 Debug: Verificando estado del plato ID: ${id}`);
    
    // Consulta completa sin filtros
    const allStatesResult = await pool.query(
      "SELECT idplato, nombre, categoria, precio, disponibilidad, isdelete, deleted_at, deleted_by FROM menu WHERE idplato = $1", 
      [id]
    );
    
    // Consulta solo eliminados
    const deletedResult = await pool.query(
      "SELECT idplato, nombre, categoria, precio, disponibilidad, isdelete, deleted_at, deleted_by FROM menu WHERE idplato = $1 AND isDelete = TRUE", 
      [id]
    );
    
    // Consulta solo activos
    const activeResult = await pool.query(
      "SELECT idplato, nombre, categoria, precio, disponibilidad, isdelete, deleted_at, deleted_by FROM menu WHERE idplato = $1 AND isDelete = FALSE", 
      [id]
    );
    
    console.log(`📊 Debug resultados para plato ${id}:`);
    console.log(`  - Total encontrados: ${allStatesResult.rows.length}`);
    console.log(`  - Eliminados: ${deletedResult.rows.length}`);
    console.log(`  - Activos: ${activeResult.rows.length}`);
    
    if (allStatesResult.rows.length > 0) {
      console.log(`📝 Estado actual: ${JSON.stringify(allStatesResult.rows[0], null, 2)}`);
    }
    
    res.json({
      dishId: id,
      found: allStatesResult.rows.length > 0,
      totalFound: allStatesResult.rows.length,
      deletedFound: deletedResult.rows.length,
      activeFound: activeResult.rows.length,
      currentState: allStatesResult.rows[0] || null,
      deletedState: deletedResult.rows[0] || null,
      activeState: activeResult.rows[0] || null
    });
  } catch (err) {
    console.error('❌ Error en debug:', err);
    res.status(500).json({ error: err.message });
  }
});

// Servir archivos de imagen
router.use("/uploads", express.static("uploads"));

module.exports = router;