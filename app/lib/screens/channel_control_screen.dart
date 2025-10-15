import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/app_state_provider.dart';
import 'package:app/widgets/channel_control_card.dart';

class ChannelControlScreen extends StatelessWidget {
  const ChannelControlScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: appState.selectedDevice == null
                ? const Center(
                    child: Text('No device connected'),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '控制每个通道的执行方式',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '支持即时设置、渐变、闪烁和爆闪。根据需要选择命令类型并配置参数。',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      if (appState.errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            appState.errorMessage,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: appState.selectedDevice!.channels.length,
                          itemBuilder: (context, index) {
                            final channel = appState.selectedDevice!.channels[index];
                            return ChannelControlCard(
                              channelId: channel.id,
                              channelName: channel.name,
                              value: channel.value,
                              onSetValue: (value) =>
                                  appState.updateChannelValue(channel.id, value),
                              onFadeCommand: (targetValue, duration) => appState
                                  .sendFadeCommand(
                                      channelId: channel.id,
                                      targetValue: targetValue,
                                      duration: duration),
                              onBlinkCommand: (period) => appState
                                  .sendBlinkCommand(
                                      channelId: channel.id, period: period),
                              onStrobeCommand: (flashCount, totalDuration,
                                      pauseDuration) =>
                                  appState.sendStrobeCommand(
                                      channelId: channel.id,
                                      flashCount: flashCount,
                                      totalDuration: totalDuration,
                                      pauseDuration: pauseDuration),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
