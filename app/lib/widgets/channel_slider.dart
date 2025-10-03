import 'package:flutter/material.dart';

class ChannelSlider extends StatelessWidget {
  final int channelId;
  final String channelName;
  final int value;
  final Function(int) onChanged;

  const ChannelSlider({
    Key? key,
    required this.channelId,
    required this.channelName,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  channelName.isNotEmpty ? channelName : 'Channel $channelId',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Slider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              divisions: 255,
              label: value.toString(),
              onChanged: (double newValue) {
                onChanged(newValue.toInt());
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('0'),
                Text('255'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}