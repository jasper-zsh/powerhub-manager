/// Provides runtime knowledge about each toggle's current state. The context is
/// consumed by the IFTTT expression evaluator to decide whether a leaf sequence
/// should run.
class SwitchHubStateContext {
  const SwitchHubStateContext({
    required this.activeStates,
    Map<String, String>? aliases,
    this.onMissingIdentifier,
  }) : aliases = aliases ?? const <String, String>{};

  /// toggleId -> stateId snapshot.
  final Map<String, String> activeStates;
  final Map<String, String> aliases;
  final void Function(String identifier)? onMissingIdentifier;

  /// Returns `true` when the current snapshot indicates that the given toggle is
  /// in the requested state. Identifiers follow the `SW1.ON` style described in
  /// the BLE specification.
  bool matchesIdentifier(String identifier) {
    final normalized = identifier.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final parts = normalized.split('.');
    if (parts.length != 2) {
      onMissingIdentifier?.call(identifier);
      return false;
    }

    final toggleKey = aliases[parts.first] ?? parts.first;
    final targetState = parts.last.toLowerCase();
    final current = activeStates[toggleKey];
    if (current == null) {
      onMissingIdentifier?.call(toggleKey);
      return false;
    }
    return current.toLowerCase() == targetState;
  }
}
