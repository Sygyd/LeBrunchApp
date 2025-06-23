const express = require("express");
const router = express.Router(); // 💡 Aquí defines router
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const pool = require("./db");
const { createUser } = require("./user");

// Constante para el ID del Super Admin - Usuario con rol '00'
const SUPER_ADMIN_ID = 1;

// Función para inicializar soft delete en tabla usuario si no existe
async function initializeUserSoftDelete() {
  try {
    console.log('🔧 Verificando columnas de soft delete en tabla usuario...');
    
    // Verificar si las columnas existen
    const checkColumns = await pool.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'usuario' 
      AND column_name IN ('isdelete', 'deleted_at', 'deleted_by')
    `);
    
    const existingColumns = checkColumns.rows.map(row => row.column_name);
    console.log('📋 Columnas existentes en tabla usuario:', existingColumns);
    
    // Agregar columnas faltantes
    if (!existingColumns.includes('isdelete')) {
      await pool.query('ALTER TABLE usuario ADD COLUMN isDelete BOOLEAN DEFAULT FALSE');
      console.log('✅ Columna isDelete agregada a tabla usuario');
    }
    
    if (!existingColumns.includes('deleted_at')) {
      await pool.query('ALTER TABLE usuario ADD COLUMN deleted_at TIMESTAMP');
      console.log('✅ Columna deleted_at agregada a tabla usuario');
    }
    
    if (!existingColumns.includes('deleted_by')) {
      await pool.query('ALTER TABLE usuario ADD COLUMN deleted_by INTEGER REFERENCES personas(idpersonas)');
      console.log('✅ Columna deleted_by agregada a tabla usuario');
    }
    
    // Asegurar que todos los usuarios existentes tengan isDelete = FALSE
    const updateResult = await pool.query(`
      UPDATE usuario 
      SET isDelete = FALSE 
      WHERE isDelete IS NULL
    `);
    
    if (updateResult.rowCount > 0) {
      console.log(`🔄 ${updateResult.rowCount} registros de usuario actualizados con isDelete = FALSE`);
    }
    
    console.log('✅ Inicialización de soft delete en tabla usuario completada');
    
  } catch (error) {
    console.error('❌ Error al inicializar soft delete en tabla usuario:', error);
    // No lanzar error para no bloquear el servidor
  }
}

// Ejecutar inicialización al cargar el módulo
initializeUserSoftDelete();

// Middleware para verificar si el usuario actual es super admin
const isSuperAdmin = async (userId) => {
  try {
    const result = await pool.query(
      "SELECT rol FROM usuario WHERE idpersona = $1",
      [userId]
    );
    // Super admin tiene rol "00" - cualquier usuario con este rol es super admin
    return result.rows.length > 0 && result.rows[0].rol === "00";
  } catch (error) {
    console.error("Error verificando super admin:", error);
    return false;
  }
};

// Middleware para verificar si el usuario actual es admin (incluye super admin)
const isAdmin = async (userId) => {
  try {
    const result = await pool.query(
      "SELECT rol FROM usuario WHERE idpersona = $1",
      [userId]
    );
    if (result.rows.length === 0) return false;
    
    const userRole = result.rows[0].rol;
    // Administrador: rol "0" (admin normal) o "00" (super admin)
    return userRole === "0" || userRole === "00";
  } catch (error) {
    console.error("Error verificando admin:", error);
    return false;
  }
};

router.post("/register", async (req, res) => {
  try {
    const { nombre, apellido, cedula, email, contrasena, rol } = req.body;

    console.log(`📝 Solicitud de registro recibida para: ${nombre} ${apellido}`);
    console.log(`📊 Datos recibidos: cedula=${cedula}, email=${email}, rol=${rol}`);

    // Validaciones básicas
    if (!nombre || !apellido || !cedula || !email || !contrasena) {
      return res.status(400).json({ 
        error: "datos_incompletos",
        message: "Todos los campos son obligatorios" 
      });
    }

    // VALIDACIONES DE UNICIDAD ANTES DE CREAR
    const cedulaExists = await pool.query(
      "SELECT idpersonas, nombre, apellido FROM personas WHERE cedula = $1 AND isDelete = FALSE",
      [cedula]
    );
    
    if (cedulaExists.rows.length > 0) {
      const existingUser = cedulaExists.rows[0];
      console.log(`❌ Registro fallido: Cédula ${cedula} ya existe (usuario: ${existingUser.nombre} ${existingUser.apellido})`);
      return res.status(400).json({ 
        error: "cedula_duplicada",
        message: `La cédula ${cedula} ya está registrada` 
      });
    }

    const emailExists = await pool.query(
      "SELECT idpersonas, nombre, apellido FROM personas WHERE email = $1 AND isDelete = FALSE",
      [email]
    );
    
    if (emailExists.rows.length > 0) {
      const existingUser = emailExists.rows[0];
      console.log(`❌ Registro fallido: Email ${email} ya existe (usuario: ${existingUser.nombre} ${existingUser.apellido})`);
      return res.status(400).json({ 
        error: "email_duplicado",
        message: `El email ${email} ya está registrado` 
      });
    }

    // Crear el usuario después de las validaciones
    const user = await createUser(nombre, apellido, cedula, email, contrasena, rol);
    console.log(`✅ Usuario registrado exitosamente: ${nombre} ${apellido} (ID: ${user.idpersona})`);
    
    res.status(201).json({
      success: true,
      message: "Usuario registrado exitosamente",
      user: {
        id: user.idpersona,
        nombre,
        apellido,
        email,
        rol: user.rol
      }
    });

  } catch (error) {
    console.error("❌ Error en registro:", error);

    // Manejar errores específicos de PostgreSQL
    if (error.code === '23505') { // Violación de restricción única
      if (error.constraint && error.constraint.includes('cedula')) {
        return res.status(400).json({ 
          error: "cedula_duplicada",
          message: "La cédula ya está registrada" 
        });
      } else if (error.constraint && error.constraint.includes('email')) {
        return res.status(400).json({ 
          error: "email_duplicado",
          message: "El email ya está registrado" 
        });
      }
    }

    res.status(500).json({ 
      error: "error_servidor",
      message: "Error interno del servidor durante el registro",
      details: error.message 
    });
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
       AND COALESCE(u.isDelete, FALSE) = FALSE
       ORDER BY p.nombre ASC`
    );
    
    console.log(`👥 Usuarios recuperados de la base de datos: ${rows.length}`);
    
    // Verificar los roles antes de devolver
    const usersWithProcessedRoles = rows.map(user => {
      // Ver el rol original
      console.log(`👤 Usuario ${user.nombre} ${user.apellido}, rol original: ${user.rol} (${typeof user.rol})`);
      
      // No convertir roles a números - mantener como string para preservar "00" vs "0"
      let rolFinal = user.rol;
      
      // Si es null o undefined, usar "1" como default (cliente)
      if (rolFinal == null) {
        rolFinal = "1";
      }
      
      // Convertir a string si no lo es
      rolFinal = rolFinal.toString();
      
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
       WHERE p.isDelete = FALSE
       AND COALESCE(u.isDelete, FALSE) = FALSE`
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
       WHERE p.isDelete = FALSE
       AND COALESCE(u.isDelete, FALSE) = FALSE`
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
       WHERE u.idpersona = $1 
       AND p.isDelete = FALSE
       AND COALESCE(u.isDelete, FALSE) = FALSE`,
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
    const { email, contrasena } = req.body;

  console.log(`🔐 Intento de login para: ${email}`);

    if (!email || !contrasena) {
    console.log("❌ Login fallido: Datos incompletos");
    return res.status(400).json({ error: "Email y contraseña son requeridos" });
    }

  try {
    // 🆕 NUEVO: Primero verificar si el usuario existe (sin importar si está eliminado)
    const userExistsQuery = await pool.query(
      `SELECT u.idpersona, u.contrasena, u.rol, p.nombre, p.apellido, p.email, p.cedula, 
              p.isDelete as persona_eliminada, COALESCE(u.isDelete, FALSE) as usuario_eliminado
       FROM usuario u
       JOIN personas p ON u.idpersona = p.idpersonas 
       WHERE p.email = $1`,
      [email]
    );

    if (userExistsQuery.rows.length === 0) {
      console.log(`❌ Login fallido: Usuario no encontrado para ${email}`);
      return res.status(401).json({ 
        error: "credenciales_invalidas",
        message: "Email o contraseña incorrectos" 
      });
    }

    const userRecord = userExistsQuery.rows[0];
    
    // 🆕 NUEVO: Verificar si el usuario está eliminado/baneado
    if (userRecord.persona_eliminada === true || userRecord.usuario_eliminado === true) {
      console.log(`🚫 Login fallido: Usuario eliminado/baneado para ${email}`);
      console.log(`   - Persona eliminada: ${userRecord.persona_eliminada}`);
      console.log(`   - Usuario eliminado: ${userRecord.usuario_eliminado}`);
      return res.status(403).json({ 
        error: "usuario_eliminado",
        message: "Esta cuenta ha sido eliminada o suspendida. Contacta al administrador para más información." 
      });
    }

    // Si llegamos aquí, el usuario existe y no está eliminado
    const { rows } = await pool.query(
      `SELECT u.idpersona, u.contrasena, u.rol, p.nombre, p.apellido, p.email, p.cedula 
       FROM usuario u
       JOIN personas p ON u.idpersona = p.idpersonas 
       WHERE p.email = $1 
       AND p.isDelete = FALSE
       AND COALESCE(u.isDelete, FALSE) = FALSE`,
      [email]
    );

    if (rows.length === 0) {
      console.log(`❌ Login fallido: Usuario no encontrado para ${email} (verificación secundaria)`);
      return res.status(401).json({ 
        error: "credenciales_invalidas",
        message: "Email o contraseña incorrectos" 
      });
    }

    const user = rows[0];
    console.log(`👤 Usuario encontrado: ${user.nombre} ${user.apellido} (ID: ${user.idpersona}, Rol: ${user.rol})`);

    // Verificar la contraseña
    const validPassword = await bcrypt.compare(contrasena, user.contrasena);
    if (!validPassword) {
      console.log(`❌ Login fallido: Contraseña incorrecta para ${email}`);
      return res.status(401).json({ 
        error: "credenciales_invalidas",
        message: "Email o contraseña incorrectos" 
      });
    }

    // Determinar si es super admin - solo verificar rol "00"
    const isSuperAdminUser = user.rol === "00";
    console.log(`🔑 Es Super Admin: ${isSuperAdminUser}`);

    // Crear token JWT
    const token = jwt.sign(
      { 
        id: user.idpersona, 
        email: user.email, 
        rol: user.rol,
        isSuperAdmin: isSuperAdminUser
      },
      "monito",
      { expiresIn: "24h" }
    );

    console.log(`✅ Login exitoso para: ${user.nombre} ${user.apellido}`);
    console.log(`🎟️ Token generado con super admin: ${isSuperAdminUser}`);

    res.json({
      token,
      user: {
        id: user.idpersona,
        nombre: user.nombre,
        apellido: user.apellido,
        email: user.email,
        cedula: user.cedula,
        rol: user.rol,
        isSuperAdmin: isSuperAdminUser,
        rolNombre: user.rol === "00" ? 'Super Administrador' :
                   user.rol === "0" ? 'Administrador' :
                   user.rol === "1" ? 'Cliente' :
                   user.rol === "2" ? 'Cocinero' : 'Barista'
      }
    });
  } catch (error) {
    console.error("❌ Error en login:", error);
    res.status(500).json({ error: "Error interno del servidor" });
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

// Endpoint para eliminar un usuario (SOFT DELETE COMPLETO - CORREGIDO)
router.delete("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const targetUserId = parseInt(id);
    
    console.log(`🗑️ Solicitud para eliminar usuario ID: ${targetUserId}`);

    // Obtener información del usuario que está haciendo la solicitud (desde el token)
    const authHeader = req.headers.authorization;
    let requestingUserId = null;
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const token = authHeader.substring(7);
        const decoded = jwt.verify(token, 'monito');
        requestingUserId = decoded.id;
        console.log(`🔑 Usuario solicitante: ${requestingUserId}`);
      } catch (tokenError) {
        console.log('⚠️ No se pudo obtener el usuario del token');
        return res.status(401).json({ 
          error: "token_invalido",
          message: "Token de autorización inválido" 
        });
      }
    } else {
      return res.status(401).json({ 
        error: "sin_autorizacion",
        message: "Se requiere autorización para esta acción" 
      });
    }

    // PROTECCIÓN 1: No se puede eliminar al super admin principal
    if (targetUserId === SUPER_ADMIN_ID) {
      console.log(`🛡️ Intento de eliminar super admin principal bloqueado`);
          return res.status(403).json({ 
        error: "superadmin_protegido",
        message: "El Super Administrador principal no puede ser eliminado por razones de seguridad del sistema"
          });
        }

    // PROTECCIÓN 2: Los usuarios no pueden eliminarse a sí mismos
    if (targetUserId === requestingUserId) {
      console.log(`🛡️ Usuario intentando eliminarse a sí mismo - BLOQUEADO`);
      return res.status(403).json({ 
        error: "autoeliminar_prohibido",
        message: "No puedes eliminar tu propia cuenta mientras estás conectado"
      });
    }

    // Verificar que el usuario objetivo existe y obtener su información
    const targetUserResult = await pool.query(
      `SELECT u.rol, p.nombre, p.apellido 
       FROM personas p
       INNER JOIN usuario u ON p.idpersonas = u.idpersona
       WHERE p.idpersonas = $1 AND p.isDelete = FALSE AND COALESCE(u.isDelete, FALSE) = FALSE`,
      [targetUserId]
    );
    
    if (targetUserResult.rows.length === 0) {
      console.log(`❌ Usuario ${targetUserId} no encontrado o ya eliminado`);
      return res.status(404).json({ 
        error: "usuario_no_encontrado",
        message: "Usuario no encontrado o ya ha sido eliminado"
      });
    }

    const targetUser = targetUserResult.rows[0];
    const targetUserRole = targetUser.rol;
    
    console.log(`🎯 Usuario objetivo: ${targetUser.nombre} ${targetUser.apellido}, rol: ${targetUserRole}`);

    // VERIFICAR PERMISOS DEL USUARIO SOLICITANTE
    const isSuperAdminRequest = await isSuperAdmin(requestingUserId);
    const isAdminRequest = await isAdmin(requestingUserId);
    
    console.log(`🔍 Permisos del solicitante:`);
    console.log(`   Es Super Admin: ${isSuperAdminRequest}`);
    console.log(`   Es Admin: ${isAdminRequest}`);

    // PROTECCIÓN 3: Solo usuarios con permisos de admin pueden eliminar usuarios
    if (!isAdminRequest) {
      console.log(`🛡️ Usuario sin permisos de admin intentando eliminar - BLOQUEADO`);
      return res.status(403).json({ 
        error: "sin_permisos_eliminar",
        message: "No tienes permisos para eliminar usuarios"
      });
    }

    // PROTECCIÓN 4: Solo super admin puede eliminar otros administradores
    const targetIsAdmin = (targetUserRole === "0" || targetUserRole === "00");
    if (targetIsAdmin && !isSuperAdminRequest) {
      console.log(`🛡️ Admin normal intentando eliminar otro admin - BLOQUEADO`);
      return res.status(403).json({ 
        error: "sin_permisos_admin",
        message: "Solo el Super Administrador puede eliminar otros administradores"
      });
    }

    // Iniciar transacción para eliminar usuario
    await pool.query('BEGIN');

    try {
      // Marcar persona como eliminada (soft delete)
    const deletePersonResult = await pool.query(
      `UPDATE personas 
         SET isDelete = TRUE, deleted_at = NOW(), deleted_by = $2
         WHERE idpersonas = $1 
       RETURNING nombre, apellido`,
        [targetUserId, requestingUserId]
      );

      // También hacer soft delete en tabla usuario
      const deleteUserResult = await pool.query(
        `UPDATE usuario 
         SET isDelete = TRUE, deleted_at = NOW(), deleted_by = $2
         WHERE idpersona = $1 
         RETURNING idpersona`,
        [targetUserId, requestingUserId]
    );
    
    if (deletePersonResult.rows.length === 0) {
      await pool.query('ROLLBACK');
      return res.status(404).json({ 
          error: "usuario_no_encontrado",
        message: "Usuario no encontrado"
      });
    }
    
    await pool.query('COMMIT');
    
      const deletedUser = deletePersonResult.rows[0];
      console.log(`✅ Usuario eliminado (soft delete): ${deletedUser.nombre} ${deletedUser.apellido} por usuario ${requestingUserId}`);
    
      res.json({
      success: true,
      message: "Usuario eliminado con éxito",
      deletedUser: {
          id: targetUserId,
          nombre: deletedUser.nombre,
          apellido: deletedUser.apellido,
          deletedBy: requestingUserId,
          deletedAt: new Date().toISOString()
      }
    });
    
    } catch (transactionError) {
    await pool.query('ROLLBACK');
      throw transactionError;
    }

  } catch (error) {
    console.error("❌ Error al eliminar usuario:", error);
    res.status(500).json({ 
      error: "error_servidor", 
      message: "Error interno del servidor al eliminar usuario", 
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Endpoint para actualizar la información de un usuario (solo si no está eliminado)
router.put("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const targetUserId = parseInt(id);
    const { nombre, apellido, cedula, email, rol, contrasena } = req.body;
    
    console.log(`📝 Solicitud para actualizar usuario ID: ${targetUserId}`);
    console.log(`📝 Datos recibidos:`, { nombre, apellido, cedula, email, rol, contrasena: contrasena ? '[HIDDEN]' : null });
    
    // Obtener información del usuario que está haciendo la solicitud
    const authHeader = req.headers.authorization;
    let requestingUserId = null;
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const token = authHeader.substring(7);
        const decoded = jwt.verify(token, 'monito');
        requestingUserId = decoded.id;
        console.log(`🔑 Usuario solicitante: ${requestingUserId}`);
      } catch (tokenError) {
        console.log('⚠️ No se pudo obtener el usuario del token');
        return res.status(401).json({ 
          error: "token_invalido",
          message: "Token de autorización inválido" 
      });
    }
    } else {
      return res.status(401).json({ 
        error: "sin_autorizacion",
        message: "Se requiere autorización para esta acción" 
      });
    }

    // Verificar que el usuario objetivo existe y no está eliminado
    const userExists = await pool.query(
      `SELECT u.rol as usuario_rol, p.nombre, p.apellido 
       FROM personas p
       INNER JOIN usuario u ON p.idpersonas = u.idpersona
       WHERE p.idpersonas = $1 AND p.isDelete = FALSE AND COALESCE(u.isDelete, FALSE) = FALSE`,
      [targetUserId]
    );
    
    if (userExists.rows.length === 0) {
      return res.status(404).json({ 
        error: "usuario_no_encontrado",
        message: "Usuario no encontrado o ha sido eliminado"
      });
    }
    
    const targetUser = userExists.rows[0];
    const currentTargetRole = targetUser.usuario_rol;
    
    console.log(`🎯 Usuario objetivo: ${targetUser.nombre} ${targetUser.apellido}, rol actual: ${currentTargetRole}`);

    // VERIFICAR PERMISOS DEL USUARIO SOLICITANTE
    const isSuperAdminRequest = await isSuperAdmin(requestingUserId);
    const isAdminRequest = await isAdmin(requestingUserId);
    
    console.log(`🔍 Permisos del solicitante:`);
    console.log(`   Es Super Admin: ${isSuperAdminRequest}`);
    console.log(`   Es Admin: ${isAdminRequest}`);

    // PROTECCIÓN 1: Solo usuarios con permisos de admin pueden editar otros usuarios
    if (!isAdminRequest) {
      return res.status(403).json({ 
        error: "sin_permisos_editar",
        message: "No tienes permisos para editar usuarios" 
      });
      }
      
    // PROTECCIÓN 2: No se puede editar al super admin principal (ID 1) sin ser super admin
    if (targetUserId === SUPER_ADMIN_ID && !isSuperAdminRequest) {
      return res.status(403).json({ 
        error: "superadmin_protegido",
        message: "Solo el Super Administrador puede editar su propia cuenta" 
      });
    }

    // PROTECCIÓN 3: Solo super admin puede editar otros administradores
    if ((currentTargetRole === "0" || currentTargetRole === "00") && !isSuperAdminRequest) {
      return res.status(403).json({ 
        error: "sin_permisos_admin",
        message: "Solo el Super Administrador puede editar otros administradores" 
      });
      }
      
    // VALIDACIONES DE UNICIDAD (solo si se proporcionan datos para cambiar)
      if (cedula) {
      const cedulaExists = await pool.query(
        "SELECT idpersonas, nombre, apellido FROM personas WHERE cedula = $1 AND idpersonas != $2 AND isDelete = FALSE",
        [cedula, targetUserId]
      );
      
      if (cedulaExists.rows.length > 0) {
        const existingUser = cedulaExists.rows[0];
        console.log(`❌ Cédula ${cedula} ya está en uso por usuario ID: ${existingUser.idpersonas}`);
        return res.status(400).json({ 
          error: "cedula_duplicada",
          message: `La cédula ${cedula} ya está registrada por ${existingUser.nombre} ${existingUser.apellido}` 
        });
      }
      }
      
      if (email) {
      const emailExists = await pool.query(
        "SELECT idpersonas, nombre, apellido FROM personas WHERE email = $1 AND idpersonas != $2 AND isDelete = FALSE",
        [email, targetUserId]
      );
      
      if (emailExists.rows.length > 0) {
        const existingUser = emailExists.rows[0];
        console.log(`❌ Email ${email} ya está en uso por usuario ID: ${existingUser.idpersonas}`);
        return res.status(400).json({ 
          error: "email_duplicado",
          message: `El email ${email} ya está registrado por ${existingUser.nombre} ${existingUser.apellido}` 
        });
      }
    }

    // VALIDACIONES DE ROL (si se proporciona)
    if (rol !== undefined) {
      console.log(`🔍 Solicitud de cambio de rol: ${currentTargetRole} → ${rol}`);
      
      // REGLA 1: Solo el super admin puede asignar rol "00" (super admin)
      if (rol === "00" && !isSuperAdminRequest) {
        console.log(`❌ Intento de asignar rol super admin sin permisos`);
        return res.status(403).json({ 
          error: "sin_permisos_superadmin",
          message: "Solo el Super Administrador puede asignar el rol de Super Administrador" 
        });
    }
    
      // REGLA 2: No se puede cambiar el rol del super admin principal
      if (targetUserId === SUPER_ADMIN_ID && currentTargetRole === "00" && rol !== "00") {
        console.log(`❌ Intento de cambiar rol del super admin principal`);
        return res.status(403).json({ 
          error: "superadmin_inmutable",
          message: "El rol del Super Administrador principal es inmutable" 
        });
      }
      
      // REGLA 3: Solo super admin puede cambiar roles a/desde administrador
      const targetIsOrWillBeAdmin = (currentTargetRole === "0" || currentTargetRole === "00") || (rol === "0" || rol === "00");
      if (targetIsOrWillBeAdmin && !isSuperAdminRequest) {
        console.log(`❌ Admin normal intentando cambiar rol de/hacia administrador`);
        return res.status(403).json({ 
          error: "sin_permisos_rol_admin",
          message: "Solo el Super Administrador puede cambiar roles de administradores o asignar roles de administrador" 
        });
      }
      
      // REGLA 4: Validar que el rol sea válido
      const validRoles = ["00", "0", "1", "2", "3"];
      if (!validRoles.includes(rol)) {
        return res.status(400).json({ 
          error: "rol_invalido",
          message: `Rol inválido. Debe ser uno de: ${validRoles.join(', ')}` 
        });
      }
    }

    // INICIAR TRANSACCIÓN
    await pool.query('BEGIN');

    try {
      // Actualizar datos en la tabla personas (si se proporcionan)
      if (nombre || apellido || cedula || email) {
        const updatePersonaQuery = `
          UPDATE personas 
          SET nombre = COALESCE($1, nombre),
              apellido = COALESCE($2, apellido),
              cedula = COALESCE($3, cedula),
              email = COALESCE($4, email)
          WHERE idpersonas = $5
        `;
        await pool.query(updatePersonaQuery, [nombre, apellido, cedula, email, targetUserId]);
        console.log(`✅ Datos personales actualizados para usuario ${targetUserId}`);
      }
      
      // Actualizar datos en la tabla usuario (rol y/o contraseña)
      let updateUserQuery = "UPDATE usuario SET ";
      const updateParams = [];
      let paramIndex = 1;

      if (rol !== undefined) {
        updateUserQuery += `rol = $${paramIndex}, `;
        updateParams.push(rol);
        paramIndex++;
        console.log(`📝 Actualizando rol a: ${rol}`);
      }

      if (contrasena) {
        const hashedPassword = await bcrypt.hash(contrasena, 10);
        updateUserQuery += `contrasena = $${paramIndex}, `;
        updateParams.push(hashedPassword);
        paramIndex++;
        console.log(`🔐 Actualizando contraseña (hasheada)`);
      }

      // Ejecutar actualización de usuario si hay cambios
      if (updateParams.length > 0) {
        updateUserQuery = updateUserQuery.slice(0, -2) + ` WHERE idpersona = $${paramIndex}`;
        updateParams.push(targetUserId);
        await pool.query(updateUserQuery, updateParams);
        console.log(`✅ Datos de usuario actualizados para usuario ${targetUserId}`);
      }

      // CONFIRMAR TRANSACCIÓN
    await pool.query('COMMIT');
    
      console.log(`✅ Usuario ${targetUserId} actualizado exitosamente por usuario ${requestingUserId}`);
      res.json({
        success: true,
        message: "Usuario actualizado exitosamente",
        updatedFields: {
          personalData: !!(nombre || apellido || cedula || email),
          role: !!rol,
          password: !!contrasena
        }
      });

    } catch (transactionError) {
      await pool.query('ROLLBACK');
      throw transactionError;
    }

  } catch (error) {
    console.error("❌ Error al actualizar usuario:", error);
    
    // Manejar errores específicos de PostgreSQL
    if (error.code === '23505') { // Violación de restricción única
      if (error.constraint && error.constraint.includes('cedula')) {
        return res.status(400).json({ 
          error: "cedula_duplicada",
          message: "La cédula ya está registrada por otro usuario" 
        });
      } else if (error.constraint && error.constraint.includes('email')) {
        return res.status(400).json({ 
          error: "email_duplicado",
          message: "El email ya está registrado por otro usuario" 
        });
      }
    }

    res.status(500).json({ 
      error: "error_servidor", 
      message: "Error interno del servidor al actualizar usuario",
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// NUEVO: Endpoint para obtener usuarios eliminados
router.get("/users/deleted/list", async (req, res) => {
  try {
    console.log('🗑️ Solicitud para obtener usuarios eliminados');

    const result = await pool.query(
      `SELECT 
        p.idpersonas as id,
        p.nombre,
        p.apellido,
        p.cedula,
        p.email,
        p.deleted_at,
        p.deleted_by,
        CAST(u.rol AS INTEGER) as rol,
        deleter.nombre as deleted_by_name,
        deleter.apellido as deleted_by_lastname
       FROM personas p
       INNER JOIN usuario u ON p.idpersonas = u.idpersona
       LEFT JOIN personas deleter ON p.deleted_by = deleter.idpersonas
       WHERE p.isDelete = TRUE 
       AND COALESCE(u.isDelete, TRUE) = TRUE
       ORDER BY p.deleted_at DESC`
    );

    console.log(`✅ Encontrados ${result.rows.length} usuarios eliminados`);

    res.json({
      deletedUsers: result.rows,
      count: result.rows.length
    });
    
  } catch (error) {
    console.error('❌ Error al obtener usuarios eliminados:', error);
    res.status(500).json({ 
      error: 'Error al obtener usuarios eliminados',
      details: error.message 
    });
  }
});

// NUEVO: Endpoint para restaurar un usuario eliminado
router.patch("/users/:id/restore", async (req, res) => {
  try {
    const { id } = req.params;
    const targetUserId = parseInt(id);
    
    console.log(`🔄 Solicitud para restaurar usuario ID: ${targetUserId}`);
    
    // Verificar que el usuario existe y está eliminado
    const checkResult = await pool.query(
      `SELECT p.*, u.rol 
       FROM personas p
       INNER JOIN usuario u ON p.idpersonas = u.idpersona
       WHERE p.idpersonas = $1 AND p.isDelete = TRUE AND u.isDelete = TRUE`, 
      [targetUserId]
    );

    if (checkResult.rows.length === 0) {
      console.log(`❌ Usuario ${targetUserId} no encontrado en elementos eliminados`);
      return res.status(404).json({ 
        error: "Usuario no encontrado en elementos eliminados" 
      });
    }

    const userData = checkResult.rows[0];

    // Verificar que no exista conflicto con datos de usuarios activos
    const conflictCheck = await pool.query(
      `SELECT idpersonas, nombre, apellido 
       FROM personas 
       WHERE (email = $1 OR cedula = $2) 
       AND idpersonas != $3 
       AND isDelete = FALSE`,
      [userData.email, userData.cedula, targetUserId]
    );

    if (conflictCheck.rows.length > 0) {
      const conflictUser = conflictCheck.rows[0];
      console.log(`❌ Conflicto al restaurar usuario: datos ya en uso por usuario activo`);
      return res.status(400).json({ 
        error: "No se puede restaurar el usuario",
        message: `Los datos (email o cédula) ya están en uso por ${conflictUser.nombre} ${conflictUser.apellido}` 
      });
    }

    // Iniciar transacción para restaurar usuario
    await pool.query('BEGIN');

    try {
      // Restaurar en tabla personas
      await pool.query(
      `UPDATE personas 
         SET isDelete = FALSE, deleted_at = NULL, deleted_by = NULL
         WHERE idpersonas = $1`,
        [targetUserId]
      );

      // Restaurar en tabla usuario
      await pool.query(
        `UPDATE usuario 
         SET isDelete = FALSE, deleted_at = NULL, deleted_by = NULL
         WHERE idpersona = $1`,
        [targetUserId]
    );

      await pool.query('COMMIT');

      console.log(`✅ Usuario restaurado: ${userData.nombre} ${userData.apellido}`);

      res.json({
      success: true,
      message: "Usuario restaurado exitosamente", 
      restoredUser: {
          id: targetUserId,
          nombre: userData.nombre,
          apellido: userData.apellido,
          email: userData.email,
          rol: userData.rol
      }
    });

    } catch (transactionError) {
      await pool.query('ROLLBACK');
      throw transactionError;
    }

  } catch (error) {
    console.error('❌ Error al restaurar usuario:', error);
    res.status(500).json({ 
      error: 'Error al restaurar usuario',
      details: error.message 
    });
  }
});

// Endpoint para verificar permisos del usuario actual
router.get("/user/permissions/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const userId = parseInt(id);
    
    const isSuperAdminUser = await isSuperAdmin(userId);
    const isAdminUser = await isAdmin(userId);
    
    res.json({
      userId,
      isSuperAdmin: isSuperAdminUser,
      isAdmin: isAdminUser,
      canDeleteAdmins: isSuperAdminUser,
      canDeleteUsers: isAdminUser,
      canModifyRoles: isSuperAdminUser
    });
  } catch (error) {
    console.error("❌ Error al verificar permisos:", error);
    res.status(500).json({ error: "Error al verificar permisos" });
  }
});

module.exports = router;
