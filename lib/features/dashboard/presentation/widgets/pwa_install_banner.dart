import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgettime/core/services/pwa_service.dart';

class PwaInstallBanner extends ConsumerStatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  ConsumerState<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends ConsumerState<PwaInstallBanner> {
  bool _showInstallBanner = false;
  bool _showUpdateBanner = false;

  @override
  void initState() {
    super.initState();
    final pwa = ref.read(pwaServiceProvider);

    pwa.isInstallable.listen((isInstallable) {
      if (mounted) {
        setState(() => _showInstallBanner = isInstallable);
      }
    });

    pwa.updateAvailable.listen((_) {
      if (mounted) {
        setState(() => _showUpdateBanner = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showUpdateBanner) {
      return Material(
        elevation: 8,
        child: Container(
          color: Colors.orange[800],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.update, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Une nouvelle version est disponible !',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.read(pwaServiceProvider).reloadApp(),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('RECHARGER'),
              ),
            ],
          ),
        ),
      );
    }

    if (_showInstallBanner) {
      return Material(
        elevation: 8,
        child: Container(
          color: Colors.blue[800],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.get_app, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Installer BudgetTime sur votre écran d\'accueil ?',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => setState(() => _showInstallBanner = false),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => ref.read(pwaServiceProvider).promptInstall(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue[800],
                ),
                child: const Text('INSTALLER'),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
