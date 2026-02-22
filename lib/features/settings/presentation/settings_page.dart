import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/database_service.dart';
import 'settings_controller.dart';
import 'package:url_launcher/url_launcher.dart';
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
                final state = ref.watch(settingsControllerProvider);
                return state.when(
                  data: (settings) =>
                      Text('Le ${settings.fiscalDayStart} du mois'),
                  loading: () => const Text('Chargement...'),
                  error: (e, s) => const Text('Erreur récupération'),
                );
              },
            ),
            trailing: Consumer(
              builder: (context, ref, child) {
                final state = ref.watch(settingsControllerProvider);
                return state.maybeWhen(
                  data: (settings) => DropdownButton<int>(
                    value: settings.fiscalDayStart,
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
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Réceptions (Smart Inbox)',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(settingsControllerProvider);
              return state.when(
                data: (settings) {
                  return Column(
                    children: settings.activeParsers.entries.map((entry) {
                      final name = entry.key == 'la_banque_postale'
                          ? 'La Banque Postale'
                          : entry.key == 'credit_mutuel'
                          ? 'Crédit Mutuel'
                          : entry.key;
                      return CheckboxListTile(
                        title: Text(name),
                        subtitle: Text(
                          'Activer le parser automatique pour $name',
                        ),
                        value: entry.value,
                        onChanged: (val) {
                          if (val != null) {
                            ref
                                .read(settingsControllerProvider.notifier)
                                .toggleParser(entry.key, val);
                          }
                        },
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: LinearProgressIndicator()),
                error: (e, s) => ListTile(title: Text('Erreur: $e')),
              );
            },
          ),
          const Divider(),
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
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('Administration (PocketBase)'),
            onTap: () async {
              final dbService = ref.read(databaseServiceProvider);
              final baseUrl = dbService.pb.baseURL;
              final adminUrl = baseUrl.endsWith('/')
                  ? '${baseUrl}_/'
                  : '$baseUrl/_/';

              try {
                // ignore: deprecated_member_use
                await launchUrl(Uri.parse(adminUrl));
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Impossible d\'ouvrir le lien: $e')),
                  );
                }
              }
            },
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
    await clearCollection('members');
    await clearCollection('categories');
    await clearCollection('raw_inbox');
  }
}
