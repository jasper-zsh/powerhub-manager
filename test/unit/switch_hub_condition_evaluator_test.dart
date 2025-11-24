import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/switch_hub/condition_evaluator.dart';
import 'package:app/models/switch_hub/state_context.dart';

void main() {
  test('evaluates boolean expressions with precedence and aliases', () {
    final context = SwitchHubStateContext(
      activeStates: {
        'SW1': 'ON',
        'SW2': 'OFF',
        'SW3': 'ON',
      },
    );
    final evaluator = SwitchHubConditionEvaluator(context);
    expect(evaluator.evaluate('SW1.ON'), isTrue);
    expect(evaluator.evaluate('SW2.ON'), isFalse);
    expect(
      evaluator.evaluate('(SW1.ON AND NOT SW2.ON) OR SW3.OFF'),
      isTrue,
    );
    expect(evaluator.evaluate('NOT (SW3.ON AND SW2.ON)'), isTrue);
  });
}
