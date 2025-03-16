import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '/Api_services/menu/add_dish_service.dart';

class AddDishScreen extends StatefulWidget {
  const AddDishScreen({super.key});

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

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona una imagen')),
      );
      return;
    }

    final menuService = MenuService();
    try {
      final isSuccess = await menuService.submitDish(
        nombre: _nameController.text,
        categoria: _selectedCategory ?? '',
        precio: _priceController.text,
        disponibilidad: _isAvailable.toString(),
        ingredientes: _ingredientsController.text,
        imagenFile: _selectedImage,
      );

      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plato agregado exitosamente')),
        );
        _clearForm();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al agregar plato: $e')));
    }
  }

  void _clearForm() {
    _formKey.currentState!.reset();
    _nameController.clear();
    _priceController.clear();
    _ingredientsController.clear();
    setState(() {
      _selectedImage = null;
      _isAvailable = true;
      _selectedCategory = null;
    });
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
              'Menu',
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
                            label: const Text('Añadir Imagen'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Vista previa de la imagen seleccionada
                          if (_selectedImage != null)
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
                            )
                          else
                            const Text(
                              'No se ha seleccionado ninguna imagen',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const SizedBox(height: 10),

                          Center(
                            child: ElevatedButton(
                              onPressed: _submitDish,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: const Text(
                                'GUARDAR',
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
