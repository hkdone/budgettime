import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'member_controller.dart';

class ManageMembersPage extends ConsumerWidget {
  const ManageMembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(memberControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gérer les membres')),
      body: membersAsync.when(
        data: (members) => ListView.builder(
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return ListTile(
              leading: CircleAvatar(child: Icon(member.icon)),
              title: Text(member.name),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDelete(context, ref, member.id),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMemberDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce membre ?'),
        content: const Text(
          'Cela ne supprimera pas ses transactions, mais détachera le membre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(memberControllerProvider.notifier).deleteMember(id);
    }
  }

  Future<void> _showAddMemberDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    int selectedIcon = Icons.person.codePoint;

    final icons = [
      Icons.person,
      Icons.face,
      Icons.face_3,
      Icons.face_6,
      Icons.emoji_people,
      Icons.child_care,
      Icons.pets,
      Icons.accessibility_new,
      Icons.directions_run,
      Icons.favorite,
      Icons.star,
      Icons.home,
    ];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Nouveau Membre'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Icône'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: icons
                        .map(
                          (icon) => InkWell(
                            onTap: () =>
                                setState(() => selectedIcon = icon.codePoint),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedIcon == icon.codePoint
                                    ? Colors.blue.withValues(alpha: 0.2)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                border: selectedIcon == icon.codePoint
                                    ? Border.all(color: Colors.blue, width: 2)
                                    : null,
                              ),
                              child: Icon(
                                icon,
                                color: selectedIcon == icon.codePoint
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    await ref
                        .read(memberControllerProvider.notifier)
                        .addMember(nameController.text, selectedIcon);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Ajouter'),
              ),
            ],
          );
        },
      ),
    );
  }
}
