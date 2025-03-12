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

    console.log("🔹 Email recibido:", email);
    console.log("🔹 Contraseña recibida:", contrasena);

    // Consulta en la base de datos
    const { rows } = await pool.query(
      `SELECT u.contrasena, u.idpersona, u.rol, p.nombre, p.apellido
       FROM usuario u
       INNER JOIN personas p ON u.idpersona = p.idpersonas
       WHERE p.email = $1`,
      [email]
    );

    // Verificamos si la consulta devolvió resultados
    if (rows.length === 0) {
      return res.status(401).json({ error: "Credenciales incorrectas" });
    }

    // Asignamos la variable 'usuario' solo si la consulta fue exitosa
    const usuario = rows[0];
    console.log("🔹 Usuario encontrado:", usuario);

    // Comparación de la contraseña ingresada con la guardada en la base de datos
    const passwordMatch = await bcrypt.compare(contrasena, usuario.contrasena);

    if (!passwordMatch) {
      return res.status(401).json({ error: "Credenciales incorrectas" });
    }

    console.log("✅ Contraseña válida");

    // Generar el token JWT
    const token = jwt.sign(
      { id: usuario.idpersona, rol: usuario.rol },  // Datos que deseas almacenar en el token
      'monito',  // Cambia esto por una clave secreta segura
      { expiresIn: '1h' }  // Expiración del token (1 hora en este caso)
    );

    // Respuesta con el token y los datos del usuario
    return res.json({
      token,
      id: usuario.idpersona,
      nombre: usuario.nombre,
      apellido: usuario.apellido,
      rol: usuario.rol
    });

  } catch (error) {
    console.error("❌ Error en login:", error);
    return res.status(500).json({ error: "Error en el servidor" });
  }
});

module.exports = router;
