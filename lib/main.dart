import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'mavlink/mavlink_usb_service.dart';
import 'package:dart_mavlink/dialects/common.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: UsbMavlinkPage());
  }
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
  int heartbeat = 0;
  String armed = '-';
  double? voltage;

  @override
  void initState() {
    super.initState();
    loadDevices();

    mavlink.frames.listen((frame) {
      final msg = frame.message;

      if (msg is Heartbeat) {
        heartbeat++;
        final isArmed =
            (msg.baseMode & mavModeFlagSafetyArmed) != 0;

        setState(() {
          status = 'Connected';
          armed = isArmed ? 'ARMED' : 'DISARMED';
        });
      }

      if (msg is SysStatus && msg.voltageBattery != 65535) {
        setState(() {
          voltage = msg.voltageBattery / 1000.0;
        });
      }
    });
  }

  Future<void> loadDevices() async {
  final list = await MavlinkUsbService.availableDevices();
    setState(() {
      devices = list;
      selected = null;
    });
  }

  Future<void> connect() async {
    if (selected == null) return;
    final ok = await mavlink.connect(selected!, baudrate);
    setState(() {
      status = ok ? 'Waiting heartbeat...' : 'Connect failed';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MAVLink USB OTG')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButton<UsbDevice>(
              isExpanded: true,
              hint: const Text('Select USB device'),
              value: selected,
              items: devices.isEmpty
                  ? null
                  : devices.map((d) {
                      return DropdownMenuItem(
                        value: d,
                        child: Text(
                          '${d.manufacturerName ?? 'Unknown'} '
                          '${d.productName ?? ''}',
                        ),
                      );
                    }).toList(),
              onChanged: devices.isEmpty
                  ? null
                  : (v) => setState(() => selected = v),
            ),

            ElevatedButton(
              onPressed: connect,
              child: const Text('Connect FC'),
            ),
            ElevatedButton(
              onPressed: loadDevices,
             child: const Text('Refresh USB'),
            ),
            const Divider(),
            Text('Status: $status'),
            Text('Heartbeat: $heartbeat'),
            Text('Armed: $armed'),
            Text('Battery: ${voltage?.toStringAsFixed(2) ?? '-'} V'),
          ],
        ),
      ),
    );
  }
}
