# SwitchHub BLE 控制协议文档

## 概述

本文档定义SwitchHub设备的蓝牙低功耗 (BLE) 控制协议。协议基于Apache Nimble BLE栈，保留PowerHub方案的电源管理能力，同时提供开关逻辑编排接口。本设备没有输出通道、温度传感器或电流传感器，因此仅暴露与输入电压和逻辑编排相关的特征。

## 基础架构

- **蓝牙栈**: Apache Nimble BLE
- **设备名称**: "SwitchHub"
- **服务UUID**: `119B5F1B-1C7A-3E8E-6147-672F-0200-0B5E`
- **连接模式**: 单连接
- **广播配置**: 可发现、不可连接广播 (同PowerHub)

## GATT 服务定义

SwitchHub提供三个核心特征：

1. 电源管理特征 (0xFFF1)
2. 实时监控特征 (0xFFF2)
3. 开关逻辑编排特征 (0xFFF3)

### 1. 电源管理特征 (UUID: 0xFFF1)

SwitchHub仅支持电压阈值管理。

**读取数据结构**

| 偏移 | 长度 | 类型   | 描述                    |
|------|------|--------|-------------------------|
| 0    | 2    | uint16 | 睡眠电压阈值 (mV)       |
| 2    | 2    | uint16 | 唤醒电压阈值 (mV)       |

**写入命令**

- 命令格式 `[命令(1B)][参数(2B)]`
- 支持命令：0x01/0x02 (电压阈值设置)、0x03 (强制睡眠)、0x04 (强制唤醒)
- 非温度设备，收到0x11/0x12命令时返回 `BLE_ATT_ERR_REQ_NOT_SUPPORTED`

### 2. 实时监控特征 (UUID: 0xFFF2)

- **属性**: 读取 + 通知
- **数据格式**: 4字节

| 偏移 | 长度 | 类型   | 描述                            |
|------|------|--------|---------------------------------|
| 0    | 2    | uint16 | 输入电压 (mV)                  |
| 2    | 1    | uint8  | 系统状态标志，bit1=0表示无温度 |
| 3    | 1    | uint8  | 预留                            |

### 3. 开关逻辑编排特征 (UUID: 0xFFF3)

- **属性**: 读/写 + 无响应写
- **描述**: 读取或写入全局开关逻辑编排数据，例如多设备联动策略或预定义脚本
- **状态读取**: 返回单一JSON文件，包含全部开关的配置、指令序列和UI定义
- **写入操作**: 以“整份JSON编排文件”作为基本单位，通过分片传输机制写入，详见3.6
- **注意**: 逻辑结果不直接驱动本设备输出，而是同步到上层系统作进一步处理

#### 3.1 多设备控制

- 单个开关可关联多个目标设备，每个设备通过其BLE MAC地址（6字节）唯一标识
- 所有指令序列均使用 `POWERHUB_BLE.md` 中“通道控制特征 (0xFFF1)”定义的命令格式，SwitchHub负责把这些命令透传到目标PowerHub
- 指令序列数据结构：
  ```
  {
    "target_mac": "AA:BB:CC:DD:EE:FF",
    "command_packets": [
      {
        "mode": 0x01,
        "channel": 0x00,
        "payload": "..." // 二进制，遵循PowerHub通道控制协议
      },
      ...
    ]
  }
  ```
- `command_packets` 数组中的每个元素对应PowerHub的一条通道控制写命令；SwitchHub按序将命令组合成单次写入或多次写入目标设备的0xFFF1
- 同一开关可以包含多个目标对象条目，实现“一键多控”

#### 3.2 开/关状态指令

- 每个开关维护 On/Off 两套独立序列；每套序列是若干 `command_packets` 列表
- 状态切换至目标状态时立即顺序执行序列中的 PowerHub 通道控制命令，避免重复执行
- 支持为整个序列或单个命令设置延迟/重试参数，如 `{ "delay_ms": 200, "retry": 1 }`

#### 3.3 IFTTT 逻辑

- On 与 Off 状态直接维护一棵逻辑树，树节点支持 `IF`/`ELSE` 结构，可任意嵌套
- `IF` 节点包含布尔表达式和两个子节点：`then` (条件成立) 与 `else` (条件不成立)
- 叶子节点表示要执行的指令序列；当遍历到叶子节点时执行其中的 `command_packets`
- 布尔表达式支持多个开关状态组合，提供 `AND`、`OR`、`NOT` 以及小括号`()`优先级，示例：`(SW1.ON AND NOT SW2.OFF) OR SW3.ON`
- 若 `else` 为空则条件不满足时不执行任何命令；通过嵌套 `IF` 节点实现多层判断

#### 3.4 UI 分区定义

每个开关在触控屏或App中拥有四个可配置区域：
1. **通道标签区**：显示开关名称或编号
2. **开标签区**：展示开状态描述，可自定义文字/图标
3. **关标签区**：展示关状态描述，可自定义文字/图标
4. **状态区域**：实时显示监控数据，可绑定最多两个来自指定设备/特征的数值

- 状态区域数据源通过`target_mac + characteristic_uuid + offset/length`指定
- 若未配置数据源，状态区域保持空白或显示自定义静态文本
- UI 配置随开关逻辑一并写入0xFFF3，客户端读取后渲染

#### 3.5 数据结构规范

所有开关的编排内容必须存储在统一的JSON对象中，可选字段如下：

| 字段 | 类型 | 说明 |
|------|------|------|
| `schema_version` | uint16 | JSON结构版本 |
| `switches` | 数组 | 每个元素一个开关定义 |
| `metadata` | 对象 | 可选扩展字段，如创建者、时间戳 |

每个 `switches[i]` 对象包含：

| 字段 | 类型 | 说明 |
|------|------|------|
| `switch_id` | uint16 | 本地开关编号 |
| `revision` | uint16 | 逻辑版本号 |
| `on` / `off` | 对象 | 直接描述逻辑树根节点 |
| `ui` | 对象 | UI 分区配置

`on`/`off` 对象即为逻辑树根节点，可分为两种类型：

1. **IF 节点**
   | 字段 | 类型 | 说明 |
   |------|------|------|
   | `type` | 字符串 | 固定为`"if"` |
   | `condition` | 字符串 | 布尔表达式 |
   | `then` | 对象 | 子节点 (logic) |
   | `else` | 对象/Null | 子节点，缺省表示不执行 |

2. **叶子节点**
   | 字段 | 类型 | 说明 |
   |------|------|------|
   | `type` | 字符串 | 固定为`"leaf"` |
   | `sequence` | 数组 | 由若干 `sequence_item` 组成 |

`sequence_item` 字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `target_mac` | 字符串 | 目标PowerHub MAC，格式`AA:BB:...` |
| `command_packets` | 数组 | PowerHub 通道控制命令列表 |
| `delay_ms` | uint16 | 可选，执行前延迟 |

`command_packet` 字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `mode` | uint8 | PowerHub命令模式 |
| `channel` | uint8 | PowerHub通道索引 |
| `payload` | base64字符串 | 参数序列的二进制编码 |
| `retry` | uint8 | 可选，失败重试次数 |

`ui` 对象字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `channel_label` | 字符串 | 通道标签内容 |
| `on_label` | 字符串 | 开状态标签 |
| `off_label` | 字符串 | 关状态标签 |
| `status_slots` | 数组 | 最多两个 `status_slot` |

`status_slot` 字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `source_mac` | 字符串 | 数据来源设备 |
| `characteristic_uuid` | 字符串 | 读取的特征 UUID |
| `offset` | uint8 | 数据偏移 |
| `length` | uint8 | 数据长度 |
| `format` | 字符串 | `u16`/`s16`/`float`等解析方式 |

示例JSON（仅展示部分结构）：

```json
{
  "schema_version": 1,
  "switches": [
    {
      "switch_id": 1,
      "revision": 12,
      "on": {
        "type": "if",
        "condition": "(SW1.ON AND NOT SW2.OFF)",
        "then": {
          "type": "leaf",
          "sequence": [
            {
              "target_mac": "AA:BB:CC:DD:EE:FF",
              "command_packets": [
                {"mode": 1, "channel": 0, "payload": "AQID", "retry": 1}
              ]
            }
          ]
        },
        "else": {
          "type": "leaf",
          "sequence": []
        }
      },
      "off": {
        "type": "leaf",
        "sequence": []
      },
      "ui": {
        "channel_label": "客厅场景",
        "on_label": "一键开启",
        "off_label": "全部关闭",
        "status_slots": [
          {
            "source_mac": "AA:BB:CC:DD:EE:FF",
            "characteristic_uuid": "0xFFF2",
            "offset": 0,
            "length": 2,
            "format": "u16"
          }
        ]
      }
    }
  ]
}
```

#### 3.6 大文件传输机制

- **分片写入**: 0xFFF3特征期望接收 `[chunk_seq(2B)][total_chunks(2B)][payload...]` 格式，每个payload承载JSON文件的连续字节流
- **校验**: 最后一片写完后客户端需再写入一个CRC32校验命令，设备验证成功后替换现有配置
- **恢复**: 如果任意分片丢失或校验失败，设备返回错误并丢弃整个会话，客户端可重新发送全部分片
- **读取**: 
  1. 首先读取0xFFF3以获取`metadata`（JSON头部，<= MTU），其中包含`total_size`、`chunk_size`和`crc32`
  2. 客户端根据`total_size`循环执行ATT Read Blob（带Offset）或`Read` + Offset控制命令，每次最多读取`chunk_size`字节
  3. 收集完全部字节后计算CRC32并与`crc32`字段比对，确认完整性


## 温度相关限制

- 设备无温度/电流传感器，请勿依赖相关数据
- 向设备写入温度阈值命令会返回错误
- 仅处理输入电压与逻辑脚本内容

## 开发注意事项

- **服务发现**: 使用新的服务UUID `119B5F1B-1C7A-3E8E-6147-672F-0200-0B5E`
- **订阅策略**: 需要电压/状态数据时订阅0xFFF2；0xFFF1用于配置读取，0xFFF3当前无通知能力
- **向后兼容**: 客户端需根据特征UUID变更更新句柄映射
- **扩展预留**: 监控与逻辑Payload均为未来版本预留，建议容错处理

## 版本记录

- **v0.5**: 完善开关逻辑编排，支持多设备序列、On/Off组合、IFTTT表达式与UI分区
- **v0.4**: 移除电流监测字段，实时监控仅保留电压与状态
- **v0.3**: 移除所有占位字段，仅保留实际测量与逻辑数据
- **v0.2**: 移除通道特征，更新服务及特征UUID
- **v0.1**: 初版协议，复用PowerHub电源与通道特征，新增开关逻辑编排占位
