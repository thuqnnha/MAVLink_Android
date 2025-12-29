import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';

class MavlinkUsbService {
  final _parser = MavlinkParser(MavlinkDialectCommon());

  UsbPort? _port;
  Stream<MavlinkFrame> get frames => _parser.stream;

  /// Lấy danh sách thiết bị USB
  static Future<List<UsbDevice>> availableDevices() {
    return UsbSerial.listDevices();
  }

  /// Kết nối FC qua USB OTG
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

  void disconnect() {
    _port?.close();
  }
}
