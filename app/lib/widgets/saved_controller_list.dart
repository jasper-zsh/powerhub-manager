import 'package:app/models/connection_status_record.dart';
import 'package:app/models/saved_controller.dart';
import 'package:flutter/material.dart';

class SavedControllerList extends StatelessWidget {
  const SavedControllerList({
    super.key,
    required this.controllers,
    this.onSelect,
    this.emptyState,
    this.onRename,
    this.onRemove,
    this.statusRecords,
  });

  final List<SavedController> controllers;
  final void Function(SavedController controller)? onSelect;
  final Widget? emptyState;
  final void Function(SavedController controller)? onRename;
  final void Function(SavedController controller)? onRemove;
  final Map<String, ConnectionStatusRecord>? statusRecords;

  @override
  Widget build(BuildContext context) {
    if (controllers.isEmpty) {
      return emptyState ??
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No saved controllers yet.'),
          );
    }

    return ListView.separated(
      itemCount: controllers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final controller = controllers[index];
        final record = statusRecords?[controller.controllerId];
        return ListTile(
          title: Text(controller.alias),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.controllerId,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              _buildStatusWrap(controller, record),
            ],
          ),
          trailing: _buildTrailingActions(controller),
          onTap: onSelect != null ? () => onSelect!(controller) : null,
        );
      },
    );
  }

  Widget _buildStatusWrap(
    SavedController controller,
    ConnectionStatusRecord? record,
  ) {
    final chips = <Widget>[
      _connectionStatusChip(controller.connectionStatus),
    ];

    if (record != null) {
      if (record.scanState == ScanState.scanning) {
        chips.add(_infoChip('Scanning', Colors.indigo));
      } else if (record.scanState == ScanState.waitingRetry) {
        chips.add(_infoChip('Retry scheduled', Colors.orange));
      }

      if (record.retryAttempts > 0 &&
          controller.connectionStatus !=
              SavedControllerConnectionStatus.connected) {
        chips.add(
          _infoChip('Attempts ${record.retryAttempts}', Colors.deepOrange),
        );
      }

      if (record.lastResult == LastScanResult.error &&
          record.errorReason != null) {
        chips.add(_infoChip('Error', Colors.redAccent));
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _buildTrailingActions(SavedController controller) {
    final actions = <Widget>[];
    if (onRename != null) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: 'Rename controller',
          onPressed: () => onRename?.call(controller),
        ),
      );
    }
    if (onRemove != null) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove controller',
          onPressed: () => onRemove?.call(controller),
        ),
      );
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions,
    );
  }

  Widget _connectionStatusChip(SavedControllerConnectionStatus status) {
    Color color;
    switch (status) {
      case SavedControllerConnectionStatus.connected:
        color = Colors.green;
        break;
      case SavedControllerConnectionStatus.connecting:
        color = Colors.orange;
        break;
      case SavedControllerConnectionStatus.unavailable:
        color = Colors.red;
        break;
      case SavedControllerConnectionStatus.disconnected:
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(status.name),
      backgroundColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: color.darken()),
    );
  }

  Widget _infoChip(String label, Color color) {
    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color.darken()),
    );
  }
}

extension _ColorBrightness on Color {
  Color darken([double amount = .2]) {
    assert(amount >= 0 && amount <= 1);
    final f = 1 - amount;
    return Color.fromARGB(
      alpha,
      (red * f).round(),
      (green * f).round(),
      (blue * f).round(),
    );
  }
}
