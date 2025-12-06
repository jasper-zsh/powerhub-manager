import 'package:flutter/material.dart';
import 'package:app/models/orchestration/toggle_scene.dart';

/// Preview component for dynamic actions with timeline visualization
class DynamicActionPreview extends StatelessWidget {
  final CommandAction action;
  final double width;
  final double height;

  const DynamicActionPreview({
    super.key,
    required this.action,
    this.width = 300,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    switch (action.type) {
      case CommandActionType.gradientMode:
        return GradientModePreview(
          action: action,
          width: width,
          height: height,
        );
      case CommandActionType.blinkMode:
        return BlinkModePreview(
          action: action,
          width: width,
          height: height,
        );
      case CommandActionType.strobeMode:
        return StrobeModePreview(
          action: action,
          width: width,
          height: height,
        );
      default:
        return SizedBox(
          width: width,
          height: height,
          child: const Center(
            child: Text('No preview available'),
          ),
        );
    }
  }
}

/// Preview component for gradient mode actions with timeline visualization
class GradientModePreview extends StatelessWidget {
  final CommandAction action;
  final double width;
  final double height;

  const GradientModePreview({
    super.key,
    required this.action,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final startValue = 0; // Assume starting from 0 (could be enhanced)
    final endValue = action.value ?? 0;
    final duration = action.duration ?? 1000;

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gradient: ${startValue} → ${endValue} over ${duration}ms',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: height - 24,
            child: CustomPaint(
              painter: GradientTimelinePainter(
                startValue: startValue,
                endValue: endValue,
                duration: duration,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Preview component for blink mode actions with pattern visualization
class BlinkModePreview extends StatelessWidget {
  final CommandAction action;
  final double width;
  final double height;

  const BlinkModePreview({
    super.key,
    required this.action,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final period = action.period ?? 1000;
    final frequency = 1000.0 / period;

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Blink: ${frequency.toStringAsFixed(1)}Hz (${period}ms period)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: height - 24,
            child: CustomPaint(
              painter: BlinkPatternPainter(
                period: period,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Preview component for strobe mode actions with complex timing visualization
class StrobeModePreview extends StatelessWidget {
  final CommandAction action;
  final double width;
  final double height;

  const StrobeModePreview({
    super.key,
    required this.action,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final count = action.count ?? 1;
    final totalTime = action.totalTime ?? 1000;
    final pauseTime = action.pauseTime ?? 100;
    final frequency = (count * 1000.0) / totalTime;

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Strobe: ${count} flashes, ${frequency.toStringAsFixed(1)}Hz',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            'Total: ${totalTime}ms, Pause: ${pauseTime}ms',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: height - 38,
            child: CustomPaint(
              painter: StrobePatternPainter(
                count: count,
                totalTime: totalTime,
                pauseTime: pauseTime,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for gradient timeline visualization
class GradientTimelinePainter extends CustomPainter {
  final int startValue;
  final int endValue;
  final int duration;
  final Color color;

  GradientTimelinePainter({
    required this.startValue,
    required this.endValue,
    required this.duration,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw gradient line
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.2), color],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.2),
      paint,
    );

    // Draw gradient line
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.45, size.width, size.height * 0.1),
      gradientPaint,
    );

    // Draw start and end points
    canvas.drawCircle(
      Offset(0, size.height / 2),
      3,
      linePaint,
    );

    canvas.drawCircle(
      Offset(size.width, size.height / 2),
      3,
      linePaint,
    );

    // Draw value labels
    final textPainter = TextPainter(
      text: TextSpan(
        text: startValue.toString(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(0, size.height / 2 - 15),
    );

    textPainter.text = TextSpan(
      text: endValue.toString(),
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.width - textPainter.width, size.height / 2 - 15),
    );
  }

  @override
  bool shouldRepaint(covariant GradientTimelinePainter oldDelegate) {
    return oldDelegate.startValue != startValue ||
        oldDelegate.endValue != endValue ||
        oldDelegate.duration != duration ||
        oldDelegate.color != color;
  }
}

/// Custom painter for blink pattern visualization
class BlinkPatternPainter extends CustomPainter {
  final int period;
  final Color color;

  BlinkPatternPainter({
    required this.period,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Show 2 complete blink cycles
    final cyclesToShow = 2;
    final cycleWidth = size.width / cyclesToShow;

    for (int cycle = 0; cycle < cyclesToShow; cycle++) {
      final startX = cycle * cycleWidth;

      // Draw on state (first half of period)
      canvas.drawRect(
        Rect.fromLTWH(startX, 0, cycleWidth * 0.5, size.height),
        paint,
      );

      // Draw off state (second half of period)
      canvas.drawRect(
        Rect.fromLTWH(startX + cycleWidth * 0.5, 0, cycleWidth * 0.5, size.height),
        Paint()
          ..color = color.withOpacity(0.1)
          ..style = PaintingStyle.fill,
      );
    }

    // Draw period divider lines
    final linePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 1; i < cyclesToShow; i++) {
      canvas.drawLine(
        Offset(i * cycleWidth, 0),
        Offset(i * cycleWidth, size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BlinkPatternPainter oldDelegate) {
    return oldDelegate.period != period || oldDelegate.color != color;
  }
}

/// Custom painter for strobe pattern visualization
class StrobePatternPainter extends CustomPainter {
  final int count;
  final int totalTime;
  final int pauseTime;
  final Color color;

  StrobePatternPainter({
    required this.count,
    required this.totalTime,
    required this.pauseTime,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final lightPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Calculate flash duration and spacing
    final activeTime = totalTime - pauseTime;
    final flashDuration = activeTime ~/ count;
    final spacing = (totalTime - (flashDuration * count)) / (count + 1);

    double currentX = 0;

    // Draw strobe pattern
    for (int i = 0; i < count; i++) {
      // Add spacing before flash
      currentX += (spacing / totalTime) * size.width;

      // Draw flash
      final flashWidth = (flashDuration / totalTime) * size.width;
      canvas.drawRect(
        Rect.fromLTWH(currentX, 0, flashWidth, size.height),
        fillPaint,
      );

      currentX += flashWidth;
    }

    // Draw pause period
    final pauseWidth = (pauseTime / totalTime) * size.width;
    if (currentX < size.width - pauseWidth) {
      canvas.drawRect(
        Rect.fromLTWH(currentX, 0, pauseWidth, size.height),
        lightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StrobePatternPainter oldDelegate) {
    return oldDelegate.count != count ||
        oldDelegate.totalTime != totalTime ||
        oldDelegate.pauseTime != pauseTime ||
        oldDelegate.color != color;
  }
}

/// Combined preview for multiple dynamic actions in sequence
class CombinedDynamicActionPreview extends StatelessWidget {
  final List<CommandAction> actions;
  final double width;
  final double height;

  const CombinedDynamicActionPreview({
    super.key,
    required this.actions,
    this.width = 400,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: Text('No actions to preview'),
        ),
      );
    }

    final dynamicActions = actions.where((action) =>
      action.type == CommandActionType.gradientMode ||
      action.type == CommandActionType.blinkMode ||
      action.type == CommandActionType.strobeMode,
    ).toList();

    if (dynamicActions.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: Text('No dynamic actions to preview'),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dynamic Actions Preview',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.vertical,
              itemCount: dynamicActions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final action = dynamicActions[index];
                return DynamicActionPreview(
                  action: action,
                  width: width,
                  height: 30,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}