const express = require("express");
const router = express.Router(); // 💡 Aquí defines router
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const pool = require("./db");
const { createUser } = require("./user");

router.post("/register", async (req, res) => {
  try {
    const { nombre, apellido, cedula, email, contrasena } = req.body;

    if (!nombre || !apellido || !cedula || !email || !contrasena) {
      return res.status(400).json({ error: "Todos los campos son obligatorios" });
    }

    const newUser = await createUser(nombre, apellido, cedula, email, contrasena);
    return res.status(201).json({ message: "Usuario registrado con éxito", user: newUser });

  } catch (error) {
    console.error("Error al registrar usuario:", error);
    return res.status(500).json({ error: "Error en el servidor" });
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

module.exports = router;
