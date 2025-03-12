import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
//import 'package:image/image.dart' as img;
import 'package:LeBrunchApp/API_Service/menu/add_dish_service.dart';

class AddDishScreen extends StatefulWidget {
  const AddDishScreen({super.key});

  @override
  State<AddDishScreen> createState() => _AddDishScreenState();
}

class _AddDishScreenState extends State<AddDishScreen> {
  // Controladores de los campos
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _availabilityController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  
  final List<PlatformFile> _selectedFiles = [];

  // Función para seleccionar imágenes
  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null) {
      setState(() {
        _selectedFiles.clear();
        _selectedFiles.addAll(result.files);
      });
    }
  }

  // Función para comprimir y convertir la imagen a base64
  Future<String?> _compressAndUploadImage(PlatformFile file) async {
    if (file.bytes != null) {
      Uint8List bytes = file.bytes!;
      img.Image? image = img.decodeImage(Uint8List.fromList(bytes));

      if (image != null) {
        img.Image resizedImage = img.copyResize(image, width: 600, height: 600);
        List<int> compressedImage = img.encodePng(resizedImage, level: 9);
        return base64Encode(Uint8List.fromList(compressedImage));
      }
    }
    return null;
  }

  // Función para enviar el plato al backend
  Future<void> _submitDish() async {
    final dish = {
      'nombre': _nameController.text,
      'categoria': _categoryController.text,
      'precio': double.tryParse(_priceController.text) ?? 0.0,
      'disponibilidad': _availabilityController.text.toLowerCase() == 'si',
      'ingredientes': _ingredientsController.text.split(','),
    };

    // Procesar imagen
    if (_selectedFiles.isNotEmpty) {
      String? compressedImage = await _compressAndUploadImage(_selectedFiles.first);
      if (compressedImage != null) {
        dish['imagen_url'] = 'data:image/png;base64,$compressedImage';
      }
    }

    final menuService = MenuService();
    try {
      final isSuccess = await menuService.submitDish(dish);
      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plato agregado exitosamente'))
        );
        _clearForm();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al agregar plato: $e'))
      );
    }
  }

  // Función para limpiar el formulario
  void _clearForm() {
    _nameController.clear();
    _categoryController.clear();
    _priceController.clear();
    _availabilityController.clear();
    _ingredientsController.clear();
    setState(() {
      _selectedFiles.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar Plato')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre del Plato'),
              ),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Categoría'),
              ),
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Precio'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _availabilityController,
                decoration: const InputDecoration(labelText: 'Disponibilidad (Sí/No)'),
              ),
              TextField(
                controller: _ingredientsController,
                decoration: const InputDecoration(labelText: 'Ingredientes (separados por coma)'),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Seleccionar Imagen'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              ),

              const SizedBox(height: 20),

              _selectedFiles.isNotEmpty
                  ? Image.memory(_selectedFiles.first.bytes!, height: 100, fit: BoxFit.cover)
                  : const Center(child: Text('No se seleccionó imagen')),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _submitDish,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Agregar Plato'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
