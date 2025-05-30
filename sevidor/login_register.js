const express = require("express");
const router = express.Router(); // 💡 Aquí defines router
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const pool = require("./db");
const { createUser } = require("./user");

router.post("/register", async (req, res) => {
  try {
    const { nombre, apellido, cedula, email, contrasena, rol } = req.body;

    if (!nombre || !apellido || !cedula || !email || !contrasena) {
      return res.status(400).json({ error: "Todos los campos son obligatorios" });
    }

    // Usamos el rol proporcionado o 1 (cliente) por defecto
    const rolToUse = rol || "1";
    console.log(`Registrando usuario con rol: ${rolToUse}`);

    const newUser = await createUser(nombre, apellido, cedula, email, contrasena, rolToUse);
    return res.status(201).json({ message: "Usuario registrado con éxito", user: newUser });

  } catch (error) {
    console.error("Error al registrar usuario:", error);
    return res.status(500).json({ error: "Error en el servidor" });
  }
});

// Nuevo endpoint para obtener todos los usuarios (solo los no eliminados)
router.get("/users", async (req, res) => {
  try {
    console.log('📋 Solicitud recibida en /users');
    
    const { rows } = await pool.query(
      `SELECT u.idpersona as id, p.nombre, p.apellido, p.cedula, p.email, u.rol
       FROM usuario u
       INNER JOIN personas p ON u.idpersona = p.idpersonas
       WHERE p.isDelete = FALSE
       ORDER BY p.nombre ASC`
    );
    
    console.log(`👥 Usuarios recuperados de la base de datos: ${rows.length}`);
    
    // Verificar los roles antes de devolver
    const usersWithProcessedRoles = rows.map(user => {
      // Ver el rol original
      console.log(`👤 Usuario ${user.nombre} ${user.apellido}, rol original: ${user.rol} (${typeof user.rol})`);
      
      // Intentar convertir a número si es string
      let rolFinal;
      if (typeof user.rol === 'string') {
        if (/^\d+$/.test(user.rol)) {
          // Es un string numérico, convertir a número
          rolFinal = parseInt(user.rol, 10);
        } else {
          // Es un string no numérico, mapear según el valor
          switch(user.rol.toLowerCase()) {
            case 'admin': rolFinal = 0; break;
            case 'client': case 'cliente': rolFinal = 1; break;
            case 'cook': case 'cocinero': rolFinal = 2; break;
            case 'barista': rolFinal = 3; break;
            default: rolFinal = 1; // Por defecto, cliente
          }
        }
      } else {
        // Ya es un número u otro tipo
        rolFinal = user.rol;
      }
      
      console.log(`   ➡️ Rol procesado: ${rolFinal} (${typeof rolFinal})`);
      
      return {
        ...user,
        rol: rolFinal
      };
    });
    
    console.log('✅ Respuesta enviada al cliente');
    return res.status(200).json(usersWithProcessedRoles);
  } catch (error) {
    console.error("❌ Error al obtener usuarios:", error);
    return res.status(500).json({ error: "Error al obtener usuarios del servidor" });
  }
});

// Endpoint para obtener métricas de usuarios (solo los no eliminados)
router.get("/users/metrics", async (req, res) => {
  try {
    console.log('📊 Solicitud de métricas de usuarios recibida');
    
    // Obtener conteo total de usuarios no eliminados
    const totalResult = await pool.query(
      `SELECT COUNT(*) as total FROM usuario u
       INNER JOIN personas p ON u.idpersona = p.idpersonas
       WHERE p.isDelete = FALSE`
    );
    const totalUsers = parseInt(totalResult.rows[0].total);
    
    // Obtener conteo de usuarios por rol (solo los no eliminados)
    const rolesResult = await pool.query(
      `SELECT 
        COUNT(CASE WHEN u.rol = '0' OR u.rol = 'admin' THEN 1 END) as admins,
        COUNT(CASE WHEN u.rol = '1' OR u.rol = 'client' OR u.rol = 'cliente' THEN 1 END) as clients,
        COUNT(CASE WHEN u.rol = '2' OR u.rol = 'cook' OR u.rol = 'cocinero' THEN 1 END) as cooks,
        COUNT(CASE WHEN u.rol = '3' OR u.rol = 'barista' THEN 1 END) as baristas
       FROM usuario u
       INNER JOIN personas p ON u.idpersona = p.idpersonas
       WHERE p.isDelete = FALSE`
    );
    
    const metrics = {
      total: totalUsers,
      byRole: {
        admins: parseInt(rolesResult.rows[0].admins),
        clients: parseInt(rolesResult.rows[0].clients),
        cooks: parseInt(rolesResult.rows[0].cooks),
        baristas: parseInt(rolesResult.rows[0].baristas)
      }
    };
    
    console.log('✅ Métricas de usuarios enviadas:', metrics);
    return res.status(200).json(metrics);
  } catch (error) {
    console.error("❌ Error al obtener métricas de usuarios:", error);
    return res.status(500).json({ 
      error: "Error al obtener métricas de usuarios del servidor",
      details: error.message 
    });
  }
});

// Obtener un usuario específico por ID (solo si no está eliminado)
router.get("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await pool.query(
      `SELECT u.idpersona as id, p.nombre, p.apellido, p.cedula, p.email, 
              CASE 
                WHEN u.rol = 'admin' THEN 0
                WHEN u.rol = 'client' THEN 1
                WHEN u.rol = 'cook' THEN 2
                WHEN u.rol = 'barista' THEN 3
                ELSE CASE
                  WHEN u.rol ~ E'^\\d+$' THEN CAST(u.rol AS INTEGER)
                  ELSE 1
                END
              END as rol
       FROM usuario u
       INNER JOIN personas p ON u.idpersona = p.idpersonas
       WHERE u.idpersona = $1 AND p.isDelete = FALSE`,
      [id]
    );
    
    if (rows.length === 0) {
      return res.status(404).json({ error: "Usuario no encontrado o ha sido eliminado" });
    }
    
    return res.status(200).json(rows[0]);
  } catch (error) {
    console.error("Error al obtener usuario:", error);
    return res.status(500).json({ error: "Error al obtener usuario del servidor" });
  }
});

router.post("/login", async (req, res) => {
  try {
    const { email, contrasena } = req.body;

    console.log(`📧 Intento de login con email: ${email}`);

    // Validación de los datos de entrada
    if (!email || !contrasena) {
      return res.status(400).json({ error: "Por favor, ingrese ambos campos." });
    }

    // Consulta en la base de datos (solo usuarios no eliminados)
    const { rows } = await pool.query(
      `SELECT u.contrasena, u.idpersona, u.rol, p.nombre, p.apellido, p.cedula, p.email
       FROM usuario u
       INNER JOIN personas p ON u.idpersona = p.idpersonas
       WHERE p.email = $1 AND p.isDelete = FALSE`,
      [email]
    );

    if (rows.length === 0) {
      console.log(`❌ Login fallido: email no encontrado o usuario eliminado: ${email}`);
      return res.status(401).json({ error: "Credenciales incorrectas" });
    }

    const usuario = rows[0];
    console.log(`👤 Usuario encontrado: ${usuario.nombre} ${usuario.apellido}, email: ${usuario.email}`);
    console.log(`👤 Rol en la base de datos: ${usuario.rol} (tipo: ${typeof usuario.rol})`);

    // Comparación de la contraseña
    console.log(`🔐 Contraseña encriptada en BD: ${usuario.contrasena.substring(0, 15)}...`);
    console.log(`🔐 Contraseña ingresada: ${contrasena.slice(0, 3)}${'*'.repeat(contrasena.length - 3)}`);
    
    try {
    const passwordMatch = await bcrypt.compare(contrasena, usuario.contrasena);
      console.log(`🔍 Resultado de comparación de contraseñas: ${passwordMatch ? '✅ Coincide' : '❌ No coincide'}`);

    if (!passwordMatch) {
        console.log(`❌ Login fallido: contraseña incorrecta para ${email}`);
      return res.status(401).json({ error: "Credenciales incorrectas" });
    }
    } catch (bcryptError) {
      console.error(`❌ Error en la comparación de contraseñas: ${bcryptError}`);
      return res.status(500).json({ error: "Error en la verificación de credenciales" });
    }

    // Asegurar que el rol esté en un formato válido
    let rolProcessed = usuario.rol;
    
    // Si el rol es string, procesarlo apropiadamente
    if (typeof rolProcessed === 'string') {
      // Si es un número en formato string, convertirlo a entero
      if (/^\d+$/.test(rolProcessed)) {
        rolProcessed = parseInt(rolProcessed, 10);
      } else {
        // Si es texto, mapearlo a valores numéricos
        switch(rolProcessed.toLowerCase()) {
          case 'admin': rolProcessed = 0; break;
          case 'client': case 'cliente': rolProcessed = 1; break;
          case 'cook': case 'cocinero': rolProcessed = 2; break;
          case 'barista': rolProcessed = 3; break;
          default: rolProcessed = 1; // Por defecto, cliente
        }
      }
    }

    console.log(`👤 Rol procesado: ${rolProcessed} (tipo: ${typeof rolProcessed})`);

    // Generar el token JWT
    const token = jwt.sign(
      { id: usuario.idpersona, rol: rolProcessed },
      'monito',
      { expiresIn: '1h' }
    );

    console.log(`✅ Login exitoso para: ${email}, rol: ${rolProcessed}`);

    // Respuesta con el token y los datos del usuario
    return res.json({
      token,
      id: usuario.idpersona,
      nombre: usuario.nombre,
      apellido: usuario.apellido,
      cedula: usuario.cedula,
      rol: rolProcessed, // Enviar el rol procesado como número
    });

  } catch (error) {
    console.error("❌ Error en login:", error);
    return res.status(500).json({ error: "Error en el servidor" });
  }
});

router.post("/logout", (req, res) => {
  try {
    // Aquí puedes invalidar el token si es necesario
    // Por ejemplo, podrías agregar el token a una lista negra si estás usando JWT

    // Respuesta exitosa
    return res.status(200).json({ message: "Sesión cerrada exitosamente" });
  } catch (error) {
    console.error("Error al cerrar sesión:", error);
    return res.status(500).json({ error: "Error en el servidor" });
  }
});

// Nuevo endpoint para verificar credenciales y recuperar contraseña (solo usuarios no eliminados)
router.post("/verify-reset-password", async (req, res) => {
  try {
    const { email, cedula } = req.body;

    // Validar datos de entrada
    if (!email || !cedula) {
      return res.status(400).json({ error: "Correo electrónico y cédula son obligatorios" });
    }

    // Buscar al usuario por email y cédula (solo si no está eliminado)
    const { rows } = await pool.query(
      `SELECT p.idpersonas, p.nombre, p.apellido, p.email
       FROM personas p
       WHERE p.email = $1 AND p.cedula = $2 AND p.isDelete = FALSE`,
      [email, cedula]
    );

    // Si no se encuentra el usuario con esas credenciales
    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "No encontramos una cuenta con esos datos. Por favor verifica la información."
      });
    }

    const usuario = rows[0];

    // En un escenario real, aquí enviarías un correo electrónico con un enlace para cambiar
    // la contraseña. El enlace podría contener un token JWT con tiempo de expiración corto.

    // Generamos un token temporal para restablecimiento (esto es una simulación)
    const resetToken = jwt.sign(
      { id: usuario.idpersonas, action: 'reset_password' },
      'monito_reset',
      { expiresIn: '15m' } // Token válido por 15 minutos
    );

    // Aquí normalmente guardarías este token en la base de datos asociado al usuario
    // y enviarías un correo electrónico con un enlace que contenga el token

    console.log(`Solicitud de restablecimiento para ${usuario.email} con token: ${resetToken}`);

    // Respuesta exitosa con el ID del usuario para el siguiente paso
    return res.status(200).json({
      success: true,
      userId: usuario.idpersonas,
      message: "Credenciales verificadas correctamente. Ahora puedes establecer tu nueva contraseña."
    });

  } catch (error) {
    console.error("Error al verificar credenciales para recuperación:", error);
    return res.status(500).json({
      success: false,
      message: "Error al procesar la solicitud de recuperación de contraseña."
    });
  }
});

// NUEVO: Endpoint para cambiar la contraseña después de verificar credenciales
router.post("/reset-password", async (req, res) => {
  try {
    const { userId, newPassword } = req.body;

    // Validar datos de entrada
    if (!userId || !newPassword) {
      return res.status(400).json({ 
        success: false,
        message: "ID de usuario y nueva contraseña son obligatorios" 
      });
    }

    // Validar que la contraseña tenga al menos 6 caracteres
    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: "La contraseña debe tener al menos 6 caracteres"
      });
    }

    console.log(`🔐 Cambiando contraseña para usuario ID: ${userId}`);

    // Verificar que el usuario existe y no está eliminado
    const userCheck = await pool.query(
      `SELECT p.idpersonas, p.nombre, p.apellido, p.email 
       FROM personas p
       INNER JOIN usuario u ON p.idpersonas = u.idpersona
       WHERE p.idpersonas = $1 AND p.isDelete = FALSE`,
      [userId]
    );

    if (userCheck.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Usuario no encontrado o ha sido eliminado"
      });
    }

    const userData = userCheck.rows[0];

    // Hashear la nueva contraseña
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    console.log(`🔑 Nueva contraseña hasheada para usuario: ${userData.nombre} ${userData.apellido}`);

    // Actualizar la contraseña en la base de datos
    const updateResult = await pool.query(
      `UPDATE usuario 
       SET contrasena = $1 
       WHERE idpersona = $2 
       RETURNING idpersona`,
      [hashedPassword, userId]
    );

    if (updateResult.rows.length === 0) {
      return res.status(500).json({
        success: false,
        message: "Error al actualizar la contraseña"
      });
    }

    console.log(`✅ Contraseña actualizada exitosamente para usuario: ${userData.nombre} ${userData.apellido}`);

    return res.status(200).json({
      success: true,
      message: "Tu contraseña ha sido actualizada exitosamente. Ya puedes iniciar sesión con tu nueva contraseña."
    });

  } catch (error) {
    console.error("❌ Error al cambiar contraseña:", error);
    return res.status(500).json({
      success: false,
      message: "Error al procesar el cambio de contraseña."
    });
  }
});

// Endpoint para eliminar un usuario (SOFT DELETE)
router.delete("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    console.log(`🗑️ Solicitud para eliminar usuario con ID: ${id}`);
    
    // Obtener el token de autorización de los headers
    const authHeader = req.headers.authorization;
    let userIdFromToken = null;
    let deletedBy = null;
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        // Verificar y decodificar el token
        const decoded = jwt.verify(authHeader.substring(7), 'monito');
        userIdFromToken = decoded.id;
        deletedBy = decoded.id;
        console.log(`👤 Usuario autenticado ID: ${userIdFromToken}`);
        
        // Si intenta eliminarse a sí mismo
        if (userIdFromToken.toString() === id.toString()) {
          return res.status(403).json({ 
            success: false,
            message: "No puedes eliminar tu propia cuenta mientras estás logueado"
          });
        }
      } catch (tokenError) {
        console.error("❌ Error al verificar token:", tokenError);
        // Si hay error de token, continuamos pero sin userIdFromToken
      }
    }
    
    // Iniciar una transacción para asegurar la integridad
    await pool.query('BEGIN');
    
    // Verificar si el usuario existe y no está ya eliminado
    const userCheck = await pool.query(
      `SELECT p.*, u.rol FROM personas p
       INNER JOIN usuario u ON p.idpersonas = u.idpersona
       WHERE p.idpersonas = $1 AND p.isDelete = FALSE`,
      [id]
    );
    
    if (userCheck.rows.length === 0) {
      await pool.query('ROLLBACK');
      return res.status(404).json({ 
        success: false,
        message: "Usuario no encontrado o ya ha sido eliminado"
      });
    }

    const userData = userCheck.rows[0];
    
    // Realizar soft delete en la tabla personas
    const deletePersonResult = await pool.query(
      `UPDATE personas 
       SET isDelete = TRUE, 
           deleted_at = NOW(), 
           deleted_by = $2 
       WHERE idpersonas = $1 AND isDelete = FALSE 
       RETURNING nombre, apellido`,
      [id, deletedBy]
    );
    
    if (deletePersonResult.rows.length === 0) {
      await pool.query('ROLLBACK');
      return res.status(404).json({ 
        success: false,
        message: "Usuario no encontrado"
      });
    }
    
    // Confirmar la transacción
    await pool.query('COMMIT');
    
    console.log(`✅ Usuario eliminado lógicamente con éxito: ${deletePersonResult.rows[0]?.nombre} ${deletePersonResult.rows[0]?.apellido} por usuario ${deletedBy || 'desconocido'}`);
    
    return res.status(200).json({
      success: true,
      message: "Usuario eliminado con éxito",
      deletedUser: {
        id: id,
        nombre: deletePersonResult.rows[0]?.nombre,
        apellido: deletePersonResult.rows[0]?.apellido,
        deletedBy: deletedBy
      }
    });
    
  } catch (error) {
    // Si hay un error, revertir la transacción
    await pool.query('ROLLBACK');
    console.error("❌ Error al eliminar usuario:", error);
    return res.status(500).json({ 
      success: false,
      message: "Error al eliminar el usuario",
      error: error.message
    });
  }
});

// Endpoint para actualizar la información de un usuario (solo si no está eliminado)
router.put("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { nombre, apellido, cedula, email, rol, contrasena } = req.body;
    
    console.log(`📝 Solicitud para actualizar usuario con ID: ${id}`);
    console.log(`Datos recibidos:`, req.body);
    
    // Validación básica
    if (!nombre && !apellido && !cedula && !email && !rol && !contrasena) {
      return res.status(400).json({ 
        success: false,
        message: "No se proporcionaron datos para actualizar"
      });
    }
    
    // Iniciar una transacción para asegurar la integridad
    await pool.query('BEGIN');
    
    // Verificar si el usuario existe y no está eliminado
    const checkUser = await pool.query(
      `SELECT u.idpersona FROM usuario u
       INNER JOIN personas p ON u.idpersona = p.idpersonas
       WHERE u.idpersona = $1 AND p.isDelete = FALSE`,
      [id]
    );
    
    if (checkUser.rows.length === 0) {
      await pool.query('ROLLBACK');
      return res.status(404).json({ 
        success: false,
        message: "Usuario no encontrado o ha sido eliminado"
      });
    }
    
    // Actualizar datos personales en la tabla personas
    if (nombre || apellido || cedula || email) {
      let updatePersonaQuery = 'UPDATE personas SET';
      const updateValues = [];
      const queryParams = [];
      
      if (nombre) {
        updateValues.push(` nombre = $${updateValues.length + 1}`);
        queryParams.push(nombre);
      }
      
      if (apellido) {
        updateValues.push(` apellido = $${updateValues.length + 1}`);
        queryParams.push(apellido);
      }
      
      if (cedula) {
        updateValues.push(` cedula = $${updateValues.length + 1}`);
        queryParams.push(cedula);
      }
      
      if (email) {
        updateValues.push(` email = $${updateValues.length + 1}`);
        queryParams.push(email);
      }
      
      updatePersonaQuery += updateValues.join(',');
      updatePersonaQuery += ` WHERE idpersonas = $${queryParams.length + 1} AND isDelete = FALSE RETURNING *`;
      queryParams.push(id);
      
      const updatePersonaResult = await pool.query(updatePersonaQuery, queryParams);
      console.log(`✅ Información personal actualizada:`, updatePersonaResult.rows[0]);
    }
    
    // Actualizar el rol y/o la contraseña si se proporcionaron
    if (rol || contrasena) {
      let updateUserQuery = 'UPDATE usuario SET';
      const updateValues = [];
      const queryParams = [];
      
    if (rol) {
      // Validar que el rol sea válido
      let rolToSave = rol;
      // Si rol no está entre los valores válidos, usar 1 (cliente) como predeterminado
      if (!["0", "1", "2", "3"].includes(rol.toString())) {
        console.warn(`⚠️ Rol no válido: "${rol}", usando rol predeterminado (1)`);
        rolToSave = "1";
      }
      
        updateValues.push(` rol = $${updateValues.length + 1}`);
        queryParams.push(rolToSave);
        console.log(`✅ Rol actualizado a: ${rolToSave}`);
      }
      
      if (contrasena) {
        // Hashear la contraseña antes de guardarla
        const bcrypt = require("bcrypt");
        const hashedPassword = await bcrypt.hash(contrasena, 10);
        
        updateValues.push(` contrasena = $${updateValues.length + 1}`);
        queryParams.push(hashedPassword);
        console.log(`🔐 Contraseña actualizada para el usuario ID: ${id}`);
      }
      
      if (updateValues.length > 0) {
        updateUserQuery += updateValues.join(',');
        updateUserQuery += ` WHERE idpersona = $${queryParams.length + 1} RETURNING *`;
        queryParams.push(id);
      
        const updateUserResult = await pool.query(updateUserQuery, queryParams);
      }
    }
    
    // Confirmar la transacción
    await pool.query('COMMIT');
    
    // Obtener los datos actualizados del usuario
    const updatedUser = await pool.query(
      `SELECT u.idpersona as id, p.nombre, p.apellido, p.cedula, p.email, u.rol
       FROM usuario u
       INNER JOIN personas p ON u.idpersona = p.idpersonas
       WHERE u.idpersona = $1 AND p.isDelete = FALSE`,
      [id]
    );
    
    // Procesar el rol para devolverlo como entero
    let rolFinal = updatedUser.rows[0].rol;
    if (typeof rolFinal === 'string') {
      if (/^\d+$/.test(rolFinal)) {
        rolFinal = parseInt(rolFinal, 10);
      } else {
        switch(rolFinal.toLowerCase()) {
          case 'admin': rolFinal = 0; break;
          case 'client': case 'cliente': rolFinal = 1; break;
          case 'cook': case 'cocinero': rolFinal = 2; break;
          case 'barista': rolFinal = 3; break;
          default: rolFinal = 1; // Por defecto, cliente
        }
      }
    }
    
    updatedUser.rows[0].rol = rolFinal;
    
    return res.status(200).json({
      success: true,
      message: "Usuario actualizado con éxito",
      user: updatedUser.rows[0]
    });
    
  } catch (error) {
    // Si hay un error, revertir la transacción
    await pool.query('ROLLBACK');
    console.error("❌ Error al actualizar usuario:", error);
    return res.status(500).json({ 
      success: false,
      message: "Error al actualizar la información del usuario",
      error: error.message
    });
  }
});

// NUEVO: Endpoint para restaurar un usuario eliminado (solo para administradores)
router.patch("/users/:id/restore", async (req, res) => {
  try {
    const { id } = req.params;
    console.log(`🔄 Solicitud para restaurar usuario con ID: ${id}`);
    
    // Verificar que el usuario existe y está eliminado
    const checkResult = await pool.query(
      `SELECT p.*, u.rol FROM personas p
       INNER JOIN usuario u ON p.idpersonas = u.idpersona
       WHERE p.idpersonas = $1 AND p.isDelete = TRUE`, 
      [id]
    );

    if (checkResult.rows.length === 0) {
      return res.status(404).json({ 
        success: false,
        message: "Usuario no encontrado en elementos eliminados" 
      });
    }

    // Restaurar el usuario
    const result = await pool.query(
      `UPDATE personas 
       SET isDelete = FALSE, 
           deleted_at = NULL, 
           deleted_by = NULL 
       WHERE idpersonas = $1 
       RETURNING *`,
      [id]
    );

    console.log(`✅ Usuario ${id} restaurado exitosamente`);
    return res.status(200).json({ 
      success: true,
      message: "Usuario restaurado exitosamente", 
      restoredUser: {
        id: result.rows[0].idpersonas,
        nombre: result.rows[0].nombre,
        apellido: result.rows[0].apellido,
        email: result.rows[0].email
      }
    });
  } catch (error) {
    console.error('❌ Error al restaurar usuario:', error);
    return res.status(500).json({ 
      success: false,
      message: "Error al restaurar el usuario",
      error: error.message 
    });
  }
});

// NUEVO: Endpoint para obtener usuarios eliminados (solo para administradores)
router.get("/users/deleted/list", async (req, res) => {
  try {
    console.log('📋 Solicitud de usuarios eliminados recibida');
    
    const result = await pool.query(
      `SELECT p.idpersonas as id, p.nombre, p.apellido, p.cedula, p.email, 
              u.rol, p.deleted_at, p.deleted_by,
              deleter.nombre as deleted_by_name, deleter.apellido as deleted_by_lastname
       FROM personas p
       INNER JOIN usuario u ON p.idpersonas = u.idpersona
       LEFT JOIN personas deleter ON p.deleted_by = deleter.idpersonas
       WHERE p.isDelete = TRUE
       ORDER BY p.deleted_at DESC`
    );
    
    // Procesar roles como en el endpoint principal
    const processedUsers = result.rows.map(user => {
      let rolFinal = user.rol;
      if (typeof rolFinal === 'string') {
        if (/^\d+$/.test(rolFinal)) {
          rolFinal = parseInt(rolFinal, 10);
        } else {
          switch(rolFinal.toLowerCase()) {
            case 'admin': rolFinal = 0; break;
            case 'client': case 'cliente': rolFinal = 1; break;
            case 'cook': case 'cocinero': rolFinal = 2; break;
            case 'barista': rolFinal = 3; break;
            default: rolFinal = 1;
          }
        }
      }
      
      return {
        ...user,
        rol: rolFinal
      };
    });
    
    console.log(`📋 ${processedUsers.length} usuarios eliminados encontrados`);
    
    return res.status(200).json({
      deletedUsers: processedUsers,
      count: processedUsers.length
    });
  } catch (error) {
    console.error("❌ Error al obtener usuarios eliminados:", error);
    return res.status(500).json({ 
      error: "Error al obtener usuarios eliminados del servidor",
      details: error.message 
    });
  }
});

module.exports = router;
