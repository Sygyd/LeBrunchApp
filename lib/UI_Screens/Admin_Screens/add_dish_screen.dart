import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '/Api_services/menu/add_dish_service.dart'; // Importa el servicio correcto

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
    return Scaffold(
      backgroundColor: Colors.teal,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Menú',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Expanded(
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Plato',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingresa el nombre del plato';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          const Text(
                            'Precio \$',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingresa el precio';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          const Text(
                            'Categoría',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            items:
                                _categories.map((category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  );
                                }).toList(),
                            onChanged:
                                (value) =>
                                    setState(() => _selectedCategory = value),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, selecciona una categoría';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          const Text(
                            'Ingredientes',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextFormField(
                            controller: _ingredientsController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingresa los ingredientes';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          const Text(
                            'Disponibilidad',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              Switch(
                                value: _isAvailable,
                                onChanged:
                                    (value) =>
                                        setState(() => _isAvailable = value),
                              ),
                              Icon(
                                _isAvailable
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: _isAvailable ? Colors.green : Colors.red,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.add_a_photo),
                            label: Text(
                              widget.dish != null
                                  ? 'Cambiar Imagen'
                                  : 'Añadir Imagen',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[700],
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
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
                                const SizedBox(height: 10),
                              ],
                            )
                          else if (widget.dish == null)
                            const Text(
                              'No se ha seleccionado ninguna imagen',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                          Center(
                            child: ElevatedButton(
                              onPressed: _submitDish,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: Text(
                                widget.dish != null ? 'EDITAR' : 'GUARDAR',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
