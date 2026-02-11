import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lasprendas_frontend/l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.profileTitle, style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.translate, color: Colors.white70),
            onPressed: () => context.read<LanguageProvider>().toggleLanguage(),
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
          child: Padding(
            padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: Stack(
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Color(0xFF1E1E1E),
                      child: Icon(Icons.person, size: 60, color: Colors.white70),
                    ),
                    if (auth.isVerified)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 16, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _ProfileInfoItem(
                label: l10n.profileNameLabel,
                value: auth.userName ?? l10n.loading,
              ),
              const SizedBox(height: 20),
              _ProfileInfoItem(
                label: l10n.profileEmailLabel,
                value: auth.userEmail ?? l10n.loading,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: () async {
                    await auth.logout();
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(
                    l10n.logout,
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _ProfileInfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileInfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
