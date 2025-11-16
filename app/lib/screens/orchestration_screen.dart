import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/controllers/orchestration_controller.dart';
import 'package:app/controllers/saved_controller_controller.dart';
import 'package:app/controllers/connection_session_controller.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/control_command/set_command.dart';

class OrchestrationScreen extends ConsumerWidget {
  const OrchestrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orchestrationState = ref.watch(orchestrationControllerProvider);
    final connectionState = ref.watch(connectionSessionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orchestration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(orchestrationControllerProvider.notifier).loadScenes();
              ref.read(orchestrationControllerProvider.notifier).loadExecutionLogs();
            },
          ),
        ],
      ),
      body: orchestrationState.scenes.isEmpty
          ? _buildEmptyState(context, ref, orchestrationState)
          : _buildSceneList(context, ref, orchestrationState, connectionState),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSceneDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, OrchestrationState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.toggle_on_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No scenes created',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first scene to orchestrate multiple devices',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateSceneDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Create Scene'),
          ),
        ],
      ),
    );
  }

  Widget _buildSceneList(
    BuildContext context,
    WidgetRef ref,
    OrchestrationState state,
    connectionState,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.scenes.length,
      itemBuilder: (context, index) {
        final scene = state.scenes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: CircleAvatar(
              child: Text('${index + 1}'),
            ),
            title: Text(scene.name),
            subtitle: Text('${scene.states.length} states'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.missingControllers.isNotEmpty)
                  Tooltip(
                    message: 'Missing controllers: ${state.missingControllers.join(', ')}',
                    child: Icon(Icons.warning, color: Colors.orange),
                  ),
                if (state.isExecuting)
                  const CircularProgressIndicator()
                else
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'execute',
                        child: ListTile(
                          leading: Icon(Icons.play_arrow),
                          title: Text('Execute'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Edit'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete),
                          title: Text('Delete'),
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'execute') {
                        _executeScene(context, ref, scene.id);
                      } else if (value == 'edit') {
                        _editScene(context, ref, scene);
                      } else if (value == 'delete') {
                        _deleteScene(context, ref, scene.id);
                      }
                    },
                  ),
              ],
            ),
            onTap: () => _showSceneDetails(context, ref, scene),
          ),
        );
      },
    );
  }

  void _showCreateSceneDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Scene'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Scene Name',
                    hintText: 'Enter scene name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Enter scene description',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Scene will be created with default toggle state. '
                  'You can edit it after creation.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isCreating ? null : () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a scene name')),
                  );
                  return;
                }

                setDialogState(() => isCreating = true);
                try {
                  // Create a default scene with one toggle state
                  final defaultState = ToggleState(
                    toggleId: 'scene_toggle',
                    stateId: 'default_state',
                    label: 'Default State',
                    commandBundles: [
                      CommandBundle(
                        id: 'default_bundle',
                        label: 'Default Bundle',
                        actions: [
                          // Add a sample action
                          CommandAction(
                            controllerId: 'sample_controller',
                            type: CommandActionType.channelValue,
                            channel: 0,
                            value: 128,
                          ),
                        ],
                      ),
                    ],
                  );

                  await ref.read(orchestrationControllerProvider.notifier).saveScene(
                    name: nameController.text.trim(),
                    states: [defaultState],
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                  );

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scene created successfully')),
                  );
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create scene: $error')),
                  );
                } finally {
                  setDialogState(() => isCreating = false);
                }
              },
              child: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _executeScene(BuildContext context, WidgetRef ref, String sceneId) {
    ref.read(orchestrationControllerProvider.notifier).executeScene(sceneId).then(
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scene execution completed')),
        );
      },
    ).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scene execution failed: $error')),
      );
    });
  }

  void _editScene(BuildContext context, WidgetRef ref, dynamic scene) {
    // Implementation would go here
  }

  void _deleteScene(BuildContext context, WidgetRef ref, String sceneId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Scene'),
        content: const Text('Are you sure you want to delete this scene?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(orchestrationControllerProvider.notifier).deleteScene(sceneId);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSceneDetails(BuildContext context, WidgetRef ref, dynamic scene) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(scene.name),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (scene.description != null && scene.description!.isNotEmpty) ...[
                  Text(
                    scene.description!,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'States (${scene.states.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...scene.states.asMap().entries.map((entry) {
                  final index = entry.key;
                  final state = entry.value;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}. ${state.label}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Command Bundles: ${state.commandBundles.length}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          ...state.commandBundles.map((bundle) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 16, top: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.chevron_right, size: 16),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${bundle.label} (${bundle.actions.length} actions)',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                if (scene.updatedAt != null)
                  Text(
                    'Last updated: ${_formatDateTime(scene.updatedAt!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _executeScene(context, ref, scene.id);
            },
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Execute'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/'
           '${dateTime.month.toString().padLeft(2, '0')}/'
           '${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}