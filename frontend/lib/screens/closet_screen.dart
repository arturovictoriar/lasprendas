import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lasprendas_frontend/l10n/app_localizations.dart';
import '../services/api_service.dart';

class ClosetScreen extends StatefulWidget {
  final List<dynamic> initialSelectedGarments;
  
  const ClosetScreen({
    super.key, 
    this.initialSelectedGarments = const [],
  });

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _garments = [];
  List<dynamic> _sessions = [];
  bool _isLoading = true;
  late String _selectedCategory;
  late List<String> _categories;
  
  final List<dynamic> _selectedInSession = [];
  List<dynamic> _confirmedGarments = [];
  bool _isGarmentSelectionMode = false;
  bool _isOutfitSelectionMode = false;
  final Set<String> _selectedGarmentsForDelete = {};
  final Set<String> _selectedOutfitsForDelete = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          if (_tabController.indexIsChanging) {
            // Reset garments to initial state
            _selectedInSession.clear();
            _selectedInSession.addAll(_confirmedGarments);
            
            _selectedGarmentsForDelete.clear();
            for (var g in _confirmedGarments) {
              if (g is Map) {
                _selectedGarmentsForDelete.add(g['id'].toString());
              }
            }
            _isGarmentSelectionMode = _selectedInSession.isNotEmpty;

            // Reset outfits
            _selectedOutfitsForDelete.clear();
            _isOutfitSelectionMode = false;
          }
        });
      }
    });
    _selectedInSession.addAll(widget.initialSelectedGarments);
    _confirmedGarments = List.from(widget.initialSelectedGarments);
    if (_selectedInSession.isNotEmpty) {
      _isGarmentSelectionMode = true;
      for (var g in widget.initialSelectedGarments) {
        if (g is Map) {
          _selectedGarmentsForDelete.add(g['id'].toString());
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    _selectedCategory = l10n.allCategories;
    _categories = [
      l10n.allCategories,
      l10n.shirtsCategory,
      l10n.pantsCategory,
      l10n.shoesCategory,
      l10n.skirtsCategory,
      l10n.jacketsCategory,
      l10n.accessoriesCategory,
    ];
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
        SnackBar(content: Text('${AppLocalizations.of(context)!.localeName == 'es' ? 'Error cargando closet' : 'Error loading closet'}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredGarments {
    if (_selectedCategory == AppLocalizations.of(context)!.allCategories) return _garments;
    return _garments.where((g) {
      final cat = g['category']?.toString().toLowerCase();
      // This is a bit tricky if categories in DB are Spanish but localized. 
      // Assuming DB categories are fixed and we map them or matching English/Spanish.
      // For now, let's stick to the logic but be aware of the translation mapping.
      return cat == _selectedCategory.toLowerCase();
    }).toList();
  }

  List<dynamic> get _filteredSessions {
    final allLabel = AppLocalizations.of(context)!.allCategories;
    if (_selectedCategory == allLabel) return _sessions;
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
      final index = _selectedInSession.indexWhere((g) => g is Map && g['id'].toString() == garment['id'].toString());
      if (index >= 0) {
        _selectedInSession.removeAt(index);
      } else {
        if (_selectedInSession.length < 10) {
          _selectedInSession.add(garment);
        } else {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.localeName == 'es' 
                  ? 'Ya tienes ${_selectedInSession.length} prendas. El máximo es 10.'
                  : 'You already have ${_selectedInSession.length} garments. The maximum is 10.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  Future<void> _handleBulkDelete() async {
    final isLibraryTab = _tabController.index == 0;
    final gCount = _selectedGarmentsForDelete.length;
    final sCount = _selectedOutfitsForDelete.length;

    if (isLibraryTab && gCount == 0) return;
    if (!isLibraryTab && sCount == 0) return;

    String message = '¿Eliminar ';
    if (isLibraryTab) {
      message += '$gCount prenda${gCount > 1 ? 's' : ''}';
    } else {
      message += '$sCount outfit${sCount > 1 ? 's' : ''}';
    }
    message += '?';

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(l10n.confirmDeleteTitle, style: const TextStyle(color: Colors.white)),
        content: Text(
          l10n.deleteItemConfirm(
            isLibraryTab ? gCount : sCount,
            isLibraryTab 
                ? (gCount > 1 ? l10n.prendas : l10n.prenda)
                : (sCount > 1 ? l10n.outfits : l10n.outfit)
          ),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteSelected, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        if (isLibraryTab) {
          for (final id in _selectedGarmentsForDelete) {
            await ApiService.deleteGarment(id);
          }
          setState(() {
            _garments.removeWhere((g) => _selectedGarmentsForDelete.contains(g['id'].toString()));
            _selectedInSession.removeWhere((g) => g is Map && _selectedGarmentsForDelete.contains(g['id'].toString()));
            _confirmedGarments.removeWhere((g) => _selectedGarmentsForDelete.contains(g['id'].toString()));
            _selectedGarmentsForDelete.clear();
            _isGarmentSelectionMode = false;
          });
        } else {
          for (final id in _selectedOutfitsForDelete) {
            await ApiService.deleteSession(id);
          }
          setState(() {
            _sessions.removeWhere((s) => _selectedOutfitsForDelete.contains(s['id'].toString()));
            _selectedOutfitsForDelete.clear();
            _isOutfitSelectionMode = false;
          });
        }
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white70),
          onPressed: () => Navigator.pop(context, _confirmedGarments),
        ),
        title: Text(l10n.closetTitle, style: const TextStyle(fontSize: 18, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: l10n.myGarmentsTab),
            Tab(text: l10n.myOutfitsTab),
          ],
        ),
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
          child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildLibraryTab(),
                  _buildOutfitsTab(),
                ],
              ),
        ),
      ),
      bottomNavigationBar: _shouldShowBottomBar() ? _buildBottomBar() : null,
    );
  }

  bool _shouldShowBottomBar() {
    if (_isLoading) return false;
    if (_tabController.index == 0) {
      return _garments.isNotEmpty;
    } else {
      return _sessions.isNotEmpty;
    }
  }

  Widget _buildBottomBar() {
    final totalCount = _selectedInSession.length;
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.only(
            left: 20, 
            right: 20, 
            top: 8, 
            bottom: MediaQuery.of(context).padding.bottom + 4
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -2))
            ],
          ),
          child: _tabController.index == 0 
            ? (_isGarmentSelectionMode ? _buildEditModeActions() : _buildNormalModeActions(totalCount))
            : (_isOutfitSelectionMode ? _buildEditModeActions() : _buildNormalModeActions(totalCount)),
        );
      },
    );
  }

  Widget _buildNormalModeActions(int totalCount) {
    return Container(
      height: 48,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ElevatedButton.icon(
        onPressed: () => setState(() {
          if (_tabController.index == 0) {
            _isGarmentSelectionMode = true;
          } else {
            _isOutfitSelectionMode = true;
          }
        }),
        icon: const Icon(Icons.check_circle_outline, size: 20),
        label: Text(AppLocalizations.of(context)!.selectButton, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Widget _buildEditModeActions() {
    final totalCount = _selectedInSession.length;
    final isLibraryTab = _tabController.index == 0;
    final hasDeleteSelection = isLibraryTab ? _selectedGarmentsForDelete.isNotEmpty : _selectedOutfitsForDelete.isNotEmpty;

    return Row(
      children: [
        TextButton(
          onPressed: () => setState(() {
            if (isLibraryTab) {
              _isGarmentSelectionMode = false;
              _selectedGarmentsForDelete.clear();
              _selectedInSession.clear();
              _confirmedGarments.clear();
            } else {
              _isOutfitSelectionMode = false;
              _selectedOutfitsForDelete.clear();
            }
          }),
          child: Text(AppLocalizations.of(context)!.cancel, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Container(
          height: 45,
          decoration: BoxDecoration(
            color: hasDeleteSelection ? Colors.redAccent.withOpacity(0.2) : Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.delete_outline, color: hasDeleteSelection ? Colors.redAccent : Colors.white24),
            onPressed: hasDeleteSelection ? _handleBulkDelete : null,
            tooltip: 'Eliminar seleccionados',
          ),
        ),
        const SizedBox(width: 8),
        if (isLibraryTab)
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: totalCount > 0 
                  ? const LinearGradient(colors: [Color(0xFF424242), Color(0xFF212121)])
                  : null,
                color: totalCount == 0 ? Colors.white.withOpacity(0.05) : null,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ElevatedButton(
                onPressed: totalCount == 0 ? null : () => Navigator.pop(context, _selectedInSession),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text(AppLocalizations.of(context)!.useButton(totalCount), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          )
        else
          const Spacer(),
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
      return Center(child: Text(AppLocalizations.of(context)!.noGarmentsSaved, style: const TextStyle(color: Colors.white54)));
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
              final isSelected = _selectedInSession.any((g) => g is Map && g['id'].toString() == garment['id'].toString());
              
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () {
                  if (_isGarmentSelectionMode) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => OutfitDetailScreen(
                      imageUrl: ApiService.getFullImageUrl(garment['originalUrl']),
                      tag: 'garment-${garment['id']}',
                    )));
                  }
                },
                onTap: () {
                  if (_isGarmentSelectionMode) {
                    _toggleSelection(garment);
                    setState(() {
                      final id = garment['id'].toString();
                      if (_selectedGarmentsForDelete.contains(id)) {
                        _selectedGarmentsForDelete.remove(id);
                      } else {
                        _selectedGarmentsForDelete.add(id);
                      }
                    });
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => OutfitDetailScreen(
                      imageUrl: ApiService.getFullImageUrl(garment['originalUrl']),
                      tag: 'garment-${garment['id']}',
                    )));
                  }
                },
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? Colors.white : Colors.white10, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        clipBehavior: Clip.antiAlias,
                        child: Hero(
                          tag: 'garment-${garment['id']}',
                          child: CachedNetworkImage(
                            imageUrl: ApiService.getFullImageUrl(garment['originalUrl']),
                            fit: BoxFit.cover,
                            memCacheWidth: 200,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            placeholder: (context, url) => Container(color: Colors.white10),
                            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                    if (_isGarmentSelectionMode)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue : Colors.black45,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Icon(
                            isSelected ? Icons.check : null,
                            size: 14,
                            color: isSelected ? Colors.white : Colors.transparent,
                          ),
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
      return Center(child: Text(AppLocalizations.of(context)!.noOutfitsSaved, style: const TextStyle(color: Colors.white54)));
    }
    final filtered = _filteredSessions;
    return Column(
      children: [
        const SizedBox(height: 10),
        _buildCategoryFilters(),
        Expanded(
          child: filtered.isEmpty 
            ? _buildNoSessionsMessage()
            : GridView.builder(
                padding: const EdgeInsets.all(15),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                  childAspectRatio: 0.7,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final session = filtered[index];
                  final isSelected = _selectedOutfitsForDelete.contains(session['id'].toString());
                  return GestureDetector(
                    onTap: () async {
                      if (_isOutfitSelectionMode) {
                        setState(() {
                          final id = session['id'].toString();
                          if (isSelected) {
                            _selectedOutfitsForDelete.remove(id);
                          } else {
                            _selectedOutfitsForDelete.add(id);
                          }
                        });
                      } else {
                        final result = await Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (context) => OutfitManagementScreen(session: session)
                          )
                        );
                        if (result != null && result is Map && result['type'] == 'retake') {
                          Navigator.pop(context, result);
                        }
                      }
                    },
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(15),
                            border: isSelected
                                ? Border.all(color: Colors.blue, width: 2)
                                : Border.all(color: Colors.white10, width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            clipBehavior: Clip.antiAlias,
                            child: session['resultUrl'] != null && session['resultUrl'].toString().isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: ApiService.getFullImageUrl(session['resultUrl']),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  memCacheWidth: 400,
                                  fadeInDuration: Duration.zero,
                                  fadeOutDuration: Duration.zero,
                                  placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white10),
                                )
                              : Container(
                                  color: Colors.white.withOpacity(0.05),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 30),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Generando outfit...',
                                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ),
                        ),
                        if (_isOutfitSelectionMode)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue : Colors.black45,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Icon(
                                isSelected ? Icons.check : null,
                                size: 14,
                                color: isSelected ? Colors.white : Colors.transparent,
                              ),
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

  Widget _buildNoSessionsMessage() {
    final allLabel = AppLocalizations.of(context)!.allCategories;
    if (_selectedCategory == allLabel) {
      return Center(child: Text(AppLocalizations.of(context)!.noOutfitsSaved, style: const TextStyle(color: Colors.white54)));
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
              AppLocalizations.of(context)!.localeName == 'es' 
                  ? 'No hay outfits con ${_selectedCategory.toLowerCase()}'
                  : 'No outfits with ${_selectedCategory.toLowerCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class OutfitManagementScreen extends StatelessWidget {
  final Map<String, dynamic> session;

  const OutfitManagementScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final garments = session['garments'] as List;
    final mannequinUrl = session['mannequinUrl'] ?? '';
    // Robust gender detection: check personType field first, then fallback to URL parsing.
    // NOTE: Check for 'female' first because 'female' contains 'male'.
    final gender = session['personType'] ?? 
        (mannequinUrl.contains('female') ? 'female' : (mannequinUrl.contains('male') ? 'male' : 'female'));
    final dateStr = session['createdAt'].toString().substring(0, 10);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('OUTFIT $dateStr', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
        centerTitle: true,
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Result Image
                Center(
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.53,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
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
                        child: session['resultUrl'] != null && session['resultUrl'].toString().isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: ApiService.getFullImageUrl(session['resultUrl']),
                              fit: BoxFit.contain,
                              memCacheHeight: 1200,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white24)),
                              errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white10, size: 50),
                            )
                          : const Center(child: Icon(Icons.auto_awesome, color: Colors.white10, size: 80)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                
                // Retake Button
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF424242), Color(0xFF212121)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, {
                        'type': 'retake',
                        'garments': session['garments'],
                        'gender': gender,
                        'resultUrl': session['resultUrl'],
                      });
                    },
                    icon: const Icon(Icons.tune, color: Colors.white, size: 20),
                    label: Text(
                      AppLocalizations.of(context)!.retakeOutfit, 
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Reference Garments
                Text(
                  AppLocalizations.of(context)!.garmentsUsed,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: garments.length,
                    itemBuilder: (context, index) {
                      final g = garments[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => OutfitDetailScreen(
                            imageUrl: ApiService.getFullImageUrl(g['originalUrl']),
                            tag: 'outfit-garment-${session['id']}-${g['id']}',
                          )));
                        },
                        child: Hero(
                          tag: 'outfit-garment-${session['id']}-${g['id']}',
                          child: Container(
                            width: 90,
                            margin: const EdgeInsets.only(right: 15),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              clipBehavior: Clip.antiAlias,
                              child: CachedNetworkImage(
                                imageUrl: ApiService.getFullImageUrl(g['originalUrl']),
                                fit: BoxFit.cover,
                                memCacheWidth: 200,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                                errorWidget: (context, url, error) => const Icon(Icons.error, size: 20, color: Colors.white10),
                              ),
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
        ),
      ),
    );
  }
}

class OutfitDetailScreen extends StatelessWidget {
  final String? imageUrl;
  final File? localFile;
  final String tag;

  const OutfitDetailScreen({
    super.key, 
    this.imageUrl, 
    this.localFile, 
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background-lasprendas.png'),
            fit: BoxFit.cover,
            opacity: 0.5,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: tag,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: localFile != null 
                    ? Image.file(localFile!, fit: BoxFit.contain)
                    : CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.contain,
                        memCacheHeight: 1200, // Optimized for detail view
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
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
      ),
    );
  }
}
