import 'toggle_scene.dart';

class ActionValidator {
  /// Validates a CommandAction and returns an error message if invalid
  static String? validate(CommandAction action) {
    switch (action.type) {
      case CommandActionType.channelValue:
        return _validateChannelValue(action);
      case CommandActionType.gradientMode:
        return _validateGradientMode(action);
      case CommandActionType.blinkMode:
        return _validateBlinkMode(action);
      case CommandActionType.strobeMode:
        return _validateStrobeMode(action);
      case CommandActionType.presetTrigger:
        return _validatePresetTrigger(action);
    }
  }

  static String? _validateChannelValue(CommandAction action) {
    if (action.channel == null) {
      return 'Channel value actions require a channel ID';
    }
    if (action.value == null) {
      return 'Channel value actions require a PWM value';
    }
    if (action.channel! < 0 || action.channel! > 5) {
      return 'Channel must be between 0 and 5';
    }
    if (action.value! < 0 || action.value! > 255) {
      return 'PWM value must be between 0 and 255';
    }
    return null;
  }

  static String? _validateGradientMode(CommandAction action) {
    if (action.channel == null) {
      return 'Gradient mode actions require a channel ID';
    }
    if (action.value == null) {
      return 'Gradient mode actions require a target value';
    }
    if (action.duration == null) {
      return 'Gradient mode actions require a duration';
    }

    // Channel validation
    if (action.channel! < 0 || action.channel! > 5) {
      return 'Channel must be between 0 and 5';
    }

    // Target value validation
    if (action.value! < 0 || action.value! > 255) {
      return 'Target value must be between 0 and 255';
    }

    // Duration validation
    if (action.duration! < 1) {
      return 'Duration must be at least 1ms';
    }
    if (action.duration! > 60000) {
      return 'Duration must not exceed 60 seconds (60000ms)';
    }

    return null;
  }

  static String? _validateBlinkMode(CommandAction action) {
    if (action.channel == null) {
      return 'Blink mode actions require a channel ID';
    }
    if (action.period == null) {
      return 'Blink mode actions require a period';
    }

    // Channel validation
    if (action.channel! < 0 || action.channel! > 5) {
      return 'Channel must be between 0 and 5';
    }

    // Period validation
    if (action.period! < 50) {
      return 'Period must be at least 50ms for visible blinking';
    }
    if (action.period! > 10000) {
      return 'Period must not exceed 10 seconds (10000ms)';
    }

    // Frequency warning (but not an error)
    if (action.period! > 5000) {
      // Return as suggestion rather than error
      return null; // No error, but could warn about long period
    }

    return null;
  }

  static String? _validateStrobeMode(CommandAction action) {
    if (action.channel == null) {
      return 'Strobe mode actions require a channel ID';
    }
    if (action.count == null) {
      return 'Strobe mode actions require a count';
    }
    if (action.totalTime == null) {
      return 'Strobe mode actions require total time';
    }
    if (action.pauseTime == null) {
      return 'Strobe mode actions require pause time';
    }

    // Channel validation
    if (action.channel! < 0 || action.channel! > 5) {
      return 'Channel must be between 0 and 5';
    }

    // Count validation
    if (action.count! < 1) {
      return 'Count must be at least 1';
    }
    if (action.count! > 255) {
      return 'Count must not exceed 255';
    }

    // Total time validation
    if (action.totalTime! < 10) {
      return 'Total time must be at least 10ms';
    }
    if (action.totalTime! > 60000) {
      return 'Total time must not exceed 60 seconds (60000ms)';
    }

    // Pause time validation
    if (action.pauseTime! < 1) {
      return 'Pause time must be at least 1ms';
    }

    // Relationship validation
    if (action.pauseTime! >= action.totalTime!) {
      return 'Pause time must be less than total time';
    }

    return null;
  }

  static String? _validatePresetTrigger(CommandAction action) {
    if (action.presetId == null) {
      return 'Preset trigger actions require a preset ID';
    }
    if (action.presetId! < 0) {
      return 'Preset ID must be positive';
    }
    return null;
  }

  /// Get a user-friendly description of the action type
  static String getActionTypeDescription(CommandActionType type) {
    switch (type) {
      case CommandActionType.channelValue:
        return 'Set channel to static value immediately';
      case CommandActionType.gradientMode:
        return 'Smooth transition to target value over specified duration';
      case CommandActionType.blinkMode:
        return 'Periodic on/off blinking with specified period';
      case CommandActionType.strobeMode:
        return 'Strobe effect with count, timing, and pause intervals';
      case CommandActionType.presetTrigger:
        return 'Activate a preset configuration';
    }
  }

  /// Get parameter examples for the action type
  static List<String> getParameterExamples(CommandActionType type) {
    switch (type) {
      case CommandActionType.channelValue:
        return ['Channel: 0-5, Value: 0-255', 'Example: Channel 2, Value 128'];
      case CommandActionType.gradientMode:
        return ['Channel: 0-5, Target: 0-255, Duration: 100-60000ms',
               'Example: Channel 1, Target 200, Duration 2000ms (2 seconds)'];
      case CommandActionType.blinkMode:
        return ['Channel: 0-5, Period: 50-10000ms',
               'Example: Channel 0, Period 1000ms (1 Hz)',
               'Example: Channel 3, Period 500ms (2 Hz)'];
      case CommandActionType.strobeMode:
        return ['Channel: 0-5, Count: 1-255, Total Time: 10-60000ms, Pause Time: 1-TotalTime-1',
               'Example: Channel 2, Count 5, Total Time 3000ms, Pause 500ms',
               'Example: Channel 4, Count 10, Total Time 2000ms, Pause 200ms'];
      case CommandActionType.presetTrigger:
        return ['Preset ID: positive integer', 'Example: Preset ID 1'];
    }
  }

  /// Get suggested values for the action type
  static Map<String, List<int>> getSuggestedValues(CommandActionType type) {
    switch (type) {
      case CommandActionType.channelValue:
        return {
          'Quick on': [255],
          'Quick off': [0],
          'Half brightness': [128],
          'Dim': [64],
        };
      case CommandActionType.gradientMode:
        return {
          'Quick fade': [500],
          'Slow fade': [2000],
          'Very slow fade': [5000],
        };
      case CommandActionType.blinkMode:
        return {
          'Fast blink': [250],
          'Normal blink': [1000],
          'Slow blink': [2000],
        };
      case CommandActionType.strobeMode:
        return {
          'Quick bursts': [10, 1000, 200],
          'Normal strobe': [5, 2000, 500],
          'Slow strobe': [3, 3000, 1000],
        };
      case CommandActionType.presetTrigger:
        return {};
    }
  }

  /// Calculate frequency for blink mode
  static double calculateBlinkFrequency(int periodMs) {
    if (periodMs <= 0) return 0.0;
    return 1000.0 / periodMs;
  }

  /// Calculate effective frequency for strobe mode
  static double calculateStrobeFrequency(int count, int totalTimeMs) {
    if (totalTimeMs <= 0 || count <= 0) return 0.0;
    return (count * 1000.0) / totalTimeMs;
  }
}