import 'package:dart_mavlink/mavlink.dart';
import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'mavlink/mavlink_usb_service.dart';
import 'package:dart_mavlink/dialects/common.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: UsbMavlinkPage());
}

class UsbMavlinkPage extends StatefulWidget {
  const UsbMavlinkPage({super.key});
  @override
  State<UsbMavlinkPage> createState() => _UsbMavlinkPageState();
}

class _UsbMavlinkPageState extends State<UsbMavlinkPage> {
  final mavlink = MavlinkUsbService();
  List<UsbDevice> devices = [];
  UsbDevice? selected;
  
  // State variables
  String status = 'Disconnected';
  int heartbeatCount = 0;
  String armed = '-';
  double? voltage;
  double roll = 0, pitch = 0, yaw = 0;

  @override
  void initState() {
    super.initState();
    loadDevices();

    // Lắng nghe stream
    mavlink.frames.listen((MavlinkFrame frame) {
      MavlinkMessage message = frame.message;
      
      switch (message.runtimeType) {
        case Heartbeat:
          _handleHeartbeat(frame.systemId, frame.componentId, message as Heartbeat);
          break;
        case SysStatus:
          _handleSysStatus(message as SysStatus);
          break;
        case Attitude:
          _handleAttitude(message as Attitude);
          break;
        case Statustext:
          // Bạn có thể in thông báo từ FC ra console ở đây
          debugPrint("FC Status: ${(message as Statustext).text}");
          break;
        default:
          break;
      }
    });
  }

  // --- Các hàm xử lý tin nhắn riêng biệt (Modular logic) ---

  void _handleHeartbeat(int sysId, int compId, Heartbeat msg) {
    if (heartbeatCount == 0) {
      _requestDataStreams(sysId, compId);
    }
    heartbeatCount++;
    final isArmed = (msg.baseMode & mavModeFlagSafetyArmed) != 0;
    
    if (mounted) {
      setState(() {
        status = 'Connected (Sys:$sysId)';
        armed = isArmed ? 'ARMED' : 'DISARMED';
      });
    }
  }

  void _handleSysStatus(SysStatus msg) {
    if (msg.voltageBattery != 65535 && mounted) {
      setState(() => voltage = msg.voltageBattery / 1000.0);
    }
  }

  void _handleAttitude(Attitude msg) {
    if (mounted) {
      setState(() {
        roll = msg.roll * 57.2958; 
        pitch = msg.pitch * 57.2958;
        yaw = msg.yaw * 57.2958;
      });
    }
  }

  // --- Các hàm điều khiển ---

  void _requestDataStreams(int targetSys, int targetComp) {
    final request = RequestDataStream(
      targetSystem: targetSys,
      targetComponent: targetComp,
      reqStreamId: 0, // MAV_DATA_STREAM_ALL
      reqMessageRate: 10,
      startStop: 1,
    );
    mavlink.send(request);
  }

  Future<void> loadDevices() async {
    final list = await MavlinkUsbService.availableDevices();
    setState(() { devices = list; selected = null; });
  }

  Future<void> connect() async {
    if (selected == null) return;
    heartbeatCount = 0;
    final ok = await mavlink.connect(selected!, 115200);
    setState(() => status = ok ? 'Waiting heartbeat...' : 'Connect failed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MAVLink Android OTG')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButton<UsbDevice>(
              isExpanded: true,
              hint: const Text('Select USB device'),
              value: selected,
              items: devices.map((d) => DropdownMenuItem(value: d, child: Text('${d.productName}'))).toList(),
              onChanged: (v) => setState(() => selected = v),
            ),
            ElevatedButton(onPressed: connect, child: const Text('Connect FC')),
            const Divider(),
            _infoTile('Status', status),
            _infoTile('Heartbeats', heartbeatCount.toString()),
            _infoTile('Battery', '${voltage?.toStringAsFixed(2) ?? '-'} V'),
            _infoTile('Armed', armed),
            const Divider(),
            const Text('ATTITUDE', style: TextStyle(fontWeight: FontWeight.bold)),
            _infoTile('Roll', '${roll.toStringAsFixed(1)}°'),
            _infoTile('Pitch', '${pitch.toStringAsFixed(1)}°'),
            _infoTile('Yaw', '${yaw.toStringAsFixed(1)}°'),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }
}