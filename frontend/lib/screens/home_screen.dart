import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pasteboard/pasteboard.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'closet_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<dynamic> _selectedItems = []; // Can be File or Map (Garment)
  String? _resultPath;
  bool _isLoading = false;
  String? _statusMessage;
  String _personType = 'female'; // 'female' or 'male'
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

  Future<void> _handlePasteImage() async {
    if (_isLoading || _selectedItems.length >= 4) return;
    
    setState(() => _isLoading = true);
    try {
      // 1. Try to get image bytes directly
      Uint8List? imageBytes = await Pasteboard.image;
      
      // 2. If no image bytes, try to get text (URL)
      if (imageBytes == null) {
        final clipboardText = await Pasteboard.text;
        if (clipboardText != null && _isValidImageUrl(clipboardText)) {
          final response = await http.get(Uri.parse(clipboardText));
          if (response.statusCode == 200) {
            imageBytes = response.bodyBytes;
          }
        }
      }

      if (imageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'pasted_image_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(p.join(tempDir.path, fileName));
        await file.writeAsBytes(imageBytes);
        
        setState(() {
          _selectedItems.add(file);
          _resultPath = null;
        });
        
        // Success: Don't show SnackBar as requested
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontró una imagen o URL válida en el portapapeles')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al pegar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isValidImageUrl(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasAbsolutePath) return false;
    
    final path = uri.path.toLowerCase();
    return path.endsWith('.png') || 
           path.endsWith('.jpg') || 
           path.endsWith('.jpeg') || 
           path.endsWith('.webp') ||
           path.contains('imgurl='); // Common in Google Image search results
  }

  Future<void> _openCloset() async {
    final List<File> files = _selectedItems.whereType<File>().toList();
    final List<dynamic> garments = _selectedItems.where((item) => item is Map).toList();

    final List<dynamic>? selectedFromCloset = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClosetScreen(
          initialSelectedGarments: garments,
          externalCount: files.length,
        ),
      ),
    );

    if (selectedFromCloset != null) {
      setState(() {
        _selectedItems.removeWhere((item) => item is Map);
        _selectedItems.addAll(selectedFromCloset);
        _resultPath = null;
      });
    }
  }

  Future<void> _tryOn() async {
    if (_selectedItems.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Iniciando procesamiento...';
    });

    try {
      final List<File> files = _selectedItems.whereType<File>().toList();
      final List<String> garmentIds = _selectedItems
          .where((item) => item is Map)
          .map((item) => item['id'] as String)
          .toList();

      final response = await ApiService.uploadGarments(
        files, 
        'clothing', 
        garmentIds: garmentIds,
        personType: _personType,
      );
      
      final sessionId = response['id'] ?? response['sessionId'];
      if (sessionId == null) {
        print('Error: Response body: $response');
        throw 'No se recibió el ID de la sesión';
      }

      await _pollSessionStatus(sessionId.toString());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
    }
  }

  Future<void> _pollSessionStatus(String sessionId) async {
    const maxRetries = 40; // ~2 mins
    int retries = 0;

    while (retries < maxRetries) {
      if (!mounted) return;
      
      final dressingMessages = [
        'Ajustando costuras',
        'Combinando texturas',
        'En el probador',
        'Espejito, espejito',
        'Perfeccionando el look',
        'Cerrando cremalleras',
        'Planchando detalles',
        'Buscando el ángulo perfecto',
        'Preparando la pasarela',
        'Estilizando tu figura',
        'Iluminando el set',
        'Capturando la esencia',
      ];
      final currentMessage = dressingMessages[retries % dressingMessages.length];
      setState(() => _statusMessage = '$currentMessage...');
      
      try {
        final session = await ApiService.getSessionStatus(sessionId);
        final resultUrl = session['resultUrl'];
        if (resultUrl != null && resultUrl.toString().isNotEmpty) {
          setState(() {
            _resultPath = resultUrl;
            _isLoading = false;
            _statusMessage = null;
          });
          return;
        }
      } catch (e) {
        print('Polling error: $e');
      }

      await Future.delayed(const Duration(seconds: 3));
      retries++;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El procesamiento está tardando más de lo esperado. Mira tus outfits luego.')),
      );
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
        leadingWidth: 80,
        leading: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() {
                _personType = 'female';
                _resultPath = null;
              }),
              child: Icon(
                Icons.woman,
                color: _personType == 'female' ? Colors.white : Colors.white24,
                size: 26,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => setState(() {
                _personType = 'male';
                _resultPath = null;
              }),
              child: Icon(
                Icons.man,
                color: _personType == 'male' ? Colors.white : Colors.white24,
                size: 26,
              ),
            ),
          ],
        ),
        title: const Text('LAS PRENDAS', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_selectedItems.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    onPressed: () => setState(() {
                      _selectedItems.clear();
                      _resultPath = null;
                    }),
                  ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white70,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
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
                              memCacheHeight: 1200, // Reasonable limit for result preview
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
                          : Image.asset(
                              _personType == 'female' 
                                ? 'assets/images/female_mannequin_anchor.png' 
                                : 'assets/images/male_mannequin_anchor.png', 
                              fit: BoxFit.contain
                            ),
                      
                      if (_isLoading)
                        Container(
                          color: Colors.black45,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(color: Colors.white),
                                if (_statusMessage != null) ...[
                                  const SizedBox(height: 20),
                                  Text(
                                    _statusMessage!,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ],
                            ),
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
                      Opacity(
                        opacity: _isLoading ? 0.5 : 1.0,
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 15),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: isFile 
                                ? Image.file(item, fit: BoxFit.cover, cacheWidth: 200)
                                : CachedNetworkImage(
                                    imageUrl: '${ApiService.baseUrl}/${item['originalUrl']}',
                                    fit: BoxFit.cover,
                                    memCacheWidth: 200, 
                                    placeholder: (context, url) => Container(color: Colors.white10),
                                  ),
                          ),
                        ),
                      ),
                      if (!_isLoading)
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Galería',
                        onPressed: _isLoading || _selectedItems.length >= 4 ? null : () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.content_paste_outlined,
                        label: 'PEGAR',
                        onPressed: _isLoading || _selectedItems.length >= 4 ? null : _handlePasteImage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.checkroom_outlined,
                        label: 'Closet',
                        onPressed: _isLoading || _selectedItems.whereType<File>().length >= 4 ? null : _openCloset,
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
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        side: BorderSide(color: onPressed == null ? Colors.white10 : Colors.white24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: onPressed == null ? Colors.white24 : Colors.white70, size: 20),
          const SizedBox(height: 4),
          Text(
            label, 
            style: TextStyle(
              color: onPressed == null ? Colors.white24 : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
