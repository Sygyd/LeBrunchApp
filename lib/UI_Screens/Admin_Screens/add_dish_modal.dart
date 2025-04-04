import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '/Api_services/menu/add_dish_service.dart';

class AddDishModal extends StatefulWidget {
  final Function onSuccess;
  final Map<String, dynamic>? dish; // Plato opcional para edición

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

  final List<String> _categories = [
    'Tablas',
    'Panquecas',
    'Tostadas francesas',
    'Gofres',
    'Omelettes',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.dish != null) {
      // Si se está editando un plato, cargar sus datos
      _nameController.text = widget.dish!['nombre'];
      _priceController.text = widget.dish!['precio'].toString();
      _ingredientsController.text = widget.dish!['ingredientes'];
      _selectedCategory = widget.dish!['categoria'];
      _isAvailable = widget.dish!['disponibilidad'];
    }
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
      if (widget.dish != null) {
        // Si se está editando un plato, usar updateDish
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
        // Si se está agregando un plato, usar submitDish
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
        Navigator.of(context).pop();
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
    final isEditing = widget.dish != null;

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
                    isEditing ? 'Editar Plato' : 'Nuevo Plato',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
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
                                Icons.add_photo_alternate,
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
                  labelText: 'Nombre del plato',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(
                    Icons.restaurant_menu,
                    color: theme.colorScheme.primary,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa el nombre del plato';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Categoría
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items:
                    _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, selecciona una categoría';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Precio
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Precio (\$)',
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
                    return 'Por favor, ingresa el precio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Ingredientes
              TextFormField(
                controller: _ingredientsController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Ingredientes',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(
                    Icons.list_alt,
                    color: theme.colorScheme.primary,
                  ),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa los ingredientes';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Disponibilidad
              SwitchListTile(
                title: const Text('Disponible en el menú'),
                subtitle: Text(
                  _isAvailable
                      ? 'El plato será visible para los clientes'
                      : 'El plato no será visible para los clientes',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                value: _isAvailable,
                onChanged: (value) => setState(() => _isAvailable = value),
                activeColor: theme.colorScheme.primary,
                secondary: Icon(
                  _isAvailable ? Icons.check_circle : Icons.cancel,
                  color: _isAvailable ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 20),

              // Botón de envío
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitDish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Text(
                            isEditing ? 'Actualizar Plato' : 'Agregar Plato',
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
