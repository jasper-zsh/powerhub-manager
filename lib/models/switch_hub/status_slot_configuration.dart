import 'status_slot_config.dart';
import 'status_data_type.dart';

/// Configuration model for managing status slots in the UI
/// This class provides additional metadata and state management for the UI layer
class StatusSlotConfiguration {
  const StatusSlotConfiguration({
    this.slot1,
    this.slot2,
    this.isConfigured = false,
  });

  /// First status slot (top position in UI)
  final StatusSlot? slot1;

  /// Second status slot (bottom position in UI)
  final StatusSlot? slot2;

  /// Whether any status slots are configured
  final bool isConfigured;

  /// Creates a copy with updated values
  StatusSlotConfiguration copyWith({
    StatusSlot? slot1,
    StatusSlot? slot2,
    bool? isConfigured,
  }) {
    return StatusSlotConfiguration(
      slot1: slot1 ?? this.slot1,
      slot2: slot2 ?? this.slot2,
      isConfigured: isConfigured ?? this.isConfigured,
    );
  }

  /// Gets all configured status slots
  List<StatusSlot> get slots {
    final result = <StatusSlot>[];
    if (slot1 != null) result.add(slot1!);
    if (slot2 != null) result.add(slot2!);
    return result;
  }

  /// Updates the value for a specific slot by matching source and data type
  StatusSlotConfiguration updateSlotValue({
    required String sourceMac,
    required StatusDataType dataType,
    required String? params,
    required String? newValue,
  }) {
    var updatedSlot1 = slot1;
    var updatedSlot2 = slot2;

    if (slot1 != null &&
        slot1!.sourceMac == sourceMac &&
        slot1!.dataType == dataType &&
        slot1!.params == params) {
      updatedSlot1 = slot1!.withValue(newValue);
    }

    if (slot2 != null &&
        slot2!.sourceMac == sourceMac &&
        slot2!.dataType == dataType &&
        slot2!.params == params) {
      updatedSlot2 = slot2!.withValue(newValue);
    }

    return StatusSlotConfiguration(
      slot1: updatedSlot1,
      slot2: updatedSlot2,
      isConfigured: isConfigured,
    );
  }

  /// Validates all configured status slots
  List<String> validate() {
    final errors = <String>[];

    if (slot1 != null) {
      final error = slot1!.validate();
      if (error != null) {
        errors.add('Slot 1: $error');
      }
    }

    if (slot2 != null) {
      final error = slot2!.validate();
      if (error != null) {
        errors.add('Slot 2: $error');
      }
    }

    return errors;
  }

  /// Checks if any slots require remote connections
  bool get requiresRemoteConnection {
    return slots.any((slot) => slot.requiresRemoteConnection);
  }

  /// Gets all remote MAC addresses that need to be connected
  Set<String> get remoteMacAddresses {
    return slots
        .where((slot) => slot.requiresRemoteConnection)
        .map((slot) => slot.sourceMac)
        .toSet();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StatusSlotConfiguration &&
        other.slot1 == slot1 &&
        other.slot2 == slot2 &&
        other.isConfigured == isConfigured;
  }

  @override
  int get hashCode {
    return Object.hash(slot1, slot2, isConfigured);
  }

  @override
  String toString() {
    return 'StatusSlotConfiguration(slot1: $slot1, slot2: $slot2, isConfigured: $isConfigured)';
  }
}