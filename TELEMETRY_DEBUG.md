# Telemetry 数据调试指南

## 问题诊断

### 原始错误
```
D/[FBP-Android](16940): [FBP] onCharacteristicRead:
D/[FBP-Android](16940): [FBP]   chr: fff5
D/[FBP-Android](16940): [FBP]   status: GATT_SUCCESS (0)
I/flutter (16940): Failed to read telemetry with error: Exception: INVALID_DATA
I/flutter (16940): AppStateProvider: Telemetry initialized
```

### 问题分析
1. 设备成功读取了特征 `fff5`
2. GATT操作成功 (`GATT_SUCCESS`)
3. 应用抛出 `INVALID_DATA` 错误

### 解决方案
更新了telemetry数据读取逻辑以支持新旧两种数据格式：

## 支持的数据格式

### 1. 新格式 (8字节) - 电源管理配置
```
偏移   长度   类型      描述
0      2      int16     高温阈值 (0.01°C)
2      2      int16     恢复阈值 (0.01°C)
4      2      uint16    睡眠电压阈值 (mV)
6      2      uint16    唤醒电压阈值 (mV)
```

### 2. 旧格式 (16字节) - 完整遥测数据
```
偏移   长度   类型      描述
0      2      uint16    输入电压 (mV)
2      2      int16     当前温度 (0.01°C)
4      2      int16     高温阈值 (0.01°C)
6      2      int16     恢复阈值 (0.01°C)
8      2      uint16    睡眠电压阈值 (mV)
10     2      uint16    唤醒电压阈值 (mV)
12     1      uint8     状态标志
13     1      -         保留字节
14     2      -         保留字
```

### 3. 通知格式 (12字节) - 增量更新
旧协议中使用的通知格式，包含增量遥测数据。

## 调试日志

应用现在会输出详细的调试信息：

### 读取调试
```
I/flutter: Telemetry read raw data length: X, bytes: [hex data]
```

### 通知调试
```
I/flutter: Telemetry notification raw data length: X, bytes: [hex data]
```

## 数据格式转换

当设备返回8字节数据时，应用会：
1. 解析为 `PowerManagementConfig`
2. 转换为 `TelemetryData` 格式
3. 设置电压字段为0（新格式中不包含输入电压）
4. 使用高温阈值作为当前温度显示
5. 设置状态标志为温度数据有效

## 故障排除

### 检查步骤

1. **验证数据长度**
   - 新设备应该返回8字节
   - 旧设备可能返回16字节
   - 其他长度会被拒绝

2. **检查字节顺序**
   - 使用大端字节序 (Big-endian)
   - 高字节在前，低字节在后

3. **验证数据值**
   - 温度阈值应该合理 (20-80°C范围)
   - 电压阈值应该合理 (10-16V范围)

4. **检查状态标志**
   - bit0: 热保护激活
   - bit1: 温度数据有效
   - bit2: 电流数据有效

### 常见问题

**问题**: `INVALID_DATA: Expected 8 or 16 bytes, got X`
- **原因**: 设备返回了不期望的数据长度
- **解决**: 检查ESP32固件中的数据格式实现

**问题**: 温度显示异常值
- **原因**: 字节顺序错误或数据损坏
- **解决**: 检查原始字节数据和解析逻辑

**问题**: 电压显示为0
- **原因**: 新格式中不包含输入电压数据
- **解决**: 这是正常的，新格式使用监控特征获取电压数据

## 测试验证

运行测试以验证兼容性：
```bash
flutter test test/unit/telemetry_compatibility_test.dart
```

## 更新内容

✅ **向后兼容性**: 支持新旧两种数据格式
✅ **详细日志**: 添加原始数据调试输出
✅ **错误处理**: 改进错误消息和数据验证
✅ **测试覆盖**: 添加兼容性测试用例

现在应用应该能够正确处理ESP32设备返回的telemetry数据，无论使用的是新固件还是旧固件。