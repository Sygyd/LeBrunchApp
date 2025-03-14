import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
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
  PlatformFile? _selectedFile;
  String? _selectedCategory;
  final List<String> _categories = ['Tablas', 'Panquecas', 'Tostadas francesas', 'Gofres', 'Omelettes'];

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _submitDish() async {
    if (!_formKey.currentState!.validate()) return;
    final dish = {
      'nombre': _nameController.text,
      'categoria': _selectedCategory,
      'precio': double.tryParse(_priceController.text) ?? 0.0,
      'disponibilidad': _isAvailable,
      'ingredientes': _ingredientsController.text.split(','),
    };

    final menuService = MenuService();
    try {
      final isSuccess = await menuService.submitDish(dish);
      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plato agregado exitosamente')));
        _clearForm();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al agregar plato: $e')));
    }
  }

  void _clearForm() {
    _formKey.currentState!.reset();
    _nameController.clear();
    _priceController.clear();
    _ingredientsController.clear();
    setState(() {
      _selectedFile = null;
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
            const Text('Menu', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
            Expanded(
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Plato', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextFormField(controller: _nameController, decoration: const InputDecoration(border: OutlineInputBorder())),
                          const SizedBox(height: 10),

                          const Text('Precio \$', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextFormField(controller: _priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder())),
                          const SizedBox(height: 10),

                          const Text('Categoría', style: TextStyle(fontWeight: FontWeight.bold)),
                          DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            items: _categories.map((category) {
                              return DropdownMenuItem(value: category, child: Text(category));
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedCategory = value),
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 10),

                          const Text('Ingredientes', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextFormField(controller: _ingredientsController, decoration: const InputDecoration(border: OutlineInputBorder())),
                          const SizedBox(height: 10),

                          const Text('Disponibilidad', style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              Switch(value: _isAvailable, onChanged: (value) => setState(() => _isAvailable = value)),
                              Icon(_isAvailable ? Icons.check_circle : Icons.cancel, color: _isAvailable ? Colors.green : Colors.red),
                            ],
                          ),
                          const SizedBox(height: 10),

                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.add_a_photo),
                            label: const Text('Añadir Imagen'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
                          ),
                          _selectedFile != null ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Image.memory(_selectedFile!.bytes!, height: 100, fit: BoxFit.cover),
                          ) : const SizedBox.shrink(),
                          const SizedBox(height: 10),

                          Center(
                            child: ElevatedButton(
                              onPressed: _submitDish,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold)),
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
