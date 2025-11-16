import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/providers/orchestration_provider.dart';
import 'package:app/services/switch_hub_ble_service.dart';

class SwitchHubSyncSheet extends StatefulWidget {
  const SwitchHubSyncSheet({
    super.key,
    required this.scene,
    required this.provider,
    this.aliasMap = const <String, String>{},
  });

  final ToggleScene scene;
  final OrchestrationProvider provider;
  final Map<String, String> aliasMap;

  @override
  State<SwitchHubSyncSheet> createState() => _SwitchHubSyncSheetState();
}

class _SwitchHubSyncSheetState extends State<SwitchHubSyncSheet> {
  late final config =
      widget.provider.buildSwitchHubConfig(widget.scene.id, schemaVersion: 1);
  late final String _jsonPreview =
      const JsonEncoder.withIndent('  ').convert(config.toJson());

  List<ScanResult> _devices = <ScanResult>[];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isScanning = false;
  bool _isSyncing = false;
  String? _statusMessage;
  String? _scanError;
  String? _syncingDeviceId;

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;
    final controllerIds = widget.scene.referencedControllers.toList()
      ..sort();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SwitchHub 编排导出',
                      style: theme.textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '以下 JSON 与 SwitchHub BLE 规范保持一致，可直接写入 0xFFF3 特征。',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildJsonPreview(theme),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.copy_all),
                            onPressed: _copyJson,
                            label: const Text('复制 JSON'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(
                              _isScanning
                                  ? Icons.bluetooth_searching
                                  : Icons.bluetooth,
                            ),
                            onPressed: _isScanning ? null : _startScan,
                            label: Text(_isScanning ? '正在扫描…' : '扫描 SwitchHub'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '涉及控制器',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (controllerIds.isEmpty)
                      const Text('暂无控制器引用。')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: controllerIds
                            .map(
                              (controllerId) => Chip(
                                label: Text(_labelForController(controllerId)),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      '已发现的 SwitchHub 设备',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_scanError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _scanError!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    if (_isScanning)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_devices.isEmpty)
                      _buildEmptyStateCard()
                    else
                      ..._devices.map(_buildDeviceTile),
                    const SizedBox(height: 12),
                    if (_statusMessage != null)
                      Text(
                        _statusMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJsonPreview(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 160),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SelectableText(
              _jsonPreview,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('尚未发现 SwitchHub 设备。'),
            SizedBox(height: 4),
            Text('请开启设备的广播模式，然后再次点击“扫描 SwitchHub”。'),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(ScanResult result) {
    final deviceId = result.device.remoteId.str;
    final title = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : 'SwitchHub ($deviceId)';
    final isBusy = _isSyncing && _syncingDeviceId == deviceId;
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text('ID: $deviceId\nRSSI: ${result.rssi} dBm'),
        trailing: isBusy
            ? const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : ElevatedButton(
                onPressed: _isSyncing ? null : () => _syncToDevice(result),
                child: const Text('同步'),
              ),
      ),
    );
  }

  Future<void> _copyJson() async {
    await Clipboard.setData(ClipboardData(text: _jsonPreview));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SwitchHub JSON 已复制。')),
    );
  }

  Future<void> _startScan() async {
    setState(() {
      _devices = <ScanResult>[];
      _scanError = null;
      _statusMessage = null;
      _isScanning = true;
    });

    final ready = await _ensureBleReady();
    if (!ready) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      } else {
        _isScanning = false;
      }
      return;
    }

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      debugPrint('[SwitchHubScan] callback results=${results.length}');
      for (final result in results) {
        debugPrint(
          '[SwitchHubScan] seen ${result.device.remoteId} ${result.device.platformName} RSSI ${result.rssi} uuids ${result.advertisementData.serviceUuids.map((e) => e.toString()).join(', ')}',
        );
      }
      final filtered = results.where(_matchesSwitchHub).toList();
      if (filtered.isEmpty) {
        return;
      }
      final merged = <String, ScanResult>{
        for (final result in _devices) result.device.remoteId.str: result,
      };
      for (final entry in filtered) {
        merged[entry.device.remoteId.str] = entry;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _devices = merged.values.toList();
      });
    });

    try {
      debugPrint(
        '[SwitchHubScan] Starting scan (no filter) for service ${SwitchHubBleService.serviceUuid}',
      );
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
        androidUsesFineLocation: true,
      );
      debugPrint('[SwitchHubScan] Scan started');
    } catch (error) {
      if (mounted) {
        setState(() {
          _scanError = '扫描失败: $error';
        });
      }
      debugPrint('[SwitchHubScan] Scan error: $error');
    } finally {
      await FlutterBluePlus.stopScan();
      debugPrint('[SwitchHubScan] Scan stopped');
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      } else {
        _isScanning = false;
      }
    }
  }

  Future<bool> _ensureBleReady() async {
    try {
      final supported = await FlutterBluePlus.isSupported;
      if (!supported) {
        if (mounted) {
          setState(() {
          _scanError = '当前设备不支持 BLE';
        });
      }
      debugPrint('[SwitchHubScan] BLE not supported');
      return false;
      }

      final statuses = await <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final allGranted = statuses.values.every((status) => status.isGranted);
      if (!allGranted) {
        if (mounted) {
          setState(() {
            _scanError = '请先授予蓝牙/定位权限';
          });
        }
        debugPrint('[SwitchHubScan] permissions denied: $statuses');
        return false;
      }

      final locationServiceStatus =
          await Permission.locationWhenInUse.serviceStatus;
      if (locationServiceStatus != ServiceStatus.enabled) {
        if (mounted) {
          setState(() {
            _scanError = '需要开启系统定位服务以扫描 BLE 设备';
          });
        }
        debugPrint('[SwitchHubScan] location service status: $locationServiceStatus');
        return false;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        if (mounted) {
          setState(() {
            _scanError = '请打开系统蓝牙后重试';
          });
        }
        debugPrint('[SwitchHubScan] adapter state: $adapterState');
        return false;
      }

      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _scanError = '无法检查蓝牙状态: $error';
        });
      }
      debugPrint('[SwitchHubScan] ensure ready error: $error');
      return false;
    }
  }

  bool _matchesSwitchHub(ScanResult result) {
    final target =
        SwitchHubBleService.serviceUuid.toLowerCase().replaceAll('-', '');
    final targetReversed = _reverseUuidBytes(target);
    for (final uuid in result.advertisementData.serviceUuids) {
      final normalized = uuid.toString().toLowerCase().replaceAll('-', '');
      if (normalized == target || normalized == targetReversed) {
        debugPrint('[SwitchHubScan] match by UUID ${uuid.toString()}');
        return true;
      }
    }
    final name = result.device.platformName.toLowerCase();
    if (name.contains('switchhub')) {
      debugPrint('[SwitchHubScan] match by name ${result.device.platformName}');
      return true;
    }
    return false;
  }

  String _reverseUuidBytes(String normalized) {
    final buffer = StringBuffer();
    for (var i = normalized.length; i > 0; i -= 2) {
      final start = (i - 2).clamp(0, normalized.length - 2).toInt();
      buffer.write(normalized.substring(start, start + 2));
    }
    return buffer.toString();
  }

  Future<void> _syncToDevice(ScanResult result) async {
    setState(() {
      _isSyncing = true;
      _syncingDeviceId = result.device.remoteId.str;
      _statusMessage = '正在同步 ${result.device.platformName}…';
    });
    try {
      await widget.provider.pushSceneToSwitchHub(
        widget.scene.id,
        device: result.device,
      );
      if (mounted) {
        setState(() {
          _statusMessage = '同步成功：${result.device.platformName.isEmpty ? result.device.remoteId.str : result.device.platformName}';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusMessage = '同步失败: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncingDeviceId = null;
        });
      } else {
        _isSyncing = false;
        _syncingDeviceId = null;
      }
    }
  }

  String _labelForController(String controllerId) {
    final alias = widget.aliasMap[controllerId];
    if (alias == null || alias.isEmpty) {
      return controllerId;
    }
    return '$controllerId ($alias)';
  }
}
