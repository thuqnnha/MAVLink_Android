import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';

class MavlinkUsbService {
  final _parser = MavlinkParser(MavlinkDialectCommon());
  UsbPort? _port;
  int _sequence = 0; // Quan trọng: Sequence phải tăng dần sau mỗi tin nhắn gửi đi

  Stream<MavlinkFrame> get frames => _parser.stream;

  static Future<List<UsbDevice>> availableDevices() {
    return UsbSerial.listDevices();
  }

  Future<bool> connect(UsbDevice device, int baudrate) async {
    _port = await device.create();
    if (_port == null) return false;

    final opened = await _port!.open();
    if (!opened) return false;

    await _port!.setDTR(true);
    await _port!.setRTS(true);

    await _port!.setPortParameters(
      baudrate,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    _port!.inputStream!.listen((Uint8List data) {
      _parser.parse(data);
    });

    return true;
  }

  /// Hàm gửi tin nhắn MAVLink từ App xuống FC
  void send(MavlinkMessage message, {int systemId = 255, int componentId = 0}) {
    if (_port == null) return;

    // Sử dụng lớp MavlinkFrame để tạo gói tin (mặc định là v2 trong các bản mới)
    final frame = MavlinkFrame.v2(
      _sequence,
      systemId,
      componentId,
      message,
    );

    _sequence = (_sequence + 1) % 256; // Tăng sequence và reset nếu vượt quá 255
    _port!.write(Uint8List.fromList(frame.serialize()));
  }

  void disconnect() {
    _port?.close();
    _port = null;
  }
}