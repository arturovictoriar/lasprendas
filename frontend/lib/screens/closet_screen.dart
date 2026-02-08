import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';

class ClosetScreen extends StatefulWidget {
  final List<dynamic> initialSelectedGarments;
  final int externalCount;
  
  const ClosetScreen({
    super.key, 
    this.initialSelectedGarments = const [],
    this.externalCount = 0,
  });

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _garments = [];
  List<dynamic> _sessions = [];
  bool _isLoading = true;
  String _selectedCategory = 'Todas';
  final List<String> _categories = ['Todas', 'Camisas', 'Pantalones', 'Zapatos', 'Faldas', 'Chaquetas', 'Accesorios'];
  
  final List<dynamic> _selectedInSession = [];
  bool _isEditMode = false;
  final Set<String> _selectedGarmentsForDelete = {};
  final Set<String> _selectedOutfitsForDelete = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          // Reset edit mode and selections when moving between tabs
          if (_tabController.indexIsChanging) {
            _isEditMode = false;
            _selectedGarmentsForDelete.clear();
            _selectedOutfitsForDelete.clear();
          }
        });
      }
    });
    _selectedInSession.addAll(widget.initialSelectedGarments);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final garments = await ApiService.getGarments();
      final sessions = await ApiService.getSessions();
      if (!mounted) return;
      setState(() {
        _garments = garments;
        _sessions = sessions;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando closet: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredGarments {
    if (_selectedCategory == 'Todas') return _garments;
    return _garments.where((g) {
      final cat = g['category']?.toString().toLowerCase();
      return cat == _selectedCategory.toLowerCase();
    }).toList();
  }

  List<dynamic> get _filteredSessions {
    if (_selectedCategory == 'Todas') return _sessions;
    return _sessions.where((session) {
      final garments = session['garments'] as List<dynamic>? ?? [];
      return garments.any((g) {
        final cat = g['category']?.toString().toLowerCase();
        return cat == _selectedCategory.toLowerCase();
      });
    }).toList();
  }

  void _toggleSelection(dynamic garment) {
    setState(() {
      final index = _selectedInSession.indexWhere((g) => g['id'].toString() == garment['id'].toString());
      if (index >= 0) {
        _selectedInSession.removeAt(index);
      } else {
        if (_selectedInSession.length + widget.externalCount < 10) {
          _selectedInSession.add(garment);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ya tienes ${widget.externalCount + _selectedInSession.length} prendas. El máximo es 10.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  Future<void> _handleBulkDelete() async {
    final gCount = _selectedGarmentsForDelete.length;
    final sCount = _selectedOutfitsForDelete.length;
    if (gCount == 0 && sCount == 0) return;

    String message = '¿Eliminar ';
    if (gCount > 0) message += '$gCount prenda${gCount > 1 ? 's' : ''}';
    if (gCount > 0 && sCount > 0) message += ' y ';
    if (sCount > 0) message += '$sCount outfit${sCount > 1 ? 's' : ''}';
    message += '?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Confirmar eliminación', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ELIMINAR TODO', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        for (final id in _selectedGarmentsForDelete) {
          await ApiService.deleteGarment(id);
        }
        for (final id in _selectedOutfitsForDelete) {
          await ApiService.deleteSession(id);
        }
        
        setState(() {
          _garments.removeWhere((g) => _selectedGarmentsForDelete.contains(g['id'].toString()));
          _selectedInSession.removeWhere((g) => _selectedGarmentsForDelete.contains(g['id'].toString()));
          _sessions.removeWhere((s) => _selectedOutfitsForDelete.contains(s['id'].toString()));
          _selectedGarmentsForDelete.clear();
          _selectedOutfitsForDelete.clear();
          _isEditMode = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _selectedInSession.length + widget.externalCount;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'CLOSET', 
          style: TextStyle(fontSize: 18, letterSpacing: 1.0, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'MIS PRENDAS'),
            Tab(text: 'MIS OUTFITS'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildLibraryTab(),
                _buildOutfitsTab(),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(totalCount),
    );
  }

  Widget _buildBottomBar(int totalCount) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.only(
            left: 20, 
            right: 20, 
            top: 15, 
            bottom: MediaQuery.of(context).padding.bottom + 15
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -2))
            ],
          ),
          child: _isEditMode ? _buildEditModeActions() : _buildNormalModeActions(totalCount),
        );
      },
    );
  }

  Widget _buildNormalModeActions(int totalCount) {
    final isLibraryTab = _tabController.index == 0;
    
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
          ),
          child: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: () => setState(() {
              _isEditMode = true;
              _selectedInSession.clear();
            }),
            tooltip: 'Entrar en modo borrado',
          ),
        ),
        if (isLibraryTab) ...[
          const SizedBox(width: 15),
          Expanded(
            child: Container(
              height: 55,
              decoration: BoxDecoration(
                gradient: totalCount > 0 
                  ? const LinearGradient(colors: [Color(0xFF424242), Color(0xFF212121)])
                  : null,
                color: totalCount == 0 ? Colors.white.withOpacity(0.05) : null,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ElevatedButton(
                onPressed: totalCount == 0 
                  ? null 
                  : () => Navigator.pop(context, _selectedInSession),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'USAR PRENDAS ($totalCount/10)',
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else
          const Spacer(),
      ],
    );
  }

  Widget _buildEditModeActions() {
    final hasSelection = _selectedGarmentsForDelete.isNotEmpty || _selectedOutfitsForDelete.isNotEmpty;
    final totalDelete = _selectedGarmentsForDelete.length + _selectedOutfitsForDelete.length;

    return Row(
      children: [
        TextButton(
          onPressed: () => setState(() {
            _isEditMode = false;
            _selectedGarmentsForDelete.clear();
            _selectedOutfitsForDelete.clear();
          }),
          child: const Text('CANCELAR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 55,
            decoration: BoxDecoration(
              color: hasSelection ? Colors.redAccent : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(18),
            ),
            child: ElevatedButton.icon(
              onPressed: hasSelection ? _handleBulkDelete : null,
              icon: const Icon(Icons.delete, size: 20),
              label: Text(
                hasSelection ? 'ELIMINAR ($totalDelete)' : 'BORRAR SELECCIONADOS',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white24,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedCategory = cat),
              backgroundColor: const Color(0xFF1E1E1E),
              selectedColor: Colors.white,
              labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white70),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLibraryTab() {
    if (_garments.isEmpty) {
      return const Center(child: Text('Aún no tienes prendas guardadas', style: TextStyle(color: Colors.white54)));
    }
    return Column(
      children: [
        const SizedBox(height: 10),
        _buildCategoryFilters(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(15),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.8,
            ),
            itemCount: _filteredGarments.length,
            itemBuilder: (context, index) {
              final garment = _filteredGarments[index];
              final isSelected = _selectedInSession.any((g) => g['id'].toString() == garment['id'].toString());
              
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () {
                  if (!_isEditMode) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OutfitDetailScreen(
                          imageUrl: ApiService.getFullImageUrl(garment['originalUrl']),
                          tag: 'garment-${garment['id']}',
                        ),
                      ),
                    );
                  }
                },
                onTap: () {
                  if (_isEditMode) {
                    setState(() {
                      final id = garment['id'].toString();
                      if (_selectedGarmentsForDelete.contains(id)) {
                        _selectedGarmentsForDelete.remove(id);
                      } else {
                        _selectedGarmentsForDelete.add(id);
                      }
                    });
                  } else {
                    _toggleSelection(garment);
                  }
                },
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isEditMode 
                            ? (_selectedGarmentsForDelete.contains(garment['id'].toString()) ? Colors.redAccent : Colors.white10)
                            : (isSelected ? Colors.white : Colors.white10),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Hero(
                          tag: 'garment-${garment['id']}',
                          child: CachedNetworkImage(
                            imageUrl: ApiService.getFullImageUrl(garment['originalUrl']),
                            fit: BoxFit.cover,
                            memCacheWidth: 200, // Small thumbnail size
                            placeholder: (context, url) => Container(color: Colors.white10),
                            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                    if (isSelected && !_isEditMode)
                      Positioned(
                        right: 5,
                        top: 5,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.check, size: 16, color: Colors.black),
                        ),
                      ),
                    if (_isEditMode && _selectedGarmentsForDelete.contains(garment['id'].toString()))
                      Positioned(
                        right: 5,
                        top: 5,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                          child: const Icon(Icons.check, size: 16, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOutfitsTab() {
    if (_sessions.isEmpty) {
      return const Center(child: Text('Aún no tienes outfits guardados', style: TextStyle(color: Colors.white54)));
    }
    final filtered = _filteredSessions;
    return Column(
      children: [
        const SizedBox(height: 10),
        _buildCategoryFilters(),
        Expanded(
          child: filtered.isEmpty 
            ? _buildNoSessionsMessage()
            : ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final session = filtered[index];

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_isEditMode) {
              setState(() {
                final id = session['id'].toString();
                if (_selectedOutfitsForDelete.contains(id)) {
                  _selectedOutfitsForDelete.remove(id);
                } else {
                  _selectedOutfitsForDelete.add(id);
                }
              });
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: _isEditMode && _selectedOutfitsForDelete.contains(session['id'].toString())
                  ? Border.all(color: Colors.redAccent, width: 3)
                  : Border.all(color: Colors.transparent, width: 3),
            ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_isEditMode) {
                        setState(() {
                          final id = session['id'].toString();
                          if (_selectedOutfitsForDelete.contains(id)) {
                            _selectedOutfitsForDelete.remove(id);
                          } else {
                            _selectedOutfitsForDelete.add(id);
                          }
                        });
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OutfitDetailScreen(
                              imageUrl: ApiService.getFullImageUrl(session['resultUrl']),
                              tag: 'outfit-${session['id']}',
                            ),
                          ),
                        );
                      }
                    },
                    child: Hero(
                      tag: 'outfit-${session['id']}',
                      child: Container(
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                          child: CachedNetworkImage(
                            imageUrl: ApiService.getFullImageUrl(session['resultUrl']),
                            width: double.infinity,
                            height: 300,
                            fit: BoxFit.cover,
                            memCacheHeight: 600, // Medium size for outfit preview
                            placeholder: (context, url) => Container(
                              height: 300,
                              color: Colors.white10,
                              child: const Center(child: CircularProgressIndicator(color: Colors.white24)),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 300,
                              color: Colors.white10,
                              child: const Icon(Icons.broken_image, color: Colors.white24, size: 50),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Outfit ${session['createdAt'].toString().substring(0, 10)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            if (!_isEditMode)
                              ElevatedButton.icon(
                                onPressed: () {
                                  final mannequinUrl = session['mannequinUrl'] ?? '';
                                  final gender = mannequinUrl.contains('male_mannequin') ? 'male' : 'female';
                                  
                                  Navigator.pop(context, {
                                    'type': 'retake',
                                    'garments': session['garments'],
                                    'gender': gender,
                                    'resultUrl': session['resultUrl'],
                                  });
                                },
                                icon: const Icon(Icons.tune, size: 16),
                                label: const Text('RETOMAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white10,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: Colors.white24),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(), // Reduce conflict with tab swiping
                            itemCount: (session['garments'] as List).length,
                            itemBuilder: (context, gIndex) {
                              final g = session['garments'][gIndex];
                              return Container(
                                width: 50,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => OutfitDetailScreen(
                                          imageUrl: ApiService.getFullImageUrl(g['originalUrl']),
                                          tag: 'outfit-thumb-${session['id']}-${g['id']}',
                                        ),
                                      ),
                                    );
                                  },
                                  child: Hero(
                                    tag: 'outfit-thumb-${session['id']}-${g['id']}',
                                    child: CachedNetworkImage(
                                      imageUrl: ApiService.getFullImageUrl(g['originalUrl']),
                                      fit: BoxFit.cover,
                                      memCacheWidth: 100, // Very small thumbnail
                                      placeholder: (context, url) => Container(color: Colors.white10),
                                      errorWidget: (context, url, error) => const Icon(Icons.error, size: 16),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isEditMode && _selectedOutfitsForDelete.contains(session['id'].toString()))
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1),
                      ],
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 24),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  ),
),
      ],
    );
  }

  Widget _buildNoSessionsMessage() {
    if (_selectedCategory == 'Todas') {
      return const Center(child: Text('Aún no tienes outfits guardados', style: TextStyle(color: Colors.white54)));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, color: Colors.white24, size: 60),
            const SizedBox(height: 15),
            Text(
              'No hay outfits con ${_selectedCategory.toLowerCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class OutfitDetailScreen extends StatelessWidget {
  final String imageUrl;
  final String tag;

  const OutfitDetailScreen({super.key, required this.imageUrl, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: tag,
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  memCacheHeight: 1200, // Optimized for detail view
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white24)
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white24),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
