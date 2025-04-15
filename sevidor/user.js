const bcrypt = require("bcrypt");
const pool = require("./db");

const createUser = async (nombre, apellido, cedula, email, contrasena, rol = "1") => {
  try {
    console.log(`📝 Iniciando creación de usuario: ${nombre} ${apellido}, email: ${email}`);
    console.log(`📊 Rol recibido en createUser: ${rol} (tipo: ${typeof rol})`);
    
    // Validar que el rol sea válido
    let rolToSave = rol;
    // Si rol no está entre los valores válidos, usar 1 (cliente) como predeterminado
    if (!["0", "1", "2", "3"].includes(rol.toString())) {
      console.warn(`⚠️ Rol no válido: "${rol}", usando rol predeterminado (1)`);
      rolToSave = "1";
    }
    
    console.log(`👤 Creando usuario con rol: ${rolToSave}`);
    
    const hashedPassword = await bcrypt.hash(contrasena, 10);

    console.log(`🔑 Contraseña hasheada correctamente`);

    const { rows: personas } = await pool.query(
      "INSERT INTO personas (nombre, apellido, cedula, email) VALUES ($1, $2, $3, $4) RETURNING idpersonas",
      [nombre, apellido, cedula, email]
    );

    const idpersonas = personas[0].idpersonas;
    console.log(`👤 Persona creada con ID: ${idpersonas}`);

    // Consultar la estructura de la tabla para ver los tipos de datos
    const tableInfo = await pool.query(
      "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'usuario'"
    );
    console.log(`📋 Estructura de la tabla usuario:`);
    tableInfo.rows.forEach(column => {
      console.log(`  - ${column.column_name}: ${column.data_type}`);
    });

    console.log(`💾 Insertando en tabla usuario: idpersona=${idpersonas}, rol=${rolToSave} (tipo: ${typeof rolToSave})`);
    const { rows } = await pool.query(
      "INSERT INTO usuario (idpersona, contrasena, rol) VALUES ($1, $2, $3) RETURNING *",
      [idpersonas, hashedPassword, rolToSave] // Usar el rol proporcionado o el predeterminado
    );

    console.log(`✅ Usuario creado exitosamente. Datos devueltos:`, rows[0]);
    // Verificar qué rol se guardó realmente
    const savedUser = await pool.query(
      "SELECT u.*, p.nombre, p.apellido, p.email FROM usuario u JOIN personas p ON u.idpersona = p.idpersonas WHERE u.idpersona = $1",
      [idpersonas]
    );
    console.log(`🔍 Verificación del usuario guardado:`, savedUser.rows[0]);

    return rows[0];
  } catch (error) {
    console.error("❌ Error al crear el usuario:", error);
    throw error;
  }
};

module.exports = { createUser };
