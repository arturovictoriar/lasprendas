import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';

class ClosetScreen extends StatefulWidget {
  final List<String> alreadySelected;
  const ClosetScreen({super.key, this.alreadySelected = const []});

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    // Initialize with already selected items if we wanted to show them, 
    // but for now let's just allow fresh selection.
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final garments = await ApiService.getGarments();
      final sessions = await ApiService.getSessions();
      setState(() {
        _garments = garments;
        _sessions = sessions;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando closet: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredGarments {
    if (_selectedCategory == 'Todas') return _garments;
    return _garments.where((g) => g['category'].toString().toLowerCase() == _selectedCategory.toLowerCase()).toList();
  }

  void _toggleSelection(dynamic garment) {
    setState(() {
      final index = _selectedInSession.indexWhere((g) => g['id'] == garment['id']);
      if (index >= 0) {
        _selectedInSession.removeAt(index);
      } else {
        if (_selectedInSession.length < 4) {
          _selectedInSession.add(garment);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Máximo 4 prendas')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('MI CLOSET', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'MI ROPA'),
            Tab(text: 'MIS OUTFITS'),
          ],
        ),
        actions: [
          if (_selectedInSession.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, _selectedInSession),
              child: const Text('USAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLibraryTab(),
                _buildOutfitsTab(),
              ],
            ),
    );
  }

  Widget _buildLibraryTab() {
    return Column(
      children: [
        const SizedBox(height: 10),
        SingleChildScrollView(
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
                  onSelected: (val) => setState(() => _selectedCategory = cat),
                  backgroundColor: const Color(0xFF1E1E1E),
                  selectedColor: Colors.white,
                  labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white70),
                ),
              );
            }).toList(),
          ),
        ),
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
              final isSelected = _selectedInSession.any((g) => g['id'] == garment['id']);
              
              return GestureDetector(
                onTap: () => _toggleSelection(garment),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.white10,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: '${ApiService.baseUrl}/${garment['originalUrl']}',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.white10),
                          errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white24),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        right: 5,
                        top: 5,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.check, size: 16, color: Colors.black),
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
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OutfitDetailScreen(
                      imageUrl: '${ApiService.baseUrl}/results/${session['resultUrl']}',
                      tag: 'outfit-${session['id']}',
                    ),
                  ),
                ),
                child: Hero(
                  tag: 'outfit-${session['id']}',
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: CachedNetworkImage(
                      imageUrl: '${ApiService.baseUrl}/results/${session['resultUrl']}',
                      width: double.infinity,
                      height: 300,
                      fit: BoxFit.cover,
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
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outfit ${session['createdAt'].toString().substring(0, 10)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: (session['garments'] as List).length,
                        itemBuilder: (context, gIndex) {
                          final g = session['garments'][gIndex];
                          return Container(
                            width: 50,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: '${ApiService.baseUrl}/${g['originalUrl']}',
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.white10),
                                errorWidget: (context, url, error) => const Icon(Icons.error, size: 16),
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
        );
      },
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
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Hero(
                tag: tag,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white24),
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
