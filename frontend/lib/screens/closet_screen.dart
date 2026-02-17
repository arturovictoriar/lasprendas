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
  
  final List<dynamic> _selectedInSession = [];
  List<dynamic> _confirmedGarments = [];
  bool _isGarmentSelectionMode = false;
  bool _isOutfitSelectionMode = false;
  bool _isDeletionMode = false;
  final Set<String> _selectedGarmentsForDelete = {};
  final Set<String> _selectedOutfitsForDelete = {};
  
  final TextEditingController _searchController = TextEditingController();
  bool _isSmartSearchLoading = false;
  List<dynamic>? _aiResults;
  bool _isSmartSearchActive = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          if (_tabController.indexIsChanging) {
            // Dismiss keyboard when switching tabs
            FocusScope.of(context).unfocus();
            
            // Reset search when switching tabs
            _searchController.clear();
            _isSmartSearchActive = false;
            _aiResults = null;

            // Reset category filter
            _selectedCategory = AppLocalizations.of(context)!.allCategories;

            // Reset deletion state when switching tabs
            _selectedGarmentsForDelete.clear();
            _selectedOutfitsForDelete.clear();
            _isDeletionMode = false;
          }
        });
      }
    });
    _selectedInSession.addAll(widget.initialSelectedGarments);
    _confirmedGarments = List.from(widget.initialSelectedGarments);
    if (_selectedInSession.isNotEmpty) {
      _isGarmentSelectionMode = true;
    }
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final l10n = AppLocalizations.of(context)!;
      _selectedCategory = l10n.allCategories;
      _isInitialized = true;
    }
  }

  String _getGarmentCategory(Map<String, dynamic> g) {
    dynamic metadataRaw = g['metadata'];
    Map<String, dynamic>? metadata;
    if (metadataRaw is List && metadataRaw.isNotEmpty) {
      metadata = metadataRaw.first as Map<String, dynamic>?;
    } else if (metadataRaw is Map) {
      metadata = Map<String, dynamic>.from(metadataRaw);
    }
    if (metadata == null || metadata['physical'] == null) return '';
    final cat = metadata['physical']['category'];
    if (cat == null) return '';
    return (Localizations.localeOf(context).languageCode == 'es' 
        ? (cat['es'] ?? cat['en'] ?? '') 
        : (cat['en'] ?? cat['es'] ?? '')).toString();
  }

  List<String> get _currentTabCategories {
    final l10n = AppLocalizations.of(context)!;
    final Set<String> cats = {l10n.allCategories};
    
    if (_tabController.index == 0) {
      for (var g in _garments) {
        final name = _getGarmentCategory(g);
        if (name.isNotEmpty) cats.add(name);
      }
    } else {
      for (var s in _sessions) {
        final garments = s['garments'] as List<dynamic>? ?? [];
        for (var g in garments) {
          final name = _getGarmentCategory(g);
          if (name.isNotEmpty) cats.add(name);
        }
      }
    }

    final sorted = cats.toList()
      ..sort((a, b) {
        if (a == l10n.allCategories) return -1;
        if (b == l10n.allCategories) return 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    
    // Ensure selected category is still valid
    if (!sorted.contains(_selectedCategory)) {
      _selectedCategory = l10n.allCategories;
    }

    return sorted;
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
    final l10n = AppLocalizations.of(context)!;
    if (_selectedCategory == l10n.allCategories) return _garments;
    return _garments.where((g) => _getGarmentCategory(g) == _selectedCategory).toList();
  }

  List<dynamic> get _filteredSessions {
    final allLabel = AppLocalizations.of(context)!.allCategories;
    if (_selectedCategory == allLabel) return _sessions;
    return _sessions.where((session) {
      final garments = session['garments'] as List<dynamic>? ?? [];
      return garments.any((g) => _getGarmentCategory(g as Map<String, dynamic>) == _selectedCategory);
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
          for (final id in _selectedGarmentsForDelete) {
            await ApiService.deleteGarment(id);
            // Remove from selection lists as well
            _selectedInSession.removeWhere((g) => g is Map && g['id'].toString() == id);
            _confirmedGarments.removeWhere((g) => g is Map && g['id'].toString() == id);
          }
          setState(() {
            _garments.removeWhere((g) => _selectedGarmentsForDelete.contains(g['id'].toString()));
            _selectedGarmentsForDelete.clear();
            _isDeletionMode = false;
            _isGarmentSelectionMode = _selectedInSession.isNotEmpty;
          });
        } else {
          for (final id in _selectedOutfitsForDelete) await ApiService.deleteSession(id);
          setState(() {
            _sessions.removeWhere((s) => _selectedOutfitsForDelete.contains(s['id'].toString()));
            _selectedOutfitsForDelete.clear();
            _isDeletionMode = false;
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white70),
          onPressed: () => Navigator.pop(context, _selectedInSession),
        ),
        title: Text(l10n.closetTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isDeletionMode ? Icons.edit : Icons.edit_outlined, color: _isDeletionMode ? Colors.redAccent : Colors.white70),
            onPressed: () => setState(() {
              _isDeletionMode = !_isDeletionMode;
              if (_isDeletionMode) {
                _isGarmentSelectionMode = false;
                _isOutfitSelectionMode = false;
              } else {
                _selectedGarmentsForDelete.clear();
                _selectedOutfitsForDelete.clear();
              }
            }),
          ),
        ],
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
    ));
  }

  bool _shouldShowBottomBar() {
    if (_isLoading) return false;
    if (_isDeletionMode) return true;
    if (_tabController.index == 1) return false; // Hide "SELECT" in Outfits tab
    return _garments.isNotEmpty;
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(context).padding.bottom + 4),
      decoration: BoxDecoration(
        color: _isDeletionMode ? const Color(0xFF2C1B1B) : const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: _isDeletionMode 
        ? _buildDeletionModeActions()
        : (_tabController.index == 0 
          ? (_isGarmentSelectionMode ? _buildEditModeActions() : _buildNormalModeActions())
          : (_isOutfitSelectionMode ? _buildEditModeActions() : _buildNormalModeActions())),
    );
  }

  Widget _buildNormalModeActions() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () => setState(() => _tabController.index == 0 ? _isGarmentSelectionMode = true : _isOutfitSelectionMode = true),
        icon: const Icon(Icons.check_circle_outline, size: 20),
        label: Text(AppLocalizations.of(context)!.selectButton.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white12, 
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildEditModeActions() {
    final totalCount = _selectedInSession.length;
    final isLibraryTab = _tabController.index == 0;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          TextButton(
            onPressed: () => setState(() {
              if (isLibraryTab) {
                _isGarmentSelectionMode = false;
                _selectedInSession.clear();
                _selectedInSession.addAll(_confirmedGarments);
              } else {
                _isOutfitSelectionMode = false;
              }
            }),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          if (isLibraryTab)
            TextButton(
              onPressed: _selectedInSession.any((item) => item is Map) 
                  ? () => setState(() => _selectedInSession.removeWhere((item) => item is Map))
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: _selectedInSession.any((item) => item is Map) ? Colors.blueAccent : Colors.white24,
              ),
              child: const Text('LIMPIAR'),
            ),
          const SizedBox(width: 12),
          if (isLibraryTab)
            Expanded(
              child: ElevatedButton(
                onPressed: _selectedInSession.any((item) => item is Map) ? () => Navigator.pop(context, _selectedInSession) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: Text(AppLocalizations.of(context)!.useButton(totalCount).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  Widget _buildDeletionModeActions() {
    final isLibraryTab = _tabController.index == 0;
    final hasDeleteSelection = isLibraryTab ? _selectedGarmentsForDelete.isNotEmpty : _selectedOutfitsForDelete.isNotEmpty;
    final count = isLibraryTab ? _selectedGarmentsForDelete.length : _selectedOutfitsForDelete.length;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          TextButton(
            onPressed: () => setState(() {
              _isDeletionMode = false;
              _selectedGarmentsForDelete.clear();
              _selectedOutfitsForDelete.clear();
            }),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: hasDeleteSelection ? _handleBulkDelete : null,
              icon: const Icon(Icons.delete_outline, size: 20),
              label: Text(
                '${AppLocalizations.of(context)!.deleteSelected} ($count)'.toUpperCase(), 
                style: const TextStyle(fontWeight: FontWeight.bold)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: TextField(
        controller: _searchController,
        maxLength: 70,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: l10n.localeName == 'es' ? 'Busca por color, estilo u ocasión...' : 'Search...',
          prefixIcon: const Icon(Icons.auto_awesome, color: Colors.blueAccent),
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          counterText: "",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          suffixIconConstraints: const BoxConstraints(maxWidth: 80),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() { _isSmartSearchActive = false; _aiResults = null; });
                    },
                    child: const Icon(Icons.close, color: Colors.white70, size: 20),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${_searchController.text.length}/70',
                  style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        onChanged: (val) {
          setState(() {}); // Update counter on every change
        },
        onSubmitted: (_) => _handleSmartSearch(),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final categories = _currentTabCategories;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: categories.map((cat) {
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

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.white12),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryTab() {
    final l10n = AppLocalizations.of(context)!;
    if (_garments.isEmpty && !_isLoading) {
      return _buildEmptyState(l10n.noGarmentsSaved, Icons.checkroom_outlined);
    }

    final listToShow = _isSmartSearchActive && _aiResults != null ? _aiResults! : _filteredGarments;
    
    return Column(
      children: [
        _buildSearchBar(),
        _buildCategoryFilters(),
        if (_isSmartSearchLoading) const LinearProgressIndicator(),
        Expanded(
          child: listToShow.isEmpty 
            ? Center(child: Text(l10n.localeName == 'es' ? 'No se encontraron prendas' : 'No garments found', style: const TextStyle(color: Colors.white38)))
            : GridView.builder(
            padding: const EdgeInsets.all(15),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: listToShow.length,
                itemBuilder: (context, index) {
                  final garment = listToShow[index];
                  final id = garment['id'].toString();
                  final isSelectedForUse = _selectedInSession.any((g) => 
                    g is Map && 
                    g['id'] != null && 
                    g['id'].toString() == id
                  );
                  final isSelectedForDelete = _selectedGarmentsForDelete.contains(id);
                  
                  return GestureDetector(
                onTap: () {
                  if (_isDeletionMode) {
                    setState(() {
                      if (isSelectedForDelete) _selectedGarmentsForDelete.remove(id);
                      else _selectedGarmentsForDelete.add(id);
                    });
                  } else if (_isGarmentSelectionMode) {
                    _toggleSelection(garment);
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => OutfitDetailScreen(
                      imageUrl: ApiService.getFullImageUrl(garment['originalUrl']),
                    )));
                  }
                },
                onLongPress: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => OutfitDetailScreen(
                    imageUrl: ApiService.getFullImageUrl(garment['originalUrl']),
                  )));
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelectedForDelete 
                        ? Colors.redAccent 
                        : (isSelectedForUse ? Colors.blueAccent : Colors.white10), 
                      width: (isSelectedForDelete || isSelectedForUse) ? 2.5 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ApiService.getFullImageUrl(garment['originalUrl']).isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: ApiService.getFullImageUrl(garment['originalUrl']),
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                              errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white12),
                            )
                          : Container(
                              color: Colors.white.withOpacity(0.05),
                              child: const Icon(Icons.broken_image, color: Colors.white12),
                            ),
                        if (isSelectedForUse && !_isDeletionMode) 
                          Container(
                            color: Colors.black26,
                            child: const Center(
                              child: Icon(Icons.check_circle, color: Colors.blueAccent, size: 30),
                            ),
                          ),
                        if (isSelectedForDelete)
                          Container(
                            color: Colors.black45,
                            child: const Center(
                              child: Icon(Icons.delete, color: Colors.redAccent, size: 30),
                            ),
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
    final l10n = AppLocalizations.of(context)!;
    if (_sessions.isEmpty && !_isLoading) {
      return _buildEmptyState(l10n.noOutfitsSaved, Icons.auto_awesome_motion_outlined);
    }

    final listToShow = _isSmartSearchActive && _aiResults != null ? _aiResults! : _filteredSessions;

    return Column(
      children: [
        _buildSearchBar(),
        _buildCategoryFilters(),
        if (_isSmartSearchLoading) const LinearProgressIndicator(),
        Expanded(
          child: listToShow.isEmpty 
            ? Center(child: Text(l10n.localeName == 'es' ? 'No se encontraron outfits' : 'No outfits found', style: const TextStyle(color: Colors.white38)))
            : GridView.builder(
            padding: const EdgeInsets.all(15),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              crossAxisSpacing: 15, 
              mainAxisSpacing: 15,
              childAspectRatio: 0.6, // Taller portrait for outfits
            ),
            itemCount: listToShow.length,
            itemBuilder: (context, index) {
              final session = listToShow[index];
              final id = session['id'].toString();
              final isSelectedForDelete = _selectedOutfitsForDelete.contains(id);
              return GestureDetector(
                onTap: () async {
                  if (_isDeletionMode) {
                    setState(() {
                      if (isSelectedForDelete) _selectedOutfitsForDelete.remove(id);
                      else _selectedOutfitsForDelete.add(id);
                    });
                  } else {
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => OutfitManagementScreen(session: session)));
                    if (result != null && result is Map && result['type'] == 'retake') Navigator.pop(context, result);
                  }
                },
                onLongPress: () {
                  if (session['resultUrl'] != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => OutfitDetailScreen(
                      imageUrl: ApiService.getFullImageUrl(session['resultUrl']),
                    )));
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black, 
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: isSelectedForDelete ? Colors.redAccent : Colors.transparent, width: isSelectedForDelete ? 2.5 : 0),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ApiService.getFullImageUrl(session['resultUrl']).isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: ApiService.getFullImageUrl(session['resultUrl']), 
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white24)),
                              errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
                            )
                          : Container(
                              color: Colors.white.withOpacity(0.05),
                              child: const Center(child: Icon(Icons.auto_awesome, color: Colors.white10, size: 40)),
                            ),
                         if (isSelectedForDelete)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Center(
                              child: Icon(Icons.delete, color: Colors.redAccent, size: 40),
                            ),
                          ),
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

  Widget _buildCategoryBadge(Map<String, dynamic> garment) {
    dynamic metadataRaw = garment['metadata'];
    if (metadataRaw == null) return const SizedBox.shrink();

    // Handle case where metadata is accidentally saved as a List
    Map<String, dynamic>? metadata;
    if (metadataRaw is List && metadataRaw.isNotEmpty) {
      metadata = metadataRaw.first as Map<String, dynamic>?;
    } else if (metadataRaw is Map) {
      metadata = Map<String, dynamic>.from(metadataRaw);
    }

    if (metadata == null || metadata['physical'] == null) {
      return const SizedBox.shrink();
    }
    final categoryName = _getGarmentCategory(garment);

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

class OutfitDetailScreen extends StatefulWidget {
  final String? imageUrl;
  final File? localFile;

  const OutfitDetailScreen({
    super.key, 
    this.imageUrl, 
    this.localFile,
  });

  @override
  State<OutfitDetailScreen> createState() => _OutfitDetailScreenState();
}

class _OutfitDetailScreenState extends State<OutfitDetailScreen> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: GestureDetector(
              onDoubleTapDown: (details) => _doubleTapDetails = details,
              onDoubleTap: () {
                if (_transformationController.value.getMaxScaleOnAxis() > 1.0) {
                  _transformationController.value = Matrix4.identity();
                } else {
                  final position = _doubleTapDetails!.localPosition;
                  _transformationController.value = Matrix4.identity()
                    ..translate(-position.dx * (2.5 - 1), -position.dy * (2.5 - 1))
                    ..scale(2.5);
                }
              },
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 1.0,
                maxScale: 4.0,
                child: widget.localFile != null
                    ? Image.file(widget.localFile!, fit: BoxFit.contain)
                    : (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: widget.imageUrl!,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white24),
                            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white24),
                          )
                        : const Center(child: Icon(Icons.broken_image, color: Colors.white24, size: 80)),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OutfitManagementScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const OutfitManagementScreen({super.key, required this.session});

  @override
  State<OutfitManagementScreen> createState() => _OutfitManagementScreenState();
}

class _OutfitManagementScreenState extends State<OutfitManagementScreen> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final garments = widget.session['garments'] as List;
    final mannequinUrl = widget.session['mannequinUrl'] ?? '';
    final gender = widget.session['personType'] ?? 
        (mannequinUrl.contains('female') ? 'female' : (mannequinUrl.contains('male') ? 'male' : 'female'));
    final dateStr = widget.session['createdAt'].toString().substring(0, 10);

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
          child: SingleChildScrollView(
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
                      child: GestureDetector(
                        onDoubleTapDown: (details) => _doubleTapDetails = details,
                        onDoubleTap: () {
                          if (_transformationController.value.getMaxScaleOnAxis() > 1.0) {
                            _transformationController.value = Matrix4.identity();
                          } else {
                            final position = _doubleTapDetails!.localPosition;
                            _transformationController.value = Matrix4.identity()
                              ..translate(-position.dx * (2.5 - 1), -position.dy * (2.5 - 1))
                              ..scale(2.5);
                          }
                        },
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: widget.session['resultUrl'] != null && widget.session['resultUrl'].toString().isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: ApiService.getFullImageUrl(widget.session['resultUrl']),
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
                        'garments': widget.session['garments'],
                        'gender': gender,
                        'resultUrl': widget.session['resultUrl'],
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
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: garments.length,
                    itemBuilder: (context, index) {
                      final garment = garments[index];
                      String categoryName = '';
                      dynamic metadataRaw = garment['metadata'];
                      Map<String, dynamic>? metadata;
                      if (metadataRaw is List && metadataRaw.isNotEmpty) {
                        metadata = metadataRaw.first as Map<String, dynamic>?;
                      } else if (metadataRaw is Map) {
                        metadata = Map<String, dynamic>.from(metadataRaw);
                      }

                      if (metadata != null && metadata['physical'] != null) {
                        final cat = metadata['physical']['category'];
                        categoryName = Localizations.localeOf(context).languageCode == 'es' 
                            ? (cat['es'] ?? '') 
                            : (cat['en'] ?? '');
                      }
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => OutfitDetailScreen(
                            imageUrl: ApiService.getFullImageUrl(garment['originalUrl']),
                          )));
                        },
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10, width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ApiService.getFullImageUrl(garment['originalUrl']).isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: ApiService.getFullImageUrl(garment['originalUrl']),
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white10),
                                    )
                                  : Container(
                                      color: Colors.white.withOpacity(0.05),
                                      child: const Icon(Icons.broken_image, color: Colors.white10),
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
