import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import 'closet_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<dynamic> _selectedItems = []; // Can be File or Map (Garment)
  String? _resultPath;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    if (_isLoading || _selectedItems.length >= 4) return;
    setState(() => _isLoading = true);
    
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedItems.add(File(image.path));
          _resultPath = null;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openCloset() async {
    final List<dynamic>? selectedFromCloset = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ClosetScreen(initialCount: _selectedItems.length)),
    );

    if (selectedFromCloset != null && selectedFromCloset.isNotEmpty) {
      setState(() {
        for (var item in selectedFromCloset) {
          if (_selectedItems.length < 4) {
            _selectedItems.add(item);
          }
        }
        _resultPath = null;
      });
    }
  }

  Future<void> _tryOn() async {
    if (_selectedItems.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final List<File> files = _selectedItems.whereType<File>().toList();
      final List<String> garmentIds = _selectedItems
          .where((item) => item is Map)
          .map((item) => item['id'] as String)
          .toList();

      final result = await ApiService.uploadGarments(files, 'clothing', garmentIds: garmentIds);
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
      _selectedItems.removeAt(index);
      if (_selectedItems.isEmpty) {
        _resultPath = null;
      }
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
          if (_selectedItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: () => setState(() {
                _selectedItems.clear();
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
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Maniquí Base o Resultado
                      _resultPath != null
                          ? CachedNetworkImage(
                              imageUrl: '${ApiService.baseUrl}/results/$_resultPath', 
                              key: ValueKey(_resultPath), // Force rebuild when path changes
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                              errorWidget: (context, url, error) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Error cargando resultado',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    Text(
                                      '${ApiService.baseUrl}/results/$_resultPath',
                                      style: const TextStyle(color: Colors.white30, fontSize: 10),
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
          ),
          
          if (_selectedItems.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _selectedItems.length,
                itemBuilder: (context, index) {
                  final item = _selectedItems[index];
                  final isFile = item is File;
                  
                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 15),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: isFile 
                              ? Image.file(item, fit: BoxFit.cover)
                              : CachedNetworkImage(
                                  imageUrl: '${ApiService.baseUrl}/${item['originalUrl']}',
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: Colors.white10),
                                ),
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
                        onPressed: _isLoading || _selectedItems.length >= 4 ? null : () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Galería',
                        onPressed: _isLoading || _selectedItems.length >= 4 ? null : () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.checkroom_outlined,
                        label: 'Mi closet',
                        onPressed: _isLoading ? null : _openCloset,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _selectedItems.isNotEmpty && !_isLoading ? _tryOn : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                    ),
                    child: Text(
                      _selectedItems.isEmpty ? 'SELECCIONA PRENDAS' : 'VIRTUAL TRY-ON (${_selectedItems.length}/4)',
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
