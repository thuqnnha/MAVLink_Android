import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';

class MavlinkUsbService {
  final _parser = MavlinkParser(MavlinkDialectCommon());
  UsbPort? _port;
  int _sequence = 0;

  Stream<MavlinkFrame> get frames => _parser.stream;

  static Future<List<UsbDevice>> availableDevices() => UsbSerial.listDevices();

  Future<bool> connect(UsbDevice device, int baudrate) async {
    _port = await device.create();
    if (_port == null) return false;
    if (!await _port!.open()) return false;

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(baudrate, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _port!.inputStream!.listen((data) => _parser.parse(data));
    return true;
  }

  /// Gửi tin nhắn chuẩn chỉ theo tài liệu: Wrap vào Frame v2 và Serialize
  void send(MavlinkMessage message, {int systemId = 255, int componentId = 0}) {
    if (_port == null) return;

    // Theo tài liệu: MavlinkFrame.v2(sequence, systemId, componentId, message)
    final frame = MavlinkFrame.v2(
      _sequence,
      systemId,
      componentId,
      message,
    );

    _sequence = (_sequence + 1) % 256;
    _port!.write(Uint8List.fromList(frame.serialize()));
  }

  void disconnect() {
    _port?.close();
    _port = null;
  }
}