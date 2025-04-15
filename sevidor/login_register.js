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

// Nuevo endpoint para obtener todos los usuarios
router.get("/users", async (req, res) => {
  try {
    console.log('📋 Solicitud recibida en /users');
    
    const { rows } = await pool.query(
      `SELECT u.idpersona as id, p.nombre, p.apellido, p.cedula, p.email, u.rol
       FROM usuario u
       INNER JOIN personas p ON u.idpersona = p.idpersonas
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

// Endpoint para obtener métricas de usuarios
router.get("/users/metrics", async (req, res) => {
  try {
    console.log('📊 Solicitud de métricas de usuarios recibida');
    
    // Obtener conteo total de usuarios
    const totalResult = await pool.query(
      `SELECT COUNT(*) as total FROM usuario`
    );
    const totalUsers = parseInt(totalResult.rows[0].total);
    
    // Obtener conteo de usuarios por rol
    const rolesResult = await pool.query(
      `SELECT 
        COUNT(CASE WHEN rol = '0' OR rol = 'admin' THEN 1 END) as admins,
        COUNT(CASE WHEN rol = '1' OR rol = 'client' OR rol = 'cliente' THEN 1 END) as clients,
        COUNT(CASE WHEN rol = '2' OR rol = 'cook' OR rol = 'cocinero' THEN 1 END) as cooks,
        COUNT(CASE WHEN rol = '3' OR rol = 'barista' THEN 1 END) as baristas
       FROM usuario`
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

// Obtener un usuario específico por ID
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
       WHERE u.idpersona = $1`,
      [id]
    );
    
    if (rows.length === 0) {
      return res.status(404).json({ error: "Usuario no encontrado" });
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

    // Validación de los datos de entrada
    if (!email || !contrasena) {
      return res.status(400).json({ error: "Por favor, ingrese ambos campos." });
    }

    // Consulta en la base de datos
    const { rows } = await pool.query(
      `SELECT u.contrasena, u.idpersona, u.rol, p.nombre, p.apellido, p.cedula
       FROM usuario u
       INNER JOIN personas p ON u.idpersona = p.idpersonas
       WHERE p.email = $1`,
      [email]
    );

    if (rows.length === 0) {
      return res.status(401).json({ error: "Credenciales incorrectas" });
    }

    const usuario = rows[0];

    // Comparación de la contraseña
    const passwordMatch = await bcrypt.compare(contrasena, usuario.contrasena);

    if (!passwordMatch) {
      return res.status(401).json({ error: "Credenciales incorrectas" });
    }

    // Generar el token JWT
    const token = jwt.sign(
      { id: usuario.idpersona, rol: usuario.rol },
      'monito',
      { expiresIn: '1h' }
    );

    // Respuesta con el token y los datos del usuario
    return res.json({
      token,
      id: usuario.idpersona,
      nombre: usuario.nombre,
      apellido: usuario.apellido,
      cedula: usuario.cedula,
      rol: usuario.rol, // Aquí devuelves el rol del usuario
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

// Nuevo endpoint para verificar credenciales y recuperar contraseña
router.post("/verify-reset-password", async (req, res) => {
  try {
    const { email, cedula } = req.body;

    // Validar datos de entrada
    if (!email || !cedula) {
      return res.status(400).json({ error: "Correo electrónico y cédula son obligatorios" });
    }

    // Buscar al usuario por email y cédula
    const { rows } = await pool.query(
      `SELECT p.idpersonas, p.nombre, p.apellido, p.email
       FROM personas p
       WHERE p.email = $1 AND p.cedula = $2`,
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

    // Respuesta exitosa simulando envío de correo
    return res.status(200).json({
      success: true,
      message: "Te hemos enviado un correo con instrucciones para restablecer tu contraseña."
    });

  } catch (error) {
    console.error("Error al verificar credenciales para recuperación:", error);
    return res.status(500).json({
      success: false,
      message: "Error al procesar la solicitud de recuperación de contraseña."
    });
  }
});

// Endpoint para eliminar un usuario
router.delete("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    console.log(`🗑️ Solicitud para eliminar usuario con ID: ${id}`);
    
    // Obtener el token de autorización de los headers
    const authHeader = req.headers.authorization;
    let userIdFromToken = null;
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7); // Quitar 'Bearer ' del inicio
      try {
        // Verificar y decodificar el token
        const decoded = jwt.verify(token, 'monito');
        userIdFromToken = decoded.id;
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
    
    // Verificar si el usuario existe
    const userCheck = await pool.query(
      `SELECT * FROM usuario WHERE idpersona = $1`,
      [id]
    );
    
    if (userCheck.rows.length === 0) {
      await pool.query('ROLLBACK');
      return res.status(404).json({ 
        success: false,
        message: "Usuario no encontrado"
      });
    }
    
    // Eliminar el usuario y persona asociada
    const deleteUserResult = await pool.query(
      'DELETE FROM usuario WHERE idpersona = $1 RETURNING idpersona',
      [id]
    );
    
    if (deleteUserResult.rows.length === 0) {
      await pool.query('ROLLBACK');
      return res.status(404).json({ 
        success: false,
        message: "Usuario no encontrado"
      });
    }
    
    // Si se eliminó el usuario, proceder a eliminar la persona
    const deletePersonResult = await pool.query(
      'DELETE FROM personas WHERE idpersonas = $1 RETURNING nombre, apellido',
      [id]
    );
    
    // Confirmar la transacción
    await pool.query('COMMIT');
    
    console.log(`✅ Usuario eliminado con éxito: ${deletePersonResult.rows[0]?.nombre} ${deletePersonResult.rows[0]?.apellido}`);
    
    return res.status(200).json({
      success: true,
      message: "Usuario eliminado con éxito",
      deletedUser: {
        id: id,
        nombre: deletePersonResult.rows[0]?.nombre,
        apellido: deletePersonResult.rows[0]?.apellido
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

// Endpoint para actualizar la información de un usuario
router.put("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { nombre, apellido, cedula, email, rol } = req.body;
    
    console.log(`📝 Solicitud para actualizar usuario con ID: ${id}`);
    console.log(`Datos recibidos:`, req.body);
    
    // Validación básica
    if (!nombre && !apellido && !cedula && !email && !rol) {
      return res.status(400).json({ 
        success: false,
        message: "No se proporcionaron datos para actualizar"
      });
    }
    
    // Iniciar una transacción para asegurar la integridad
    await pool.query('BEGIN');
    
    // Verificar si el usuario existe
    const checkUser = await pool.query(
      'SELECT idpersona FROM usuario WHERE idpersona = $1',
      [id]
    );
    
    if (checkUser.rows.length === 0) {
      await pool.query('ROLLBACK');
      return res.status(404).json({ 
        success: false,
        message: "Usuario no encontrado"
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
      updatePersonaQuery += ` WHERE idpersonas = $${queryParams.length + 1} RETURNING *`;
      queryParams.push(id);
      
      const updatePersonaResult = await pool.query(updatePersonaQuery, queryParams);
      console.log(`✅ Información personal actualizada:`, updatePersonaResult.rows[0]);
    }
    
    // Actualizar el rol si se proporcionó
    if (rol) {
      // Validar que el rol sea válido
      let rolToSave = rol;
      // Si rol no está entre los valores válidos, usar 1 (cliente) como predeterminado
      if (!["0", "1", "2", "3"].includes(rol.toString())) {
        console.warn(`⚠️ Rol no válido: "${rol}", usando rol predeterminado (1)`);
        rolToSave = "1";
      }
      
      const updateRolResult = await pool.query(
        'UPDATE usuario SET rol = $1 WHERE idpersona = $2 RETURNING *',
        [rolToSave, id]
      );
      
      console.log(`✅ Rol actualizado a: ${rolToSave}`);
    }
    
    // Confirmar la transacción
    await pool.query('COMMIT');
    
    // Obtener los datos actualizados del usuario
    const updatedUser = await pool.query(
      `SELECT u.idpersona as id, p.nombre, p.apellido, p.cedula, p.email, u.rol
       FROM usuario u
       INNER JOIN personas p ON u.idpersona = p.idpersonas
       WHERE u.idpersona = $1`,
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

module.exports = router;
