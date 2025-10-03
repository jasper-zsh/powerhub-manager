import 'package:flutter/material.dart';
import 'package:app/models/preset.dart';

class PresetList extends StatelessWidget {
  final List<Preset> presets;
  final void Function(Preset) onPresetSelected;
  final void Function(Preset)? onPresetDeleted;
  final void Function(Preset)? onPresetUpload;
  final bool enableDelete;
  final bool showUpload;
  final String emptyMessage;
  final bool alwaysScrollable;

  const PresetList({
    Key? key,
    required this.presets,
    required this.onPresetSelected,
    this.onPresetDeleted,
    this.onPresetUpload,
    this.enableDelete = true,
    this.showUpload = false,
    this.emptyMessage = 'No presets found. Create your first preset!',
    this.alwaysScrollable = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (presets.isEmpty) {
      if (alwaysScrollable) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
          children: [
            Center(
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      }

      return Center(
        child: Text(emptyMessage),
      );
    }

    return ListView.builder(
      physics: alwaysScrollable ? const AlwaysScrollableScrollPhysics() : null,
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final preset = presets[index];

        final trailingWidgets = <Widget>[];
        if (preset.isFavorite) {
          trailingWidgets.add(
            const Icon(
              Icons.star,
              color: Colors.yellow,
              size: 20,
            ),
          );
        }

        if (showUpload && onPresetUpload != null) {
          trailingWidgets.add(
            IconButton(
              icon: const Icon(Icons.upload),
              onPressed: () => onPresetUpload!(preset),
              tooltip: '保存到设备',
            ),
          );
        }

        if (enableDelete && onPresetDeleted != null) {
          trailingWidgets.add(
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => onPresetDeleted!(preset),
            ),
          );
        }

        Widget? trailing;
        if (trailingWidgets.isNotEmpty) {
          trailing = Row(
            mainAxisSize: MainAxisSize.min,
            children: trailingWidgets,
          );
        }

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ),
          child: ListTile(
            title: Text(preset.name),
            subtitle: Text('${preset.commandCount} commands'),
            trailing: trailing,
            onTap: () => onPresetSelected(preset),
          ),
        );
      },
    );
  }
}
