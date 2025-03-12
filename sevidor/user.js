const bcrypt = require("bcrypt");
const pool = require("./db");  // Aquí importamos el pool desde el archivo db.js

const createUser = async (nombre, apellido, cedula, email, contrasena) => {
  try {
    // Hasheando la contraseña antes de guardarla en la base de datos
    const hashedPassword = await bcrypt.hash(contrasena, 10);

    const { rows: personas } = await pool.query(
      "INSERT INTO personas (nombre, apellido, cedula, email) VALUES ($1, $2, $3, $4) RETURNING idpersonas",
      [nombre, apellido, cedula, email]
    );

    const idpersonas = personas[0].idpersonas;

    const { rows } = await pool.query(
      "INSERT INTO usuario (idpersona, contrasena, rol) VALUES ($1, $2, $3) RETURNING *",
      [idpersonas, hashedPassword, 1]
    );

    return rows[0];
  } catch (error) {
    console.error("Error al crear el usuario:", error);
    throw error;
  }
};

module.exports = { createUser};
