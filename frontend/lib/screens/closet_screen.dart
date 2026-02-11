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
  
  final TextEditingController _searchController = TextEditingController();
  bool _isSmartSearchLoading = false;
  List<dynamic>? _aiResults;
  bool _isSmartSearchActive = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          if (_tabController.indexIsChanging) {
            // Reset search when switching tabs
            _searchController.clear();
            _isSmartSearchActive = false;
            _aiResults = null;

            // Reset selection state
            _selectedInSession.clear();
            _selectedInSession.addAll(_confirmedGarments);
            
            _selectedGarmentsForDelete.clear();
            for (var g in _confirmedGarments) {
              if (g is Map) {
                _selectedGarmentsForDelete.add(g['id'].toString());
              }
            }
            _isGarmentSelectionMode = _selectedInSession.isNotEmpty;
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
    _searchController.dispose();
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

  Future<void> _handleSmartSearch() async {
    final query = _searchController.text.trim();
    final isOutfitsTab = _tabController.index == 1;

    if (query.isEmpty) {
      setState(() {
        _isSmartSearchActive = false;
        _aiResults = null;
      });
      return;
    }

    setState(() {
      _isSmartSearchLoading = true;
      _isSmartSearchActive = true;
    });

    try {
      String? category;
      if (_selectedCategory != AppLocalizations.of(context)!.allCategories) {
        // Find DB category name if localized. 
        // For now using the simple matching.
        category = _selectedCategory;
      }

      if (isOutfitsTab) {
        final results = await ApiService.smartSearchSessions(query: query, category: category);
        setState(() => _aiResults = results);
      } else {
        final results = await ApiService.smartSearch(query: query, category: category);
        setState(() => _aiResults = results);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSmartSearchLoading = false);
    }
  }

  List<dynamic> get _filteredGarments {
    if (_selectedCategory == AppLocalizations.of(context)!.allCategories) return _garments;
    return _garments.where((g) {
      if (g['metadata'] == null || g['metadata']['physical'] == null) return false;
      final cat = g['metadata']['physical']['category'];
      final categoryName = (cat['en'] ?? cat['es'] ?? '').toString().toLowerCase();
      final categoryNameEs = (cat['es'] ?? '').toString().toLowerCase();
      return categoryName == _selectedCategory.toLowerCase() || categoryNameEs == _selectedCategory.toLowerCase();
    }).toList();
  }

  List<dynamic> get _filteredSessions {
    final allLabel = AppLocalizations.of(context)!.allCategories;
    if (_selectedCategory == allLabel) return _sessions;
    return _sessions.where((session) {
      final garments = session['garments'] as List<dynamic>? ?? [];
      return garments.any((g) {
        if (g['metadata'] == null || g['metadata']['physical'] == null) return false;
        final cat = g['metadata']['physical']['category'];
        final categoryName = (cat['en'] ?? cat['es'] ?? '').toString().toLowerCase();
        final categoryNameEs = (cat['es'] ?? '').toString().toLowerCase();
        return categoryName == _selectedCategory.toLowerCase() || categoryNameEs == _selectedCategory.toLowerCase();
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
                  ? 'Máximo 10 prendas' 
                  : 'Maximum 10 garments'),
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
    final count = isLibraryTab ? gCount : sCount;

    if (count == 0) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(l10n.confirmDeleteTitle, style: const TextStyle(color: Colors.white)),
        content: Text(
          l10n.deleteItemConfirm(
            count,
            isLibraryTab ? (gCount > 1 ? l10n.prendas : l10n.prenda) : (sCount > 1 ? l10n.outfits : l10n.outfit)
          ),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.deleteSelected, style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        if (isLibraryTab) {
          for (final id in _selectedGarmentsForDelete) await ApiService.deleteGarment(id);
          setState(() {
            _garments.removeWhere((g) => _selectedGarmentsForDelete.contains(g['id'].toString()));
            _selectedGarmentsForDelete.clear();
          });
        } else {
          for (final id in _selectedOutfitsForDelete) await ApiService.deleteSession(id);
          setState(() {
            _sessions.removeWhere((s) => _selectedOutfitsForDelete.contains(s['id'].toString()));
            _selectedOutfitsForDelete.clear();
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        title: Text(l10n.closetTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [Tab(text: l10n.myGarmentsTab), Tab(text: l10n.myOutfitsTab)],
        ),
      ),
      body: Container(
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
                children: [_buildLibraryTab(), _buildOutfitsTab()],
              ),
        ),
      ),
      bottomNavigationBar: _shouldShowBottomBar() ? _buildBottomBar() : null,
    );
  }

  bool _shouldShowBottomBar() {
    if (_isLoading) return false;
    return _tabController.index == 0 ? _garments.isNotEmpty : _sessions.isNotEmpty;
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(context).padding.bottom + 4),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: _tabController.index == 0 
        ? (_isGarmentSelectionMode ? _buildEditModeActions() : _buildNormalModeActions())
        : (_isOutfitSelectionMode ? _buildEditModeActions() : _buildNormalModeActions()),
    );
  }

  Widget _buildNormalModeActions() {
    return ElevatedButton.icon(
      onPressed: () => setState(() => _tabController.index == 0 ? _isGarmentSelectionMode = true : _isOutfitSelectionMode = true),
      icon: const Icon(Icons.check_circle_outline),
      label: Text(AppLocalizations.of(context)!.selectButton),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
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
            } else {
              _isOutfitSelectionMode = false;
              _selectedOutfitsForDelete.clear();
            }
          }),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: hasDeleteSelection ? Colors.redAccent : Colors.white24),
          onPressed: hasDeleteSelection ? _handleBulkDelete : null,
        ),
        if (isLibraryTab)
          Expanded(
            child: ElevatedButton(
              onPressed: totalCount == 0 ? null : () => Navigator.pop(context, _selectedInSession),
              child: Text(AppLocalizations.of(context)!.useButton(totalCount)),
            ),
          )
        else
          const Spacer(),
      ],
    );
  }

  Widget _buildSearchBar() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: l10n.localeName == 'es' ? 'Busca por color, estilo u ocasión...' : 'Search...',
          prefixIcon: const Icon(Icons.auto_awesome, color: Colors.blueAccent),
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.close), onPressed: () {
            _searchController.clear();
            setState(() { _isSmartSearchActive = false; _aiResults = null; });
          }) : null,
        ),
        onSubmitted: (_) => _handleSmartSearch(),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedCategory = cat),
              selectedColor: Colors.white,
              labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white70),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLibraryTab() {
    final listToShow = _isSmartSearchActive && _aiResults != null ? _aiResults! : _filteredGarments;
    return Column(
      children: [
        _buildSearchBar(),
        _buildCategoryFilters(),
        if (_isSmartSearchLoading) const LinearProgressIndicator(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(15),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: listToShow.length,
            itemBuilder: (context, index) {
              final garment = listToShow[index];
              final isSelected = _selectedInSession.any((g) => g is Map && g['id'].toString() == garment['id'].toString());
              return GestureDetector(
                onTap: () {
                  if (_isGarmentSelectionMode) {
                    _toggleSelection(garment);
                    setState(() {
                      final id = garment['id'].toString();
                      if (_selectedGarmentsForDelete.contains(id)) _selectedGarmentsForDelete.remove(id);
                      else _selectedGarmentsForDelete.add(id);
                    });
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => OutfitDetailScreen(
                      imageUrl: ApiService.getFullImageUrl(garment['originalUrl']),
                      tag: 'garment-${garment['id']}',
                    )));
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? Colors.blue : Colors.white10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: ApiService.getFullImageUrl(garment['originalUrl']),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.white05),
                        ),
                        _buildCategoryBadge(garment),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOutfitsTab() {
    final listToShow = _isSmartSearchActive && _aiResults != null ? _aiResults! : _filteredSessions;
    return Column(
      children: [
        _buildSearchBar(),
        _buildCategoryFilters(),
        if (_isSmartSearchLoading) const LinearProgressIndicator(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(15),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15),
            itemCount: listToShow.length,
            itemBuilder: (context, index) {
              final session = listToShow[index];
              final isSelected = _selectedOutfitsForDelete.contains(session['id'].toString());
              return GestureDetector(
                onTap: () async {
                  if (_isOutfitSelectionMode) {
                    setState(() {
                      final id = session['id'].toString();
                      if (isSelected) _selectedOutfitsForDelete.remove(id);
                      else _selectedOutfitsForDelete.add(id);
                    });
                  } else {
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => OutfitManagementScreen(session: session)));
                    if (result != null && result is Map && result['type'] == 'retake') Navigator.pop(context, result);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: CachedNetworkImage(imageUrl: ApiService.getFullImageUrl(session['resultUrl']), fit: BoxFit.cover),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: tag,
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white24),
                errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white24),
              ),
            ),
          ),
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
                Text(
                  AppLocalizations.of(context)!.garmentsUsed,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: garments.length,
                    itemBuilder: (context, index) {
                      final garment = garments[index];
                      String categoryName = '';
                      if (garment['metadata'] != null && garment['metadata']['physical'] != null) {
                        final cat = garment['metadata']['physical']['category'];
                        categoryName = Localizations.localeOf(context).languageCode == 'es' 
                            ? (cat['es'] ?? '') 
                            : (cat['en'] ?? '');
                      }
                      return Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: ApiService.getFullImageUrl(garment['originalUrl']),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.white05),
                              ),
                              if (categoryName.isNotEmpty)
                                Positioned(
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
                                ),
                            ],
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
