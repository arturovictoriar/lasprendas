import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<File> _selectedImages = [];
  String? _resultPath;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    if (_isLoading || _selectedImages.length >= 4) return;
    setState(() => _isLoading = true);
    
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
          _resultPath = null;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _tryOn() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.uploadGarments(_selectedImages, 'clothing');
      setState(() {
        _resultPath = result['resultPath'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('LAS PRENDAS', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_selectedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: () => setState(() {
                _selectedImages.clear();
                _resultPath = null;
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Maniquí Base o Resultado
                    _resultPath != null
                        ? Image.network(
                            '${ApiService.baseUrl}/results/$_resultPath', 
                            key: ValueKey(_resultPath), // Force rebuild when path changes
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator(color: Colors.white));
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Error cargando resultado',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    '${ApiService.baseUrl}/results/$_resultPath',
                                    style: TextStyle(color: Colors.white30, fontSize: 10),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              );
                            },
                          )
                        : Image.asset('assets/images/mannequin_anchor.png', fit: BoxFit.contain),
                    
                    if (_isLoading)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          if (_selectedImages.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 15),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: FileImage(_selectedImages[index]),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      Positioned(
                        right: 5,
                        top: -5,
                        child: IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
                          onPressed: () => _removeImage(index),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.camera_alt_outlined,
                        label: 'Cámara',
                        onPressed: _isLoading || _selectedImages.length >= 4 ? null : () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Galería',
                        onPressed: _isLoading || _selectedImages.length >= 4 ? null : () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _selectedImages.isNotEmpty && !_isLoading ? _tryOn : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                    ),
                    child: Text(
                      _selectedImages.isEmpty ? 'SELECCIONA PRENDAS' : 'VIRTUAL TRY-ON (${_selectedImages.length}/4)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: onPressed == null ? Colors.white24 : Colors.white70),
      label: Text(label, style: TextStyle(color: onPressed == null ? Colors.white24 : Colors.white)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
        side: BorderSide(color: onPressed == null ? Colors.white10 : Colors.white24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
