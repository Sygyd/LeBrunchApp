import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();

  bool _isAvailable = true; // Estado del switch

  PlatformFile? _selectedFile;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<String?> _compressAndUploadImage(PlatformFile file) async {
    return await compute(_processImage, file.bytes);
  }

  static String? _processImage(Uint8List? bytes) {
    if (bytes == null) return null;
    final image = img.decodeImage(bytes);
    if (image != null) {
      final resizedImage = img.copyResize(image, width: 600, height: 600);
      final compressedImage = img.encodeJpg(resizedImage, quality: 80);
      return base64Encode(Uint8List.fromList(compressedImage));
    }
    return null;
  }

  Future<void> _submitDish() async {
    if (!_formKey.currentState!.validate()) return;

    final dish = {
      'nombre': _nameController.text,
      'categoria': _categoryController.text,
      'precio': double.tryParse(_priceController.text) ?? 0.0,
      'disponibilidad': _isAvailable, // Usa el valor del switch
      'ingredientes': _ingredientsController.text.split(','),
    };

    if (_selectedFile != null) {
      final compressedImage = await _compressAndUploadImage(_selectedFile!);
      if (compressedImage != null) {
        dish['imagen_url'] = compressedImage;
      }
    }

    final menuService = MenuService();
    try {
      final isSuccess = await menuService.submitDish(dish);
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
    _categoryController.clear();
    _priceController.clear();
    _ingredientsController.clear();
    setState(() {
      _selectedFile = null;
      _isAvailable = true; // Restablecer el estado del switch
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar Plato')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Plato',
                  ),
                  validator:
                      (value) => value!.isEmpty ? 'Campo requerido' : null,
                ),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  validator:
                      (value) => value!.isEmpty ? 'Campo requerido' : null,
                ),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Precio'),
                  keyboardType: TextInputType.number,
                  validator:
                      (value) =>
                          (double.tryParse(value!) == null)
                              ? 'Ingrese un número válido'
                              : null,
                ),
                SwitchListTile(
                  title: const Text("Disponible"),
                  value: _isAvailable,
                  onChanged: (value) {
                    setState(() {
                      _isAvailable = value;
                    });
                  },
                ),
                TextFormField(
                  controller: _ingredientsController,
                  decoration: const InputDecoration(
                    labelText: 'Ingredientes (separados por coma)',
                  ),
                  validator:
                      (value) => value!.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Seleccionar Imagen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 20),
                _selectedFile != null
                    ? Image.memory(
                      _selectedFile!.bytes!,
                      height: 100,
                      fit: BoxFit.cover,
                    )
                    : const Center(child: Text('No se seleccionó imagen')),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitDish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Agregar Plato'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
