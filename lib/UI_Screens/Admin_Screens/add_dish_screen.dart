import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '/Api_services/menu/add_dish_service.dart';

class AddDishScreen extends StatefulWidget {
  final Map<String, dynamic>? dish; // Plato opcional para edición

  const AddDishScreen({super.key, this.dish});

  @override
  State<AddDishScreen> createState() => _AddDishScreenState();
}

class _AddDishScreenState extends State<AddDishScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _priceFocusNode = FocusNode();
  final FocusNode _ingredientsFocusNode = FocusNode();
  final FocusNode _categoryFocusNode = FocusNode();

  bool _isAvailable = true;
  File? _selectedImage;
  String? _selectedCategory;
  final List<String> _categories = [
    'Tablas',
    'Panquecas',
    'Tostadas francesas',
    'Gofres',
    'Omelettes',
  ];

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _priceFocusNode.dispose();
    _ingredientsFocusNode.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _nameController.text.isEmpty) {
        FocusScope.of(context).requestFocus(_nameFocusNode);
      } else if (mounted && _priceController.text.isEmpty) {
        FocusScope.of(context).requestFocus(_priceFocusNode);
      } else if (mounted && _ingredientsController.text.isEmpty) {
        FocusScope.of(context).requestFocus(_ingredientsFocusNode);
      }
    });
  }

  void _fieldSubmitted({
    required FocusNode currentFocus,
    bool isLastField = false,
  }) {
    // Verificar si el campo actual está vacío
    bool shouldStay = false;

    if (currentFocus == _nameFocusNode && _nameController.text.isEmpty) {
      shouldStay = true;
    } else if (currentFocus == _priceFocusNode &&
        _priceController.text.isEmpty) {
      shouldStay = true;
    } else if (currentFocus == _ingredientsFocusNode &&
        _ingredientsController.text.isEmpty) {
      shouldStay = true;
    }

    if (shouldStay) {
      currentFocus.requestFocus(); // Mantener el foco si está vacío
      return;
    }

    if (isLastField) {
      currentFocus.unfocus(); // Quitar el teclado si es el último campo
      return;
    }

    // Navegación ordenada entre campos
    if (currentFocus == _nameFocusNode) {
      if (_priceController.text.isEmpty) {
        FocusScope.of(context).requestFocus(_priceFocusNode);
      } else if (_selectedCategory == null || _selectedCategory!.isEmpty) {
        FocusScope.of(context).requestFocus(_categoryFocusNode);
      } else if (_ingredientsController.text.isEmpty) {
        FocusScope.of(context).requestFocus(_ingredientsFocusNode);
      } else {
        _priceFocusNode.requestFocus();
      }
    } else if (currentFocus == _priceFocusNode) {
      if (_selectedCategory == null || _selectedCategory!.isEmpty) {
        FocusScope.of(context).requestFocus(_categoryFocusNode);
      } else if (_ingredientsController.text.isEmpty) {
        FocusScope.of(context).requestFocus(_ingredientsFocusNode);
      } else {
        _categoryFocusNode.requestFocus();
      }
    } else if (currentFocus == _categoryFocusNode) {
      if (_ingredientsController.text.isEmpty) {
        FocusScope.of(context).requestFocus(_ingredientsFocusNode);
      } else {
        _ingredientsFocusNode.requestFocus();
      }
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se seleccionó ninguna imagen')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar la imagen: $e')),
      );
    }
  }

  Future<void> _submitDish() async {
    if (!_formKey.currentState!.validate()) return;

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

      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.dish != null
                  ? 'Plato editado exitosamente'
                  : 'Plato agregado exitosamente',
            ),
          ),
        );
        Navigator.pop(context, true); // Regresar a la pantalla anterior
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.dish != null ? 'Editar Plato' : 'Agregar Plato',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Nombre del plato
                    // Campo Nombre
                    TextFormField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Plato',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa el nombre del plato';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted:
                          (_) => _fieldSubmitted(currentFocus: _nameFocusNode),
                    ),
                    const SizedBox(height: 15),

                    // Precio
                    // Campo Precio
                    TextFormField(
                      controller: _priceController,
                      focusNode: _priceFocusNode,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Precio \$',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa el precio';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Por favor, ingresa un número válido';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted:
                          (_) => _fieldSubmitted(currentFocus: _priceFocusNode),
                    ),
                    const SizedBox(height: 15),

                    // Categoría
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      items:
                          _categories.map((category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                      onChanged:
                          (value) => setState(() => _selectedCategory = value),
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, selecciona una categoría';
                        }
                        return null;
                      },
                      dropdownColor: Colors.white,
                      elevation: 2,
                      menuMaxHeight: 200,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down),
                      iconSize: 24,
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                      // Configuración clave para posición consistente
                      alignment: Alignment.bottomLeft,
                      borderRadius: BorderRadius.circular(8),
                      itemHeight: 48,
                    ),
                    const SizedBox(height: 15),

                    // Ingredientes
                    TextFormField(
                      controller: _ingredientsController,
                      focusNode: _ingredientsFocusNode,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Ingredientes',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa los ingredientes';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted:
                          (_) => _fieldSubmitted(
                            currentFocus: _ingredientsFocusNode,
                            isLastField: true,
                          ),
                    ),
                    const SizedBox(height: 15),

                    // Disponibilidad
                    Row(
                      children: [
                        const Text(
                          'Disponible:',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 10),
                        Switch(
                          value: _isAvailable,
                          onChanged:
                              (value) => setState(() => _isAvailable = value),
                          activeColor: Colors.teal,
                        ),
                        Icon(
                          _isAvailable ? Icons.check_circle : Icons.cancel,
                          color: _isAvailable ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Imagen
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_a_photo),
                          label: Text(
                            widget.dish != null
                                ? 'Cambiar Imagen'
                                : 'Añadir Imagen',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Mostrar la imagen actual si se está editando
                        if (widget.dish != null &&
                            widget.dish!['imagen_url'] != null)
                          Column(
                            children: [
                              const Text(
                                'Imagen actual:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              CachedNetworkImage(
                                imageUrl: widget.dish!['imagen_url'],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) =>
                                        const CircularProgressIndicator(),
                                errorWidget:
                                    (context, url, error) =>
                                        const Icon(Icons.error),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),

                        // Mostrar la nueva imagen seleccionada
                        if (_selectedImage != null)
                          Column(
                            children: [
                              const Text(
                                'Nueva imagen:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Botón de guardar
                    ElevatedButton(
                      onPressed: _submitDish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: Text(
                        widget.dish != null
                            ? 'GUARDAR CAMBIOS'
                            : 'AGREGAR PLATO',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
