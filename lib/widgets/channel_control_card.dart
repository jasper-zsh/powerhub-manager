import 'package:flutter/material.dart';
import 'channel_slider.dart';

enum ChannelCommandType { set, fade, blink, strobe }

class ChannelControlCard extends StatefulWidget {
  final int channelId;
  final String channelName;
  final int value;
  final ValueChanged<int> onSetValue;
  final Future<void> Function(int targetValue, int duration) onFadeCommand;
  final Future<void> Function(int period) onBlinkCommand;
  final Future<void> Function(int flashCount, int totalDuration, int pauseDuration)
      onStrobeCommand;

  const ChannelControlCard({
    Key? key,
    required this.channelId,
    required this.channelName,
    required this.value,
    required this.onSetValue,
    required this.onFadeCommand,
    required this.onBlinkCommand,
    required this.onStrobeCommand,
  }) : super(key: key);

  @override
  State<ChannelControlCard> createState() => _ChannelControlCardState();
}

class _ChannelControlCardState extends State<ChannelControlCard> {
  ChannelCommandType _selectedCommand = ChannelCommandType.set;

  final _fadeTargetController = TextEditingController();
  final _fadeDurationController = TextEditingController(text: '1000');
  final _blinkPeriodController = TextEditingController(text: '500');
  final _strobeFlashCountController = TextEditingController(text: '5');
  final _strobeTotalDurationController = TextEditingController(text: '1000');
  final _strobePauseDurationController = TextEditingController(text: '200');

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _syncControllersWithValue();
  }

  @override
  void didUpdateWidget(covariant ChannelControlCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _syncControllersWithValue();
    }
  }

  void _syncControllersWithValue() {
    _fadeTargetController.text = widget.value.toString();
  }

  @override
  void dispose() {
    _fadeTargetController.dispose();
    _fadeDurationController.dispose();
    _blinkPeriodController.dispose();
    _strobeFlashCountController.dispose();
    _strobeTotalDurationController.dispose();
    _strobePauseDurationController.dispose();
    super.dispose();
  }

  Future<void> _handleFadeCommand() async {
    final targetValue = int.tryParse(_fadeTargetController.text);
    final duration = int.tryParse(_fadeDurationController.text);

    if (targetValue == null || targetValue < 0 || targetValue > 255) {
      _showError('目标值必须在 0 到 255 之间');
      return;
    }

    if (duration == null || duration <= 0 || duration > 65535) {
      _showError('渐变时长必须在 1 到 65535 毫秒之间');
      return;
    }

    await _runCommand(() => widget.onFadeCommand(targetValue, duration));
  }

  Future<void> _handleBlinkCommand() async {
    final period = int.tryParse(_blinkPeriodController.text);

    if (period == null || period <= 0 || period > 65535) {
      _showError('闪烁周期必须在 1 到 65535 毫秒之间');
      return;
    }

    await _runCommand(() => widget.onBlinkCommand(period));
  }

  Future<void> _handleStrobeCommand() async {
    final flashCount = int.tryParse(_strobeFlashCountController.text);
    final totalDuration = int.tryParse(_strobeTotalDurationController.text);
    final pauseDuration = int.tryParse(_strobePauseDurationController.text);

    if (flashCount == null || flashCount <= 0 || flashCount > 255) {
      _showError('闪烁次数必须在 1 到 255 之间');
      return;
    }

    if (totalDuration == null || totalDuration <= 0 || totalDuration > 65535) {
      _showError('总时长必须在 1 到 65535 毫秒之间');
      return;
    }

    if (pauseDuration == null || pauseDuration < 0 || pauseDuration > 65535) {
      _showError('暂停时长必须在 0 到 65535 毫秒之间');
      return;
    }

    await _runCommand(() => widget.onStrobeCommand(flashCount, totalDuration, pauseDuration));
  }

  Future<void> _runCommand(Future<void> Function() command) async {
    if (_isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await command();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('指令已发送')),
      );
    } catch (e) {
      _showError('指令发送失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildCommandContent() {
    switch (_selectedCommand) {
      case ChannelCommandType.set:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChannelSlider(
              channelId: widget.channelId,
              channelName: widget.channelName,
              value: widget.value,
              onChanged: widget.onSetValue,
            ),
            const SizedBox(height: 8),
            const Text(
              '拖动滑块立即更新通道值。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        );
      case ChannelCommandType.fade:
        return Column(
          children: [
            TextField(
              controller: _fadeTargetController,
              decoration: const InputDecoration(
                labelText: '目标值 (0-255)',
                prefixIcon: Icon(Icons.flag),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fadeDurationController,
              decoration: const InputDecoration(
                labelText: '渐变时长 (毫秒)',
                prefixIcon: Icon(Icons.timelapse),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _handleFadeCommand,
                icon: const Icon(Icons.play_arrow),
                label: const Text('执行渐变'),
              ),
            ),
          ],
        );
      case ChannelCommandType.blink:
        return Column(
          children: [
            TextField(
              controller: _blinkPeriodController,
              decoration: const InputDecoration(
                labelText: '闪烁周期 (毫秒)',
                prefixIcon: Icon(Icons.repeat),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _handleBlinkCommand,
                icon: const Icon(Icons.flash_on),
                label: const Text('执行闪烁'),
              ),
            ),
          ],
        );
      case ChannelCommandType.strobe:
        return Column(
          children: [
            TextField(
              controller: _strobeFlashCountController,
              decoration: const InputDecoration(
                labelText: '闪烁次数 (1-255)',
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _strobeTotalDurationController,
              decoration: const InputDecoration(
                labelText: '总时长 (毫秒)',
                prefixIcon: Icon(Icons.schedule),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _strobePauseDurationController,
              decoration: const InputDecoration(
                labelText: '暂停时长 (毫秒)',
                prefixIcon: Icon(Icons.pause_circle_outline),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _handleStrobeCommand,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('执行爆闪'),
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelLabel = widget.channelName.isNotEmpty
        ? widget.channelName
        : 'Channel ${widget.channelId}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  channelLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                DropdownButton<ChannelCommandType>(
                  value: _selectedCommand,
                  items: const [
                    DropdownMenuItem(
                      value: ChannelCommandType.set,
                      child: Text('立即设置'),
                    ),
                    DropdownMenuItem(
                      value: ChannelCommandType.fade,
                      child: Text('渐变'),
                    ),
                    DropdownMenuItem(
                      value: ChannelCommandType.blink,
                      child: Text('闪烁'),
                    ),
                    DropdownMenuItem(
                      value: ChannelCommandType.strobe,
                      child: Text('爆闪'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedCommand = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCommandContent(),
          ],
        ),
      ),
    );
  }
}
