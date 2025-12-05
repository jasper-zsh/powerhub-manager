import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/switch_hub/status_slot_config.dart';
import 'package:app/models/switch_hub/status_data_source.dart';
import 'package:app/models/switch_hub/status_data_type.dart';
import 'package:app/widgets/status/status_slot_widget.dart';

void main() {
  group('StatusSlotWidget Tests', () {
    testWidgets('displays local voltage status correctly', (WidgetTester tester) async {
      const statusSlot = StatusSlot(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
        value: '12.5V',
        label: '输入电压',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusSlotWidget(statusSlot: statusSlot),
          ),
        ),
      );

      // Verify the label is displayed
      expect(find.text('输入电压'), findsOneWidget);

      // Verify the value is displayed
      expect(find.text('12.5V'), findsOneWidget);

      // Verify the unit is displayed
      expect(find.text('V'), findsOneWidget);
    });

    testWidgets('displays remote current status correctly', (WidgetTester tester) async {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0',
        value: '1.250A',
        label: '通道0电流',
      );

      const dataSource = StatusDataSource(
        macAddress: 'AA:BB:CC:DD:EE:FF',
        deviceName: 'PowerHub-1',
        connectionStatus: ConnectionStatus.connected,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusSlotWidget(
              statusSlot: statusSlot,
              dataSource: dataSource,
            ),
          ),
        ),
      );

      // Verify the label is displayed
      expect(find.text('通道0电流'), findsOneWidget);

      // Verify the value is displayed
      expect(find.text('1.250A'), findsOneWidget);

      // Verify the connected device indicator
      expect(find.byIcon(Icons.bluetooth_connected), findsOneWidget);
    });

    testWidgets('displays connection error state correctly', (WidgetTester tester) async {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.voltage,
        value: null, // No value
      );

      const dataSource = StatusDataSource(
        macAddress: 'AA:BB:CC:DD:EE:FF',
        deviceName: 'PowerHub-1',
        connectionStatus: ConnectionStatus.connectionFailed,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusSlotWidget(
              statusSlot: statusSlot,
              dataSource: dataSource,
            ),
          ),
        ),
      );

      // Verify the error state
      expect(find.text('--'), findsOneWidget);
      expect(find.text('连接错误'), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth_disabled), findsOneWidget);
    });

    testWidgets('displays loading state correctly', (WidgetTester tester) async {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.voltage,
        value: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusSlotWidget(
              statusSlot: statusSlot,
              isLoading: true,
            ),
          ),
        ),
      );

      // Verify loading indicator is shown when loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays temperature status correctly', (WidgetTester tester) async {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.temperature,
        params: 'POWER',
        value: '27.5°C',
        label: '电源区温度',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusSlotWidget(statusSlot: statusSlot),
          ),
        ),
      );

      // Verify the label is displayed
      expect(find.text('电源区温度'), findsOneWidget);

      // Verify the value is displayed
      expect(find.text('27.5°C'), findsOneWidget);

      // Verify temperature icon
      expect(find.byIcon(Icons.thermostat), findsOneWidget);
    });

    testWidgets('generates default label correctly', (WidgetTester tester) async {
      const statusSlot = StatusSlot(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
        value: '12.5V',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusSlotWidget(statusSlot: statusSlot),
          ),
        ),
      );

      // Should show default label for local voltage
      expect(find.text('输入电压'), findsOneWidget);
    });
  });

  group('StatusDisplayRow Tests', () {
    testWidgets('displays two status slots correctly', (WidgetTester tester) async {
      const slot1 = StatusSlot(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
        value: '12.5V',
        label: '电压',
      );

      const slot2 = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0',
        value: '1.250A',
        label: '电流',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusDisplayRow(slot1: slot1, slot2: slot2),
          ),
        ),
      );

      // Verify both slots are displayed
      expect(find.text('电压'), findsOneWidget);
      expect(find.text('12.5V'), findsOneWidget);
      expect(find.text('电流'), findsOneWidget);
      expect(find.text('1.250A'), findsOneWidget);
    });

    testWidgets('displays single status slot correctly', (WidgetTester tester) async {
      const slot1 = StatusSlot(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
        value: '12.5V',
        label: '电压',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusDisplayRow(slot1: slot1),
          ),
        ),
      );

      // Verify the single slot is displayed
      expect(find.text('电压'), findsOneWidget);
      expect(find.text('12.5V'), findsOneWidget);
    });

    testWidgets('displays empty state when no slots', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusDisplayRow(),
          ),
        ),
      );

      // Verify empty state message
      expect(find.text('未配置状态显示'), findsOneWidget);
    });
  });

  group('StatusDisplayEmptyState Tests', () {
    testWidgets('displays empty state correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusDisplayEmptyState(),
          ),
        ),
      );

      // Verify empty state message and icon
      expect(find.text('状态显示未配置'), findsOneWidget);
      expect(find.text('请在设备配置中添加状态插槽'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });
}