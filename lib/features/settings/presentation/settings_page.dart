import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/database_service.dart';
import 'settings_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../members/presentation/manage_members_page.dart';
import '../../../pages/open_banking_accounts_page.dart';

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
            leading: const Icon(Icons.account_balance),
            title: const Text('Liaison Bancaire (Enable Banking)'),
            subtitle: const Text('Connecter un nouveau compte bancaire'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OpenBankingAccountsPage(),
              ),
            ),
          ),
          const Divider(),
          // ── Section Synchronisation Bancaire ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Synchronisation bancaire',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(settingsControllerProvider);
              return state.maybeWhen(
                data: (settings) => Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.schedule),
                      title: const Text('Synchronisation automatique à 8h'),
                      subtitle: const Text(
                        'Récupère automatiquement les nouvelles transactions bancaires chaque matin.',
                      ),
                      value: settings.autoSync,
                      onChanged: (v) => ref
                          .read(settingsControllerProvider.notifier)
                          .updateAutoSync(v),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.sync),
                      title: const Text(
                        'Actualisation bancaire sur swipe vers le bas',
                      ),
                      subtitle: const Text(
                        'En vue détail d\'un compte, tirer vers le bas synchronise aussi les transactions bancaires (1 fois/heure max).',
                      ),
                      value: settings.pullToSync,
                      onChanged: (v) => ref
                          .read(settingsControllerProvider.notifier)
                          .updatePullToSync(v),
                    ),
                  ],
                ),
                orElse: () => const SizedBox.shrink(),
              );
            },
          ),
          const Divider(),
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
