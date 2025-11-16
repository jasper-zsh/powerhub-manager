# SwitchHub 蓝牙模块功能设计

## 1. 背景与目标
- SwitchHub 需要继承 `SWITCHHUB_BLE.md` 中定义的自有 GATT 服务，充当**配置接收端**。
- 目标设备遵循 `POWERHUB_BLE.md` 协议，SwitchHub 必须能**同时连接多个 PowerHub** 并对其下发通道控制命令。
- 模块要在单颗 ESP32 上实现「一端做 GATT Server 接收配置，另一端做 GATT Client 控制多目标」的双角色架构。

## 2. 功能范围
1. **GATT Server（配置入口）**  
   - 对外暴露 0xFFF1/0xFFF2/0xFFF3 特征，接口与 `SWITCHHUB_BLE.md` 完全一致。  
   - 接收/存储电压阈值、实时监控订阅以及开关逻辑 JSON 文件。  
   - 为客户端提供状态读取、配置分片写、CRC 校验与版本管理。
2. **GATT Client（多目标控制）**  
   - 以中心角色扫描、连接多个 PowerHub，读取其服务 `119B5F1B-...-0100-0B5E`。  
   - 维护每个目标的通道控制特征 0xFFF1、状态特征 0xFFF0、监控特征 0xFFF6 的句柄，并在启动或编排变更时主动连接编排文件中列出的全部设备。  
   - 按配置脚本顺序向不同目标透传 `POWERHUB_BLE.md` 定义的命令。
3. **连接调度与状态同步**  
   - 内部逻辑执行器遍历 JSON 中的 IF/ELSE 树、On/Off 序列，触发适当的 PowerHub 命令包。  
   - 支持多连接并发队列和失败重试；实时监控数据写入本地状态缓存，供 UI 状态区 (`status_slots`) 映射。

## 3. 协议角色分工
| 角色 | SwitchHub 视角 | PowerHub 视角 |
|------|----------------|---------------|
| 广播 | SwitchHub 广播自身服务 (被动)，不主动连接 | 作为外围设备等待连接 |
| 配置通道 | SwitchHub 作为 GATT Server 接收来自 App/控制中心的写入 | 不参与 |
| 执行通道 | SwitchHub 作为 GATT Client 对多个 PowerHub 发起连接 | PowerHub 作为 GATT Server，接收 0xFFF1 命令 |
| 状态采集 | SwitchHub 订阅 PowerHub 的 0xFFF0/0xFFF6；本地 0xFFF2 为客户端提供汇总 | PowerHub 发送通知 |

## 4. 模块组成
1. **Server 子系统**  
   - 复用 Nimble GATT Server，维系 0xFFF1/0xFFF2/0xFFF3。  
   - 0xFFF3 写入使用分片格式 `[chunk_seq][total_chunks][payload]`；所有片段到齐后执行 CRC32 校验，成功则替换逻辑脚本。  
   - 0xFFF2 定期以 4 字节结构上报输入电压与状态位，供客户端订阅。
2. **连接管理器**  
   - 负责扫描、维护最多 *N*（由 RAM/吞吐量配置）个 PowerHub 连接。  
   - 设备启动后立即根据当前编排 JSON 中的 `target_mac` 清单发起连接；编排更新成功后重复该过程，确保所有目标始终保持连接或正在重连。  
   - 为每个连接维护状态（RSSI、MTU、订阅标志、最后一次事件时间）。  
   - 当连接数达到上限时，采用 LRU 或优先级策略释放空闲连接。
3. **命令调度器**  
   - 接收逻辑执行器提交的 `command_packet`，按 `target_mac` 查找连接句柄。  
   - 如果连接尚未建立，触发异步连接并将命令压入等待队列。  
   - 执行命令时根据 `POWERHUB_BLE.md` 的通道控制格式拼装多命令写入，支持 `write without response` 或 MTU 分片。
4. **逻辑执行器**  
   - 解析 JSON 中 `on`/`off` 的 IF 树与 leaf 序列。  
   - 维护所有开关状态机，触发时生成执行计划（包含延迟、retry）并送入命令调度器。  
   - 同步 UI 区域绑定的监控数据，保证 `status_slots` 映射实时更新。
5. **状态缓存**  
   - 汇总自身输入电压 (0xFFF2) 与各 PowerHub 的监控值。  
   - 为逻辑条件（如 `SW1.ON`）提供快速查询，也供客户端读取 0xFFF2/0xFFF3 时附带 `metadata`。

## 5. 运行流程
设备上电后会读取存储中的最新编排 JSON，并立即派发 `target_mac` 列表给连接管理器，确保所有目标设备在后台并行连接与订阅。

1. **配置流程 (SwitchHub Server)**  
   1. 客户端发现 SwitchHub 的服务 UUID `...0200-0B5E`。  
   2. 读取 0xFFF3 `metadata` 获取 `total_size/chunk_size/schema_version/revision`。  
3. 通过分片写入完整 JSON；写入完毕后 SwitchHub 自动校验并应用。  
   4. 校验成功 -> 更新逻辑版本 -> 通知执行器加载新配置。  
   5. 连接管理器刷新 `target_mac` 集合，针对新增目标立即发起连接，对已移除目标断开并释放资源。
2. **控制流程 (SwitchHub Client)**  
   1. 执行器根据事件（触摸、自动化、定时）选择 On/Off 序列。  
   2. 对序列中的每个 `sequence_item`：  
      - 连接管理器确保 `target_mac` 已连接，必要时发起连接并订阅 0xFFF0/0xFFF6。  
      - 命令调度器根据 `mode/channel/payload` 形成写入 buffer，发送至 PowerHub 0xFFF1。  
      - 根据 `retry` 定义进行重试，失败则记录错误上报至 0xFFF2 状态位或事件队列。  
   3. 监控特征通知返回后更新状态缓存，并根据 `status_slots` 推送到 UI。
3. **多目标并发**  
   - 所有连接共享一个事件循环，借助 Nimble host task 轮询。  
   - 命令调度器按目标连接的 QoS/优先级分配写窗口，确保单个目标不会饥饿。  
   - 支持批量命令写入：若序列中的多个 `command_packet` 需要连续写入同一 PowerHub，则先在本地拼包以减少 ATT 事务。

## 6. 关键设计细节
- **双角色隔离**：Server (面向配置) 与 Client (面向执行) 在不同 Nimble host task 上运行，通过消息队列解耦，避免配置写入阻塞执行。  
- **MTU 策略**：  
  - Server 端同 PowerHub 模式一致，支持协商到 247 字节以提升 0xFFF3 分片效率。  
  - Client 端连接 PowerHub 时也请求 247 字节，以便发送多命令组合帧。  
- **错误处理**：  
  - 配置写入阶段若分片顺序或长度异常，返回 `BLE_ATT_ERR_UNLIKELY` 并弃用缓存。  
  - 命令调度失败时更新状态标志位（0xFFF2 bit0=失败），并在逻辑执行器中触发回滚或告警。  
  - 连接超时或 MTU 协商失败会触发重连策略，超过阈值将暂停目标并向客户端报告。
- **扩展性**：  
  - JSON `schema_version` 控制兼容，允许未来新增字段（如条件节点扩展、新 UI 插槽）。  
  - 连接管理器预留钩子，可加入非 PowerHub 设备，只要提供适配器将命令转换为目标协议。

## 7. 测试与验证
1. **单连接回归**：验证 SwitchHub 与单个 PowerHub 的通道控制、监控订阅、阈值指令与 PowerHub 规范一致。  
2. **多连接压力**：在 N=4/6/8 目标下循环执行 On/Off 序列，确认无连接丢失与命令错序。  
3. **配置完整性**：针对 0xFFF3 分片写入执行断点续传、分片缺失、重复写入等场景。  
4. **状态一致性**：验证 `status_slots` 映射的电压/通道状态与 PowerHub 端通知一致。  
5. **容错**：模拟目标断电/超时，确保命令调度器能重试或标记失败并继续执行其他目标。

## 8. 交付物
- `SWITCHHUB_BLE.md`：协议规范（已存在）。  
- `POWERHUB_BLE.md`：目标设备协议（已存在）。  
- 本文档：功能设计，指导 BLE 模块实现双角色与多目标控制。  
- 后续实现需在 Nimble Host 层新增多连接管理与脚本执行模块，并配套单元/集成测试用例。
