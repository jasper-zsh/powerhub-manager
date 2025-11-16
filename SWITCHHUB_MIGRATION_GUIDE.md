# SwitchHub Migration Guide

## 1. Overview

This guide helps users migrate from the current local orchestration system to the new SwitchHub-based centralized control system. The migration preserves existing configurations while enabling enhanced multi-device coordination.

## 2. Understanding the Change

### 2.1 Current System (Local Orchestration)
- **Control Method**: App directly controls individual PowerHub devices
- **Logic Execution**: Runs on the mobile app
- **Limitations**: Single device control, app must be active
- **Data Storage**: Local JSON files on device

### 2.2 New System (SwitchHub Orchestration)
- **Control Method**: App configures SwitchHub, which controls multiple PowerHubs
- **Logic Execution**: Runs on SwitchHub device
- **Advantages**: Multi-device coordination, standalone operation
- **Data Storage**: JSON stored on SwitchHub device

## 3. Migration Prerequisites

### 3.1 Hardware Requirements
- **SwitchHub Device**: ESP32-based orchestrator device
- **PowerHub Devices**: Existing devices remain compatible
- **Mobile App**: Updated version with SwitchHub support

### 3.2 Software Requirements
- **App Version**: v2.0+ with SwitchHub support
- **SwitchHub Firmware**: v0.5+ (supports full orchestration protocol)
- **PowerHub Firmware**: v1.6+ (compatible with SwitchHub control)

## 4. Migration Process

### 4.1 Preparation Phase

#### Step 1: Backup Current Configuration
1. Open PowerHub Manager app
2. Navigate to Orchestration screen
3. Export all scenes using "Export Configuration" option
4. Save backup file to cloud storage or computer

#### Step 2: Identify PowerHub Devices
1. Go to Device Management screen
2. Note all PowerHub MAC addresses
3. Document current device aliases and configurations
4. Test connectivity to all devices

#### Step 3: Setup SwitchHub Hardware
1. Power on SwitchHub device
2. Ensure SwitchHub is in setup mode (LED indicator)
3. Verify SwitchHub appears in device scan
4. Connect to SwitchHub and verify firmware version

### 4.2 Data Migration Phase

#### Step 4: Convert Orchestration Data
The migration wizard will automatically convert:

**Toggle Scenes → SwitchHub Switches**
```
Current ToggleScene:
{
  "id": "scene-1",
  "name": "Living Room",
  "states": [
    {
      "toggleId": "toggle-1",
      "stateId": "on",
      "label": "Lights On",
      "commandBundles": [...]
    }
  ]
}

Becomes SwitchHub Switch:
{
  "switch_id": 1,
  "revision": 1,
  "on": {
    "type": "leaf",
    "sequence": [...]
  },
  "off": {
    "type": "leaf", 
    "sequence": [...]
  },
  "ui": {
    "channel_label": "Living Room",
    "on_label": "Lights On",
    "off_label": "Lights Off"
  }
}
```

**Command Actions → PowerHub Command Packets**
```
Current CommandAction:
{
  "controllerId": "powerhub-1",
  "type": "channelValue",
  "channel": 2,
  "value": 255
}

Becomes PowerHub Command Packet:
{
  "target_mac": "AA:BB:CC:DD:EE:FF",
  "command_packets": [
    {
      "mode": 0,
      "channel": 2,
      "payload": "/w==",  // base64 encoded value
      "retry": 1
    }
  ]
}
```

#### Step 5: Map Device Addresses
The migration wizard will:
1. Scan for available PowerHub devices
2. Match current controller IDs with MAC addresses
3. Create mapping table for device association
4. Allow manual correction if needed

#### Step 6: Handle Complex Logic
**IFTTT Logic Conversion:**
```
Current ConditionalRule:
{
  "id": "rule-1",
  "toggleId": "toggle-1",
  "expectedStateId": "on",
  "trueBundleId": "bundle-on",
  "falseBundleId": "bundle-off"
}

Becomes SwitchHub IF Node:
{
  "type": "if",
  "condition": "SW1.ON",
  "then": {
    "type": "leaf",
    "sequence": [...bundle-on commands...]
  },
  "else": {
    "type": "leaf", 
    "sequence": [...bundle-off commands...]
  }
}
```

### 4.3 Validation Phase

#### Step 7: Test Migration Results
1. **Connect SwitchHub** to all identified PowerHub devices
2. **Upload converted orchestration** to SwitchHub
3. **Verify device connections** through SwitchHub status
4. **Test each switch** in the orchestration
5. **Validate command execution** on target PowerHubs

#### Step 8: Status Monitoring Setup
Configure status slots to display real-time data:
```
Status Slot Configuration:
{
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
```

### 4.4 Finalization Phase

#### Step 9: Switch to SwitchHub Mode
1. In app settings, select "SwitchHub Mode"
2. Disconnect from direct PowerHub connections
3. Connect to SwitchHub device
4. Verify orchestration functionality

#### Step 10: Clean Up
1. Archive old local orchestration files
2. Remove PowerHub devices from direct control (optional)
3. Update device aliases for clarity
4. Test full system functionality

## 5. Migration Tools

### 5.1 Automated Migration Wizard
The app provides a step-by-step migration wizard that:
- **Analyzes current configuration**
- **Identifies migration complexity**
- **Provides progress tracking**
- **Handles error recovery**
- **Validates results**

### 5.2 Manual Migration Options
For advanced users, manual migration tools include:
- **JSON converter utility**
- **Device mapping interface**
- **Logic editor for complex scenarios**
- **Batch configuration tools**

## 6. Troubleshooting

### 6.1 Common Issues

#### Issue: Device Not Found
**Cause**: PowerHub MAC address changed or device offline
**Solution**: 
1. Rescan for PowerHub devices
2. Update MAC address mapping
3. Ensure devices are powered and in range

#### Issue: Command Execution Fails
**Cause**: Command format incompatibility or connection issues
**Solution**:
1. Verify SwitchHub-PowerHub connectivity
2. Check command packet format
3. Review retry configuration
4. Test with simple commands first

#### Issue: Status Monitoring Not Working
**Cause**: Incorrect characteristic UUID or offset
**Solution**:
1. Verify PowerHub firmware version
2. Check characteristic UUID format
3. Validate offset and length parameters
4. Test with known working configuration

#### Issue: Complex Logic Not Executing
**Cause**: IFTTT expression syntax error
**Solution**:
1. Validate expression syntax
2. Test with simplified conditions
3. Check switch state references
4. Use logic validation tool

### 6.2 Recovery Procedures

#### Partial Migration Failure
1. **Identify failed components** from migration log
2. **Re-run migration** for specific items
3. **Manually configure** problematic items
4. **Validate system** before proceeding

#### Complete Migration Failure
1. **Restore from backup** created in Step 1
2. **Check system requirements** and compatibility
3. **Contact support** with error logs
4. **Consider staged migration** (simplify first, then add complexity)

## 7. Post-Migration Optimization

### 7.1 Performance Tuning
- **Optimize command sequences** for minimal latency
- **Adjust retry parameters** for reliability
- **Fine-tune status update intervals**
- **Balance SwitchHub connection load**

### 7.2 Advanced Features
- **Implement conditional logic** using IFTTT expressions
- **Set up status monitoring** for real-time feedback
- **Create device groups** for coordinated control
- **Configure automation schedules** if supported

### 7.3 Maintenance
- **Regular backup** of SwitchHub configuration
- **Monitor device health** and connectivity
- **Update firmware** for all devices
- **Review and optimize** orchestration logic

## 8. Rollback Procedure

If migration causes issues, rollback steps:

1. **Stop SwitchHub mode** in app settings
2. **Reconnect to PowerHub devices** directly
3. **Restore local configuration** from backup
4. **Verify functionality** in direct mode
5. **Contact support** if issues persist

## 9. Support Resources

### 9.1 Documentation
- **SwitchHub Protocol Specification**: SWITCHHUB_BLE.md
- **Integration Guide**: SWITCHHUB_FLUTTER_INTEGRATION.md
- **API Reference**: Available in app help section

### 9.2 Tools
- **Migration Wizard**: Built into app v2.0+
- **Configuration Validator**: Online tool available
- **Device Compatibility Checker**: Web-based utility

### 9.3 Community Support
- **Forums**: PowerHub community discussions
- **GitHub Issues**: Bug reports and feature requests
- **Discord Server**: Real-time chat support

## 10. Frequently Asked Questions

### Q: Will my existing PowerHub devices still work?
A: Yes, all existing PowerHub devices are fully compatible with SwitchHub control.

### Q: Can I use both systems simultaneously?
A: During migration, you can switch between modes, but it's recommended to fully migrate for best experience.

### Q: What happens to my existing presets?
A: Presets are converted to SwitchHub command sequences and preserved in the new configuration.

### Q: Is internet required for SwitchHub operation?
A: No, SwitchHub operates standalone once configured. Internet is only needed for initial setup and updates.

### Q: How many PowerHub devices can one SwitchHub control?
A: The theoretical limit is based on SwitchHub memory and BLE connection limits, typically 8-16 devices.

### Q: Can I migrate back to direct control?
A: Yes, you can rollback to direct PowerHub control at any time using the rollback procedure.

This migration guide ensures a smooth transition to SwitchHub while preserving all existing functionality and enabling new capabilities.