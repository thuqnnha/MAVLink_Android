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
  int baudrate = 115200;

  String status = 'Disconnected';
  int heartbeatCount = 0;
  String armed = '-';
  double? voltage;
  
  // Biến hiển thị Attitude
  double roll = 0, pitch = 0, yaw = 0;

  @override
  void initState() {
    super.initState();
    loadDevices();

    mavlink.frames.listen((frame) {
      final msg = frame.message;

      // 1. Xử lý Heartbeat & Gửi Request Data Stream
      if (msg is Heartbeat) {
        if (heartbeatCount == 0) {
          // Lần đầu thấy FC, gửi yêu cầu dữ liệu ngay
          _requestDataStreams(frame.systemId, frame.componentId);
        }
        heartbeatCount++;
        final isArmed = (msg.baseMode & mavModeFlagSafetyArmed) != 0;
        setState(() {
          status = 'Connected';
          armed = isArmed ? 'ARMED' : 'DISARMED';
        });
      }

      // 2. Xử lý dữ liệu Pin
      if (msg is SysStatus && msg.voltageBattery != 65535) {
        setState(() => voltage = msg.voltageBattery / 1000.0);
      }

      // 3. Xử lý dữ liệu Attitude (ĐÂY LÀ PHẦN BẠN CẦN)
      if (msg is Attitude) {
        setState(() {
          roll = msg.roll * 57.2958;  // Rad to Deg
          pitch = msg.pitch * 57.2958;
          yaw = msg.yaw * 57.2958;
        });
      }
    });
  }

  // Hàm gửi yêu cầu FC phát dữ liệu
  void _requestDataStreams(int targetSys, int targetComp) {
    // Yêu cầu tất cả các luồng dữ liệu phổ biến (bao gồm attitude)
    final request = RequestDataStream(
      targetSystem: targetSys,
      targetComponent: targetComp,
      reqStreamId: 0, // 0 = MAV_DATA_STREAM_ALL
      reqMessageRate: 10, // 10 Hz
      startStop: 1, // 1 = Start
    );
    mavlink.send(request);
    print("Sent RequestDataStream to $targetSys:$targetComp");
  }

  Future<void> loadDevices() async {
    final list = await MavlinkUsbService.availableDevices();
    setState(() { devices = list; selected = null; });
  }

  Future<void> connect() async {
    if (selected == null) return;
    heartbeatCount = 0; // Reset để gửi lại request khi kết nối mới
    final ok = await mavlink.connect(selected!, baudrate);
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
              items: devices.map((d) => DropdownMenuItem(
                value: d, 
                child: Text('${d.productName}'),
              )).toList(),
              onChanged: (v) => setState(() => selected = v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: connect, child: const Text('Connect')),
                ElevatedButton(onPressed: loadDevices, child: const Text('Refresh')),
              ],
            ),
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