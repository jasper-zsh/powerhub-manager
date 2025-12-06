import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/models/switch_hub/state_context.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/providers/orchestration_provider.dart';

/// Widget for building boolean expressions like (SW1.ON AND NOT SW2.OFF) OR SW3.ON
class ConditionBuilder extends ConsumerStatefulWidget {
  const ConditionBuilder({
    super.key,
    required this.onConditionChanged,
    this.initialCondition,
    this.availableToggles = const [],
    this.aliases = const {},
  });

  final Function(String) onConditionChanged;
  final String? initialCondition;
  final List<String> availableToggles;
  final Map<String, String> aliases;

  @override
  ConsumerState<ConditionBuilder> createState() => _ConditionBuilderState();
}

class _ConditionBuilderState extends ConsumerState<ConditionBuilder> {
  late String _condition;
  bool _isValid = true;
  List<String> _validationErrors = [];

  @override
  void initState() {
    super.initState();
    _condition = widget.initialCondition ?? '';
    // Don't validate during init to avoid triggering onConditionChanged callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _validateCondition();
      }
    });
  }

  @override
  void didUpdateWidget(ConditionBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update condition if the initialCondition actually changed
    if (oldWidget.initialCondition != widget.initialCondition) {
      setState(() {
        _condition = widget.initialCondition ?? '';
      });
      _validateCondition();
    }
  }

  void _validateCondition() {
    setState(() {
      if (_condition.trim().isEmpty) {
        _isValid = true;
        _validationErrors = [];
        return;
      }

      // Create a mock state context for validation
      final context = SwitchHubStateContext(
        activeStates: {},
        aliases: widget.aliases,
        onMissingIdentifier: (identifier) {
          setState(() {
            if (!_validationErrors.contains('Unknown reference: $identifier')) {
              _validationErrors.add('Unknown reference: $identifier');
            }
          });
        },
      );

      // Check for basic syntax validation
      final errors = <String>[];

      // Check parentheses matching
      int parenCount = 0;
      for (int i = 0; i < _condition.length; i++) {
        final char = _condition[i];
        if (char == '(') parenCount++;
        else if (char == ')') parenCount--;

        if (parenCount < 0) {
          errors.add('Unmatched closing parenthesis at position $i');
          break;
        }
      }

      if (parenCount != 0) {
        errors.add('Unmatched opening parenthesis');
      }

      // Check for valid tokens
      final tokens = _tokenizeExpression(_condition);
      for (final token in tokens) {
        if (!_isValidToken(token)) {
          errors.add('Invalid token: $token');
        }
      }

      _validationErrors = errors;
      _isValid = errors.isEmpty;

      // Notify parent of validation result
      widget.onConditionChanged(_isValid ? _condition : '');
    });
  }

  List<String> _tokenizeExpression(String expression) {
    final regex = RegExp(r'(\(|\)|AND|OR|NOT|SW\d+\.(ON|OFF)|\w+\.\w+|\w+)');
    final matches = regex.allMatches(expression);
    return matches.map((match) => match.group(0)!).toList();
  }

  bool _isValidToken(String token) {
    // Check if it's a valid operator
    if (['(', ')', 'AND', 'OR', 'NOT'].contains(token.toUpperCase())) {
      return true;
    }

    // Check if it's a valid toggle reference
    final toggleRegex = RegExp(r'^SW\d+\.(ON|OFF)$', caseSensitive: false);
    if (toggleRegex.hasMatch(token)) {
      return true;
    }

    // Check for alias references
    if (widget.aliases.containsKey(token.toUpperCase())) {
      return true;
    }

    return false;
  }

  void _addTokenToCondition(String token) {
    setState(() {
      if (_condition.isEmpty) {
        _condition = token;
      } else {
        _condition = '$_condition $token';
      }
      _validateCondition();
    });
    widget.onConditionChanged(_condition);
  }

  void _removeLastToken() {
    setState(() {
      final tokens = _tokenizeExpression(_condition);
      if (tokens.isNotEmpty) {
        tokens.removeLast();
        _condition = tokens.join(' ');
      } else {
        _condition = '';
      }
      _validateCondition();
    });
    widget.onConditionChanged(_condition);
  }

  void _clearCondition() {
    setState(() {
      _condition = '';
      _validateCondition();
    });
    widget.onConditionChanged(_condition);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Expression display
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isValid
                ? theme.colorScheme.surfaceContainer
                : theme.colorScheme.errorContainer.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isValid
                  ? theme.colorScheme.outline.withOpacity(0.3)
                  : theme.colorScheme.error,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _condition.isEmpty ? 'Tap buttons below to build condition' : _condition,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: 'monospace',
                  color: _isValid ? null : theme.colorScheme.onErrorContainer,
                ),
              ),
              if (_validationErrors.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._validationErrors.map((error) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    error,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                )),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Toggle reference buttons
        _buildToggleReferenceButtons(),

        const SizedBox(height: 16),

        // Logical operator buttons
        _buildOperatorButtons(),

        const SizedBox(height: 16),

        // Control buttons
        _buildControlButtons(),

        const SizedBox(height: 16),

        // Example templates
        _buildExampleTemplates(),
      ],
    );
  }

  Widget _buildToggleReferenceButtons() {
    final toggles = widget.availableToggles.isEmpty
        ? ['SW1', 'SW2', 'SW3', 'SW4', 'SW5'] // Default examples
        : widget.availableToggles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Toggle References:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: toggles.map((toggle) => [
            _buildReferenceButton('$toggle.ON'),
            _buildReferenceButton('$toggle.OFF'),
          ]).expand((element) => element).toList(),
        ),

        // Alias references
        if (widget.aliases.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Aliases:', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.aliases.entries.map((entry) => [
              _buildReferenceButton('${entry.key}.ON'),
              _buildReferenceButton('${entry.key}.OFF'),
            ]).expand((element) => element).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildReferenceButton(String reference) {
    return ElevatedButton(
      onPressed: () => _addTokenToCondition(reference),
      child: Text(reference),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildOperatorButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Logical Operators:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildOperatorButton('AND'),
            _buildOperatorButton('OR'),
            _buildOperatorButton('NOT'),
            _buildOperatorButton('('),
            _buildOperatorButton(')'),
          ],
        ),
      ],
    );
  }

  Widget _buildOperatorButton(String operator) {
    return OutlinedButton(
      onPressed: () => _addTokenToCondition(operator),
      child: Text(operator),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _removeLastToken,
          icon: const Icon(Icons.backspace),
          label: const Text('Backspace'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _clearCondition,
          icon: const Icon(Icons.clear),
          label: const Text('Clear'),
        ),
        const Spacer(),
        if (_isValid)
          Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
          )
        else
          Icon(
            Icons.error,
            color: Theme.of(context).colorScheme.error,
          ),
      ],
    );
  }

  Widget _buildExampleTemplates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Example Templates:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTemplateButton('SW1.ON'),
            _buildTemplateButton('SW1.ON AND SW2.ON'),
            _buildTemplateButton('NOT SW3.OFF'),
            _buildTemplateButton('(SW1.ON AND NOT SW2.OFF) OR SW3.ON'),
          ],
        ),
      ],
    );
  }

  Widget _buildTemplateButton(String template) {
    return TextButton(
      onPressed: () {
        setState(() {
          _condition = template;
          _validateCondition();
        });
        widget.onConditionChanged(_condition);
      },
      child: Text(
        template,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}