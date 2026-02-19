import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/database_service.dart';
import 'settings_controller.dart';
import '../../members/presentation/manage_members_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('Début du mois fiscal'),
            subtitle: Consumer(
              builder: (context, ref, child) {
                final settings = ref.watch(settingsControllerProvider);
                return settings.when(
                  data: (day) => Text('Le $day du mois'),
                  loading: () => const Text('Chargement...'),
                  error: (e, s) => const Text('Erreur récupération'),
                );
              },
            ),
            trailing: Consumer(
              builder: (context, ref, child) {
                final settings = ref.watch(settingsControllerProvider);
                return settings.maybeWhen(
                  data: (day) => DropdownButton<int>(
                    value: day,
                    items: List.generate(28, (index) => index + 1)
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text(d.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (newDay) {
                      if (newDay != null) {
                        ref
                            .read(settingsControllerProvider.notifier)
                            .updateFiscalDayStart(newDay);
                      }
                    },
                  ),
                  orElse: () => const SizedBox.shrink(),
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Gérer les membres'),
            onTap: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageMembersPage(),
                  ),
                ).then((_) {
                  // Refresh if needed, though members are usually static
                }),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Réinitialiser la base de données',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Attention: cette action est irréversible.'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirmation'),
                  content: const Text(
                    'Êtes-vous sûr de vouloir tout effacer ? Toutes les données (comptes, transactions, récurrences) seront perdues.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Effacer'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                try {
                  final dbService = ref.read(databaseServiceProvider);
                  await _clearAllData(dbService);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Base de données réinitialisée.'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData(DatabaseService dbService) async {
    final user = dbService.pb.authStore.record;
    if (user == null) return;

    // Delete in order to respect dependencies if needed,
    // though usually cascade delete or wiping collections is enough.
    // Order: transactions, recurrences, accounts, raw_inbox

    // Helper to clear a collection
    Future<void> clearCollection(String name) async {
      final records = await dbService.pb.collection(name).getFullList();
      for (final r in records) {
        await dbService.pb.collection(name).delete(r.id);
      }
    }

    await clearCollection('transactions');
    await clearCollection('recurrences');
    await clearCollection('accounts');
    await clearCollection('raw_inbox');
  }
}
