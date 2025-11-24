import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/models/connection_status_record.dart';
import 'package:app/controllers/connection_session_controller.dart';

class ReconnectStatusScreen extends ConsumerWidget {
  const ReconnectStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionSessionControllerProvider);
    final statusHistory = ref.watch(connectionStatusHistoryProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reconnection Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshConnectionStatus(ref),
            tooltip: 'Refresh status',
          ),
        ],
      ),
      body: _buildBody(connectionState, statusHistory),
    );
  }

  Widget _buildBody(ConnectionSessionState connectionState, AsyncValue<List<ConnectionStatusRecord>> statusHistory) {
    return RefreshIndicator(
      onRefresh: () => _refreshConnectionStatus(ref),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentStatusCard(connectionState),
            const SizedBox(height: 16),
            _buildReconnectionSettingsCard(connectionState),
            const SizedBox(height: 16),
            _buildStatusHistoryCard(statusHistory),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard(ConnectionSessionState connectionState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getConnectionIcon(connectionState.status),
                  color: _getConnectionColor(connectionState.status),
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Connection Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  _getConnectionStatusText(connectionState.status),
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(
                        color: _getConnectionColor(connectionState.status),
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            if (connectionState.device != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Device',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    connectionState.device!.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ],
            if (connectionState.lastError != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Last Error',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Expanded(
                    child: Text(
                      connectionState.lastError!,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: Colors.red),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
            if (connectionState.isReconnecting) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'Attempting to reconnect... (${connectionState.reconnectAttempts}/${connectionState.maxReconnectAttempts})',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReconnectionSettingsCard(ConnectionSessionState connectionState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.settings,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Reconnection Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Auto Reconnect'),
              subtitle: const Text('Automatically reconnect when connection is lost'),
              trailing: Switch(
                value: connectionState.autoReconnect,
                onChanged: (value) => _toggleAutoReconnect(ref, value),
              ),
            ),
            ListTile(
              title: const Text('Max Reconnect Attempts'),
              subtitle: Text('${connectionState.maxReconnectAttempts} attempts'),
              trailing: const Icon(Icons.edit),
              onTap: () => _showMaxReconnectAttemptsDialog(connectionState.maxReconnectAttempts),
            ),
            ListTile(
              title: const Text('Reconnect Interval'),
              subtitle: Text('${connectionState.reconnectIntervalSeconds}s'),
              trailing: const Icon(Icons.edit),
              onTap: () => _showReconnectIntervalDialog(connectionState.reconnectIntervalSeconds),
            ),
            ListTile(
              title: const Text('Connection Timeout'),
              subtitle: Text('${connectionState.connectionTimeoutSeconds}s'),
              trailing: const Icon(Icons.edit),
              onTap: () => _showConnectionTimeoutDialog(connectionState.connectionTimeoutSeconds),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHistoryCard(AsyncValue<List<ConnectionStatusRecord>> statusHistory) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.history,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Connection History',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _clearHistory(ref),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            statusHistory.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('Error loading history: $error'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _refreshConnectionStatus(ref),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (records) => records.isEmpty
                  ? const Center(
                      child: Text('No connection history available'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return ListTile(
                          leading: Icon(
                            _getConnectionIcon(record.status),
                            color: _getConnectionColor(record.status),
                          ),
                          title: Text(_getConnectionStatusText(record.status)),
                          subtitle: Text(_formatTimestamp(record.timestamp)),
                          trailing: record.error != null
                              ? const Icon(Icons.error, color: Colors.red)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getConnectionIcon(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.disconnected:
        return Icons.bluetooth_disabled;
      case ConnectionStatus.connecting:
        return Icons.bluetooth_searching;
      case ConnectionStatus.connected:
        return Icons.bluetooth_connected;
      case ConnectionStatus.reconnecting:
        return Icons.sync;
      case ConnectionStatus.failed:
        return Icons.error;
    }
  }

  Color _getConnectionColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.disconnected:
        return Colors.grey;
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
        return Colors.orange;
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.failed:
        return Colors.red;
    }
  }

  String _getConnectionStatusText(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.connecting:
        return 'Connecting';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.reconnecting:
        return 'Reconnecting';
      case ConnectionStatus.failed:
        return 'Failed';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  void _toggleAutoReconnect(WidgetRef ref, bool value) {
    ref.read(connectionSessionControllerProvider.notifier).setAutoReconnect(value);
  }

  void _showMaxReconnectAttemptsDialog(int currentValue) {
    final controller = TextEditingController(text: currentValue.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Max Reconnect Attempts'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Maximum attempts',
            hintText: 'Enter maximum reconnect attempts',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                ref.read(connectionSessionControllerProvider.notifier).setMaxReconnectAttempts(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showReconnectIntervalDialog(int currentValue) {
    final controller = TextEditingController(text: currentValue.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reconnect Interval'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Interval (seconds)',
            hintText: 'Enter reconnect interval in seconds',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                ref.read(connectionSessionControllerProvider.notifier).setReconnectInterval(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showConnectionTimeoutDialog(int currentValue) {
    final controller = TextEditingController(text: currentValue.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Timeout'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Timeout (seconds)',
            hintText: 'Enter connection timeout in seconds',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                ref.read(connectionSessionControllerProvider.notifier).setConnectionTimeout(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshConnectionStatus(WidgetRef ref) {
    return ref.read(connectionSessionControllerProvider.notifier).refreshStatus();
  }

  void _clearHistory(WidgetRef ref) {
    ref.read(connectionSessionControllerProvider.notifier).clearStatusHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connection history cleared')),
    );
  }
}