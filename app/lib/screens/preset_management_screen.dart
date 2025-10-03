import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/app_state_provider.dart';
import 'package:app/widgets/preset_list.dart';

class PresetManagementScreen extends StatefulWidget {
  const PresetManagementScreen({Key? key}) : super(key: key);

  @override
  State<PresetManagementScreen> createState() => _PresetManagementScreenState();
}

class _PresetManagementScreenState extends State<PresetManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppStateProvider>();
      if (appState.selectedDevice != null && appState.isConnected) {
        appState.loadDevicePresets();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final actions = <Widget>[
          if (appState.isConnected)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新设备预设',
              onPressed: () {
                appState.loadDevicePresets();
              },
            ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '创建本地预设',
            onPressed: () {
              _showCreatePresetDialog(context, appState);
            },
          ),
        ];

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Preset Management'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              actions: actions,
              bottom: const TabBar(
                tabs: [
                  Tab(text: '设备预设'),
                  Tab(text: '本地预设'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildDevicePresetTab(appState),
                _buildLocalPresetTab(appState),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDevicePresetTab(AppStateProvider appState) {
    if (!appState.isConnected) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        children: const [
          Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            '连接设备以查看存储在设备上的预设。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      );
    }

    if (appState.isLoadingDevicePresets && appState.devicePresets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (appState.isLoadingDevicePresets)
          const LinearProgressIndicator(minHeight: 4),
        if (appState.devicePresetError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                appState.devicePresetError,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: appState.loadDevicePresets,
            child: PresetList(
              presets: appState.devicePresets,
              onPresetSelected: (preset) {
                appState.executePreset(preset.id);
              },
              onPresetDeleted: null,
              enableDelete: false,
              emptyMessage: appState.devicePresetError.isNotEmpty
                  ? appState.devicePresetError
                  : '设备上没有预设。',
              alwaysScrollable: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalPresetTab(AppStateProvider appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '管理本地预设',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: appState.loadLocalPresets,
            child: PresetList(
              presets: appState.localPresets,
              onPresetSelected: (preset) {
                if (appState.isConnected) {
                  appState.executePreset(preset.id);
                }
              },
              onPresetDeleted: (preset) {
                appState.deleteLocalPreset(preset.id);
              },
              onPresetUpload: appState.isConnected
                  ? (preset) => appState.savePresetToDevice(preset)
                  : null,
              showUpload: appState.isConnected,
              emptyMessage: 'No local presets. Create one to get started!',
              alwaysScrollable: true,
            ),
          ),
        ),
      ],
    );
  }

  void _showCreatePresetDialog(
      BuildContext context, AppStateProvider appState) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Create New Preset'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'Enter preset name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  // TODO: Implement preset creation workflow.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Preset creation is not implemented yet.'),
                    ),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}
