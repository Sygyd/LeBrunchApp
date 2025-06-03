import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '/Api_services/menu/add_dish_service.dart';

class AddDishModal extends StatefulWidget {
  final Function onSuccess;
  final Map<String, dynamic>? dish; // Plato/bebida opcional para edición

  const AddDishModal({super.key, required this.onSuccess, this.dish});

  @override
  State<AddDishModal> createState() => _AddDishModalState();
}

class _AddDishModalState extends State<AddDishModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();

  bool _isAvailable = true;
  File? _selectedImage;
  String? _selectedCategory;
  bool _isLoading = false;
  bool _isNewItem = false;
  bool _isDrink = false;
  String _itemType = 'plato';

  // Categorías de platos
  final List<String> _dishCategories = [
    'Tablas',
    'Panquecas',
    'Tostadas francesas',
    'Gofres',
    'Omelettes',
  ];

  // Categorías de bebidas
  final List<String> _drinkCategories = [
    'Expresos',
    'Frapuccinos',
    'Cold Brew',
    'Jugos',
  ];

  // Lista actual de categorías
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();

    // Determinar si es una bebida basado en la categoría o el marcador especial
    if (widget.dish != null) {
      final category = widget.dish!['categoria'] ?? '';
      final isNewItem = widget.dish!['_isNewItem'] ?? false;
      final itemType = widget.dish!['_itemType'] ?? 'plato';

      _isNewItem = isNewItem;
      _itemType = itemType;
      _isDrink = _isDrinkCategory(category) || itemType == 'bebida';

      // Establecer las categorías correctas según sea plato o bebida
      _categories = _isDrink ? _drinkCategories : _dishCategories;

      // Solo cargar datos si no es un nuevo ítem
      if (!_isNewItem) {
        _nameController.text = widget.dish!['nombre'] ?? '';
        _priceController.text = widget.dish!['precio']?.toString() ?? '';
        _ingredientsController.text = widget.dish!['ingredientes'] ?? '';
        _selectedCategory = category;
        _isAvailable = widget.dish!['disponibilidad'] ?? true;
      } else {
        // Para nuevos items, establecer la categoría inicial
        _selectedCategory = category;
      }
    } else {
      // Por defecto, mostrar categorías de platos
      _categories = _dishCategories;
    }
  }

  // CORRECCIÓN CRÍTICA: Añadir dispose de todos los TextEditingController
  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  // Función para determinar si una categoría corresponde a bebidas
  bool _isDrinkCategory(String category) {
    return _drinkCategories.contains(category);
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar la imagen: $e')),
        );
      }
    }
  }

  Future<void> _submitDish() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final addDishService = AddDishService();
    try {
      bool isSuccess;
      if (widget.dish != null && !_isNewItem) {
        // Si se está editando un plato existente, usar updateDish
        isSuccess = await addDishService.updateDish(
          id: widget.dish!['idplato'].toString(),
          nombre: _nameController.text,
          categoria: _selectedCategory ?? '',
          precio: _priceController.text,
          disponibilidad: _isAvailable.toString(),
          ingredientes: _ingredientsController.text,
          imagenFile: _selectedImage,
        );
      } else {
        // Si se está agregando un plato o bebida nuevo, usar submitDish
        isSuccess = await addDishService.submitDish(
          nombre: _nameController.text,
          categoria: _selectedCategory ?? '',
          precio: _priceController.text,
          disponibilidad: _isAvailable.toString(),
          ingredientes: _ingredientsController.text,
          imagenFile: _selectedImage,
        );
      }

      if (isSuccess && mounted) {
        widget.onSuccess();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.dish != null && !_isNewItem;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: contentBox(context, theme, isEditing),
    );
  }

  Widget contentBox(BuildContext context, ThemeData theme, bool isEditing) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(0, 10),
            blurRadius: 10,
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Editar $_itemType' : 'Nueva $_itemType',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              // Imagen
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child:
                      _selectedImage != null
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                          : isEditing && widget.dish!['imagen_url'] != null
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: CachedNetworkImage(
                              imageUrl: widget.dish!['imagen_url'],
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                              errorWidget:
                                  (context, url, error) => const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  ),
                            ),
                          )
                          : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isDrink
                                    ? Icons.local_cafe
                                    : Icons.add_photo_alternate,
                                size: 50,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Añadir imagen',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
              const SizedBox(height: 20),

              // Nombre
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre de ${_isDrink ? 'la bebida' : 'l plato'}',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(
                    _isDrink ? Icons.local_cafe : Icons.restaurant_menu,
                    color: theme.colorScheme.primary,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Categoría
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(
                    Icons.category,
                    color: theme.colorScheme.primary,
                  ),
                ),
                items:
                    _categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor selecciona una categoría';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Precio
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Precio',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(
                    Icons.attach_money,
                    color: theme.colorScheme.primary,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un precio';
                  }
                  try {
                    double.parse(value);
                  } catch (e) {
                    return 'Ingresa un precio válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Ingredientes
              TextFormField(
                controller: _ingredientsController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _isDrink ? 'Descripción' : 'Ingredientes',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Icon(
                      _isDrink ? Icons.description : Icons.list_alt,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _isDrink
                        ? 'Por favor ingresa una descripción'
                        : 'Por favor ingresa los ingredientes';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Disponibilidad
              SwitchListTile(
                title: const Text('Disponible'),
                value: _isAvailable,
                onChanged: (bool value) {
                  setState(() {
                    _isAvailable = value;
                  });
                },
                secondary: Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),

              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitDish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(
                              isEditing ? 'Actualizar' : 'Guardar',
                              style: const TextStyle(
                                fontFamily: 'MADE TOMMY',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
