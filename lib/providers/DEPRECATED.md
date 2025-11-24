# 已弃用的 Provider

此目录中的 Provider 已被新的 Riverpod 架构取代，不应再使用。

## 迁移映射

| 旧 Provider | 新 Controller | 说明 |
|-------------|---------------|------|
| AppStateProvider | ConnectionSessionController + DiscoveryController + SavedControllerController | 连接、发现和保存的控制器管理 |
| DeviceControlProvider | DeviceControlController | 设备控制和预设管理 |
| OrchestrationProvider | OrchestrationController | 场景编排和执行日志 |

## 迁移指南

详细的迁移指南请参考: [docs/state_migration_guide.md](../../docs/state_migration_guide.md)

## 计划

这些文件将在下一个主要版本中被移除。请尽快迁移到新的 Riverpod 架构。

## 兼容性

为了向后兼容，这些 Provider 仍然存在，但它们只是新 Controller 的薄包装层。建议直接使用新的 Controller 以获得更好的性能和类型安全。