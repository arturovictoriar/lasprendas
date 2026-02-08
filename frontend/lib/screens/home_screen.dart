import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pasteboard/pasteboard.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
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
  List<dynamic> _processingItems = []; // Items currently being "dressed"
  String? _resultPath;
  bool _isLoading = false;
  bool _isRetrying = false;
  bool _isCancelled = false;
  String? _statusMessage;
  String _personType = 'female'; // 'female' or 'male'
  String _processingPersonType = 'female'; // Tracking the gender being processed
  final ImagePicker _picker = ImagePicker();
  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> _resilientWrite(String key, String value) async {
    try {
      await _storage.write(
        key: key, 
        value: value,
        iOptions: const IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
      );
    } on PlatformException catch (e) {
      if (e.code == '-25299') {
        await _storage.delete(
          key: key,
          iOptions: const IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
        );
        await _storage.write(
          key: key, 
          value: value,
          iOptions: const IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
        );
      } else {
        rethrow;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPersistedState();
  }

  Future<void> _savePersistedState() async {
    try {
      final List<Map<String, dynamic>> serializedItems = _selectedItems.map((item) {
        if (item is File) {
          return {'type': 'file', 'path': item.path};
        } else if (item is Map) {
          return {'type': 'map', 'data': item};
        }
        return <String, dynamic>{};
      }).toList();

      // Ultra-resilient write strategy
      await _resilientWrite('selected_garments', jsonEncode(serializedItems));
      await _resilientWrite('person_type', _personType);

      if (_resultPath != null) {
        await _resilientWrite('result_path', _resultPath!);
      } else {
        await _storage.delete(key: 'result_path');
      }
      
      if (_isLoading && _processingItems.isNotEmpty) {
        final List<Map<String, dynamic>> serializedProcessingItems = _processingItems.map((item) {
          if (item is File) {
            return {'type': 'file', 'path': item.path};
          } else if (item is Map) {
            return {'type': 'map', 'data': item};
          }
          return <String, dynamic>{};
        }).toList();

        await _resilientWrite('processing_items', jsonEncode(serializedProcessingItems));
        await _resilientWrite('processing_person_type', _processingPersonType);
      }
    } catch (e) {
      print('Error saving state: $e');
    }
  }

  Future<void> _loadPersistedState() async {
    try {
      final savedGarments = await _storage.read(key: 'selected_garments');
      final savedPersonType = await _storage.read(key: 'person_type');
      final savedSessionId = await _storage.read(key: 'processing_session_id');
      final savedProcessingItems = await _storage.read(key: 'processing_items');
      final savedProcessingPersonType = await _storage.read(key: 'processing_person_type');

      if (savedPersonType != null) {
        setState(() => _personType = savedPersonType);
      }

      final savedResultPath = await _storage.read(key: 'result_path');
      if (savedResultPath != null) {
        setState(() => _resultPath = savedResultPath);
      }

      if (savedGarments != null) {
        final List<dynamic> decodedItems = jsonDecode(savedGarments);
        final List<dynamic> restoredItems = [];

        for (var item in decodedItems) {
          if (item['type'] == 'file') {
            final file = File(item['path']);
            if (await file.exists()) {
              restoredItems.add(file);
            }
          } else if (item['type'] == 'map') {
            restoredItems.add(item['data']);
          }
        }

        if (restoredItems.isNotEmpty) {
          setState(() => _selectedItems.addAll(restoredItems));
        }
      }

      if (savedSessionId != null && savedProcessingItems != null) {
        final List<dynamic> decodedProcItems = jsonDecode(savedProcessingItems);
        final List<dynamic> restoredProcItems = [];

        for (var item in decodedProcItems) {
          if (item['type'] == 'file') {
            final file = File(item['path']);
            if (await file.exists()) {
              restoredProcItems.add(file);
            }
          } else if (item['type'] == 'map') {
            restoredProcItems.add(item['data']);
          }
        }

        if (restoredProcItems.isNotEmpty) {
          setState(() {
            _isLoading = true;
            _processingItems = restoredProcItems;
            _processingPersonType = savedProcessingPersonType ?? _personType;
            _statusMessage = 'Retomando...';
          });
          _pollSessionStatus(savedSessionId, _processingPersonType);
        }
      }
    } catch (e) {
      print('Error loading state: $e');
    }
  }

  Future<void> _clearPersistedState() async {
    try {
      await _storage.delete(key: 'selected_garments', iOptions: const IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device));
      await _storage.delete(key: 'processing_session_id', iOptions: const IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device));
      await _storage.delete(key: 'processing_items', iOptions: const IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device));
      await _storage.delete(key: 'processing_person_type', iOptions: const IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device));
      await _storage.delete(key: 'result_path', iOptions: const IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device));
    } catch (e) {
      print('Error clearing state: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isLoading || _selectedItems.length >= 10) return;
    setState(() => _isLoading = true);
    
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null && mounted) {
        setState(() {
          _selectedItems.add(File(image.path));
          _resultPath = null;
        });
        _savePersistedState();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePasteImage() async {
    if (_isLoading || _selectedItems.length >= 10) return;
    
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
        _savePersistedState();
        
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

    final dynamic result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute<dynamic>(
        builder: (context) => ClosetScreen(
          initialSelectedGarments: garments,
          externalCount: files.length,
        ),
      ),
    );

    if (result != null) {
      if (result is List) {
        // Legacy behavior: just picking garments
        final currentGarmentIds = _selectedItems
            .where((item) => item is Map)
            .map((item) => item['id'].toString())
            .toSet();
        final newGarmentIds = result
            .map((item) => item['id'].toString())
            .toSet();

        final hasChanged = currentGarmentIds.length != newGarmentIds.length ||
            !currentGarmentIds.every((id) => newGarmentIds.contains(id));

        setState(() {
          _selectedItems.removeWhere((item) => item is Map);
          _selectedItems.addAll(result);
          if (hasChanged) {
            _resultPath = null;
          }
        });
        _savePersistedState();
      } else if (result is Map && result['type'] == 'retake') {
        // New behavior: retaking a whole outfit
        setState(() {
          _selectedItems.clear();
          _selectedItems.addAll(result['garments']);
          _personType = result['gender'];
          _resultPath = result['resultUrl'];
        });
      }
      _savePersistedState();
    }
  }

  Future<void> _tryOn() async {
    if (_selectedItems.isEmpty || _isLoading) return;

    final requestedPersonType = _personType; // Capturar el género actual
    setState(() {
      _isLoading = true;
      _isRetrying = false;
      _isCancelled = false;
      _statusMessage = 'Alistando...';
      _processingItems = List.from(_selectedItems); // Capture current selection
      _processingPersonType = requestedPersonType; // Store gender for UI
    });

    try {
      final List<File> files = _processingItems.whereType<File>().toList();
      final List<String> garmentIds = _processingItems
          .where((item) => item is Map)
          .map((item) => item['id'] as String)
          .toList();

      // Calculate hashes for new files to enable pre-flight check
      final List<String> hashes = [];
      for (var file in files) {
        final bytes = await file.readAsBytes();
        final hash = sha256.convert(bytes).toString();
        hashes.add(hash);
      }

      bool success = false;
      String? sessionId;

      while (!success && !_isCancelled) {
        try {
          final response = await ApiService.uploadGarments(
            files, 
            'clothing', 
            garmentIds: garmentIds,
            personType: requestedPersonType,
            hashes: hashes,
          );
          
          sessionId = response['id'] ?? response['sessionId'];
          if (sessionId == null) throw 'No se recibió el ID de la sesión';
          // Update _selectedItems to replace Files with resolved Garments (new or matched by hash)
          if (response['resolvedGarments'] != null && mounted) {
            final List<dynamic> resolved = response['resolvedGarments'];
            setState(() {
              for (var i = 0; i < files.length; i++) {
                final fileToRemove = files[i];
                final index = _selectedItems.indexWhere((item) => item is File && item.path == fileToRemove.path);
                if (index != -1 && i < resolved.length) {
                  final garment = Map<String, dynamic>.from(resolved[i]);
                  garment['_localFilePath'] = fileToRemove.path; // Attach the local path
                  _selectedItems[index] = garment;
                }
              }
            });
          }

          success = true;
        } catch (e) {
          if (e.toString().contains('503') || e.toString().contains('lleno')) {
            if (!mounted) return;
            setState(() {
              _isRetrying = true;
              _statusMessage = 'El vestier está muy lleno hoy... Reintentando...';
            });
            await Future.delayed(const Duration(seconds: 5));
          } else {
            rethrow;
          }
        }
        if (!mounted) return;
      }

      if (success && sessionId != null && !_isCancelled) {
        if (!mounted) return;
        // Message will be handled by the polling loop sequence
        await _storage.write(key: 'processing_session_id', value: sessionId.toString());
        await _savePersistedState(); // Save processing_items and person_type
        await _pollSessionStatus(sessionId.toString(), requestedPersonType);
      }
    } catch (e) {
      if (mounted && !_isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRetrying = false;
          _statusMessage = null;
          _processingItems = [];
        });
      }
    }
  }

  Future<void> _pollSessionStatus(String sessionId, String requestedPersonType) async {
    const maxRetries = 40; // ~2 mins
    int retries = 0;

    while (retries < maxRetries) {
      if (!mounted) return;
      
      final dressingMessages = [
        'Vistiendo',
        'Ajustando',
        'Retocando',
        'Modelando',
        'Estilando',
        'Entallando',
        'Puliendo',
        'Combinando',
        'Entelando',
        'Cociendo',
        'Probando',
      ];
      final currentMessage = dressingMessages[retries % dressingMessages.length];
      if (!mounted || _isCancelled) return;
      setState(() => _statusMessage = '$currentMessage...');
      
      try {
        final session = await ApiService.getSessionStatus(sessionId);
        if (!mounted || _isCancelled) return;
        
        final resultUrl = session['resultUrl'];
        if (resultUrl != null && resultUrl.toString().isNotEmpty) {
          setState(() {
            _personType = requestedPersonType; // Sincronizar iconos con el resultado
            _resultPath = resultUrl;
            _isLoading = false;
            _statusMessage = null;
          });
          _clearPersistedState();
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
    _savePersistedState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        leadingWidth: 110,
        leading: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(width: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _personType = 'female';
                  _resultPath = null;
                });
                _savePersistedState();
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.woman,
                  color: _personType == 'female' ? Colors.white : Colors.white24,
                  size: 26,
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _personType = 'male';
                  _resultPath = null;
                });
                _savePersistedState();
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.man,
                  color: _personType == 'male' ? Colors.white : Colors.white24,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
        title: const Text(
          'LAS PRENDAS', 
          style: TextStyle(fontSize: 18, letterSpacing: 1.0, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_selectedItems.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _selectedItems.clear();
                  _resultPath = null;
                });
                _clearPersistedState();
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                child: const Icon(Icons.refresh, color: Colors.white70, size: 26),
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: const Icon(
                Icons.person,
                color: Colors.white70,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background-lasprendas.png'),
            fit: BoxFit.cover,
            opacity: 0.7,
          ),
        ),
        child: Column(
          children: [
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                Center(
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
                      child: InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: _resultPath != null
                            ? CachedNetworkImage(
                                imageUrl: ApiService.getFullImageUrl(_resultPath), 
                                key: ValueKey(_resultPath),
                                fit: BoxFit.contain,
                                memCacheHeight: 1200,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(color: Colors.white),
                                ),
                                errorWidget: (context, url, error) {
                                  return const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                                      SizedBox(height: 10),
                                      Text(
                                        'Error cargando resultado',
                                        style: TextStyle(color: Colors.white70),
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
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: -4,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: (_isLoading && _statusMessage != null) ? 1.0 : 0.0,
                    curve: Curves.easeInOut,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 300),
                      scale: (_isLoading && _statusMessage != null) ? 1.0 : 0.95,
                      curve: Curves.easeOutBack,
                      child: IgnorePointer(
                        ignoring: !(_isLoading && _statusMessage != null),
                        child: Container(
                          width: 120, // Revertido al tamaño original que te gustaba
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white10),
                            boxShadow: [
                              BoxShadow(color: Colors.black45, blurRadius: 10),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_processingItems.isNotEmpty)
                            SizedBox(
                              height: 45,
                              child: Row(
                                children: [
                                  // Maniquí FIJO
                                  Container(
                                    width: 30,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: Image.asset(
                                        _processingPersonType == 'female' 
                                            ? 'assets/images/female_mannequin_anchor.png' 
                                            : 'assets/images/male_mannequin_anchor.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const VerticalDivider(color: Colors.white24, width: 8, indent: 5, endIndent: 5), // Reducido de 12 a 8
                                  // Ropa con Scroll
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: _processingItems.map((item) {
                                          return Container(
                                            width: 30,
                                            margin: const EdgeInsets.only(right: 6),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.white24),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(5),
                                              child: item is File 
                                                ? Image.file(item, fit: BoxFit.cover)
                                                : CachedNetworkImage(
                                                    imageUrl: ApiService.getFullImageUrl(item['originalUrl']),
                                                    fit: BoxFit.cover,
                                                    placeholder: (context, url) {
                                                      if (item['_localFilePath'] != null) {
                                                        final file = File(item['_localFilePath']);
                                                        return Image.file(file, fit: BoxFit.cover);
                                                      }
                                                      return Container(color: Colors.white10);
                                                    },
                                                  ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _isRetrying 
                                          ? 'Esperando...' 
                                          : (_statusMessage ?? 'Alistando...').toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (_isRetrying)
                                GestureDetector(
                                  onTap: () {
                                    if (!mounted) return;
                                    setState(() {
                                      _isCancelled = true;
                                      _isLoading = false;
                                      _isRetrying = false;
                                      _statusMessage = null;
                                      _processingItems = [];
                                    });
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'CANCELAR', 
                                      style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)
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
                      GestureDetector(
                        onLongPress: () {
                          final heroTag = 'selected-${index}-${isFile ? item.path : item['id']}';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OutfitDetailScreen(
                                imageUrl: isFile ? null : ApiService.getFullImageUrl(item['originalUrl']),
                                localFile: isFile ? item : null,
                                tag: heroTag,
                              ),
                            ),
                          );
                        },
                        child: Hero(
                          tag: 'selected-${index}-${isFile ? item.path : item['id']}',
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
                                        imageUrl: ApiService.getFullImageUrl(item['originalUrl']),
                                        fit: BoxFit.cover,
                                        memCacheWidth: 200, 
                                        placeholder: (context, url) {
                                          if (item['_localFilePath'] != null) {
                                            final file = File(item['_localFilePath']);
                                            return Image.file(file, fit: BoxFit.cover, cacheWidth: 200);
                                          }
                                          return Container(color: Colors.white.withOpacity(0.05));
                                        },
                                      ),
                            ),
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
                        onPressed: _selectedItems.length >= 10 ? null : () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Galería',
                        onPressed: _selectedItems.length >= 10 ? null : () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.content_paste_outlined,
                        label: 'PEGAR',
                        onPressed: _selectedItems.length >= 10 ? null : _handlePasteImage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.checkroom_outlined,
                        label: 'Closet',
                        onPressed: _selectedItems.whereType<File>().length >= 10 ? null : _openCloset,
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
                      _selectedItems.isEmpty ? 'SELECCIONA PRENDAS' : 'VESTIR (${_selectedItems.length}/10)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
