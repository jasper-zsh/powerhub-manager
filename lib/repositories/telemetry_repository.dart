import 'package:app/models/monitoring_data.dart';
import 'package:app/models/telemetry.dart';
import 'package:app/services/ble_service.dart';

/// 负责管理遥测、监控与通道状态通知的仓库
class TelemetryRepository {
  TelemetryRepository({BLEService? bleService})
      : _bleService = bleService ?? BLEService();

  final BLEService _bleService;

  Future<MonitoringData> readTelemetrySnapshot() {
    return _bleService.readTelemetrySnapshot();
  }

  Future<Stream<MonitoringData>> subscribeTelemetry() {
    return _bleService.enableTelemetryNotifications();
  }

  Future<void> unsubscribeTelemetry() {
    return _bleService.disableTelemetryNotifications();
  }

  Future<MonitoringData> readMonitoringData() {
    return _bleService.readMonitoringData();
  }

  Future<Stream<MonitoringData>> subscribeMonitoring() {
    return _bleService.enableMonitoringNotifications();
  }

  Future<void> unsubscribeMonitoring() {
    return _bleService.disableMonitoringNotifications();
  }

  Future<List<int>> readChannelStates() {
    return _bleService.readChannelStates();
  }

  Future<Stream<List<int>>> subscribeChannelStates() {
    return _bleService.enableChannelStateNotifications();
  }

  Future<void> unsubscribeChannelStates() {
    return _bleService.disableChannelStateNotifications();
  }
}
