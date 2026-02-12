import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pasteboard/pasteboard.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:lasprendas_frontend/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
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
  final _storage = StorageService();

  Future<void> _resilientWrite(String key, String value) async {
    await _storage.write(key: key, value: value);
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
          setState(() {
            _selectedItems.clear();
            _selectedItems.addAll(restoredItems);
          });
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
            _statusMessage = AppLocalizations.of(context)!.loading; // "Retomando..." was here, "Cargando..." or dedicated key
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
      await _storage.delete(key: 'selected_garments');
      await _storage.delete(key: 'processing_session_id');
      await _storage.delete(key: 'processing_items');
      await _storage.delete(key: 'processing_person_type');
      await _storage.delete(key: 'result_path');
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
            SnackBar(content: Text(AppLocalizations.of(context)!.noGarmentsSaved)), // Fallback or dedicated message
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

  String _calculateGarmentsFingerprint(List<dynamic> items) {
    final List<String> identifiers = items.map((item) {
      if (item is Map) {
        return 'garment_${item['id']}';
      } else if (item is File) {
        return 'file_${item.path}';
      }
      return 'unknown';
    }).toList();
    identifiers.sort();
    return identifiers.join('|');
  }

  Future<void> _openCloset() async {
    // If we are processing, the "real" current selection is what we are processing.
    // This allows the user to go to the closet and see/edit what is on the mannequin.
    final List<dynamic> sourceItems = _isLoading ? _processingItems : _selectedItems;
    
    final List<dynamic> initialGarments = sourceItems; // Pass everything

    final dynamic result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute<dynamic>(
        builder: (context) => ClosetScreen(
          initialSelectedGarments: initialGarments,
        ),
      ),
    );

    if (result != null) {
      if (result is List) {
        final currentFingerprint = _calculateGarmentsFingerprint(sourceItems);
        final newFingerprint = _calculateGarmentsFingerprint(result);
        final hasChanged = currentFingerprint != newFingerprint;

        setState(() {
          _selectedItems.clear();
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
      _statusMessage = AppLocalizations.of(context)!.dressingStatus1 + '...';
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
            garmentIds: garmentIds,
            personType: requestedPersonType,
            hashes: hashes,
          );
          
          sessionId = response['id'] ?? response['sessionId'];
          if (sessionId == null) throw 'No se recibió el ID de la sesión';
          
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
                  
                  // Keep processing items in sync
                  final procIndex = _processingItems.indexWhere((item) => item is File && item.path == fileToRemove.path);
                  if (procIndex != -1) {
                    _processingItems[procIndex] = garment;
                  }
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
              _statusMessage = AppLocalizations.of(context)!.waiting;
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
        await _storage.write(key: 'processing_session_id', value: sessionId.toString());
        await _savePersistedState();
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
      
      final l10n = AppLocalizations.of(context)!;
      final dressingMessages = [
        l10n.dressingStatus1,
        l10n.dressingStatus2,
        l10n.dressingStatus3,
        l10n.dressingStatus4,
        l10n.dressingStatus5,
        l10n.dressingStatus6,
        l10n.dressingStatus7,
        l10n.dressingStatus8,
        l10n.dressingStatus9,
        l10n.dressingStatus10,
        l10n.dressingStatus11,
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
        SnackBar(content: Text(AppLocalizations.of(context)!.localeName == 'es' 
            ? 'El procesamiento está tardando más de lo esperado. Mira tus outfits luego.' 
            : 'Processing is taking longer than expected. Check your outfits later.')),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
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
        title: Text(
          AppLocalizations.of(context)!.appTitle, 
          style: const TextStyle(fontSize: 18, letterSpacing: 1.0, fontWeight: FontWeight.bold)
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
        child: SafeArea(
          child: Column(
            children: [
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: _resultPath != null
                            ? CachedNetworkImage(
                                imageUrl: ApiService.getFullImageUrl(_resultPath), 
                                key: ValueKey(_resultPath),
                                fit: BoxFit.contain,
                                memCacheHeight: 2400,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(color: Colors.white),
                                ),
                                errorWidget: (context, url, error) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                                      SizedBox(height: 10),
                                      Text(
                                        AppLocalizations.of(context)!.errorLoadingResult,
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
                                                  ? Image.file(item, fit: BoxFit.cover, cacheWidth: 100)
                                                  : CachedNetworkImage(
                                                      imageUrl: ApiService.getFullImageUrl(item['originalUrl']),
                                                      fit: BoxFit.cover,
                                                      memCacheWidth: 100,
                                                      placeholder: (context, url) {
                                                        if (item['_localFilePath'] != null) {
                                                          final file = File(item['_localFilePath']);
                                                          return Image.file(file, fit: BoxFit.cover, cacheWidth: 100);
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
                                          ? AppLocalizations.of(context)!.waiting 
                                          : (_statusMessage ?? AppLocalizations.of(context)!.dressingStatus1 + '...').toUpperCase(),
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
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      l10n.cancel, 
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)
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
          const SizedBox(height: 15),

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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OutfitDetailScreen(
                                imageUrl: isFile ? null : ApiService.getFullImageUrl(item['originalUrl']),
                                localFile: isFile ? item : null,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 90,
                          margin: const EdgeInsets.only(right: 15),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10, width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                isFile 
                                ? Image.file(item, fit: BoxFit.cover, cacheWidth: 400)
                                : ApiService.getFullImageUrl(item['originalUrl'] ?? '').isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: ApiService.getFullImageUrl(item['originalUrl']),
                                      fit: BoxFit.cover,
                                      memCacheWidth: 400, 
                                      placeholder: (context, url) {
                                        if (item['_localFilePath'] != null) {
                                          final file = File(item['_localFilePath']);
                                          return Image.file(file, fit: BoxFit.cover, cacheWidth: 400);
                                        }
                                        return Container(color: Colors.white.withOpacity(0.05));
                                      },
                                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white24),
                                    )
                                  : Container(
                                      color: Colors.white.withOpacity(0.05),
                                      child: const Icon(Icons.broken_image, color: Colors.white24),
                                    ),
                                if (!isFile) _buildCategoryBadge(item as Map<String, dynamic>),
                              ],
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
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.camera_alt_outlined,
                        label: l10n.camera,
                        onPressed: _selectedItems.length >= 10 ? null : () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.photo_library_outlined,
                        label: l10n.gallery,
                        onPressed: _selectedItems.length >= 10 ? null : () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.content_paste_outlined,
                        label: l10n.paste,
                        onPressed: _selectedItems.length >= 10 ? null : _handlePasteImage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.checkroom_outlined,
                        label: l10n.closetButton,
                        onPressed: _selectedItems.whereType<File>().length >= 10 ? null : _openCloset,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
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
                      _selectedItems.isEmpty 
                          ? l10n.selectGarmentsPrompt 
                          : l10n.dressButton(_selectedItems.length),
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
    ),
    );
  }

  Widget _buildCategoryBadge(Map<String, dynamic> garment) {
    dynamic metadataRaw = garment['metadata'];
    if (metadataRaw == null) return const SizedBox.shrink();

    Map<String, dynamic>? metadata;
    if (metadataRaw is List && metadataRaw.isNotEmpty) {
      metadata = metadataRaw.first as Map<String, dynamic>?;
    } else if (metadataRaw is Map) {
      metadata = Map<String, dynamic>.from(metadataRaw);
    }

    if (metadata == null || metadata['physical'] == null) {
      return const SizedBox.shrink();
    }
    final cat = metadata['physical']['category'];
    if (cat == null) return const SizedBox.shrink();
    
    final categoryName = Localizations.localeOf(context).languageCode == 'es' 
        ? (cat['es'] ?? '') 
        : (cat['en'] ?? '');

    if (categoryName.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        color: Colors.black54,
        child: Text(
          categoryName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
