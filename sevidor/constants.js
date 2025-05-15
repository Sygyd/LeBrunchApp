// Definición de categorías
const FOOD_CATEGORIES = ['tablas', 'panquecas', 'tostadas francesas', 'gofres', 'omelettes'];
const DRINK_CATEGORIES = ['Expresos', 'Frapuccinos', 'Cold Brew', 'Jugos'];

// Función auxiliar para verificar si una categoría es comida
function isFoodCategory(category) {
  return FOOD_CATEGORIES.includes(category.toLowerCase());
}

// Función auxiliar para verificar si una categoría es bebida
function isDrinkCategory(category) {
  return DRINK_CATEGORIES.includes(category);
}

module.exports = {
  FOOD_CATEGORIES,
  DRINK_CATEGORIES,
  isFoodCategory,
  isDrinkCategory
}; 