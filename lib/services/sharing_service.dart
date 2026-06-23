import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../models/file_item.dart';

class SharingService {
  static const _port = 9876;
  HttpServer? _server;
  bool _isRunning = false;

  Future<String> generateShareData(FileItem file) async {
    final info = {
      'name': file.name,
      'size': file.size,
      'ext': file.extension,
      'host': await _getLocalIp(),
      'port': _port,
    };
    return base64Encode(utf8.encode(jsonEncode(info)));
  }

  Future<FileItem?> parseShareData(String data) async {
    try {
      final decoded = utf8.decode(base64Decode(data));
      final info = jsonDecode(decoded) as Map<String, dynamic>;
      return FileItem(
        name: info['name'] as String,
        path: info['name'] as String,
        extension: info['ext'] as String,
        size: info['size'] as int,
      );
    } catch (_) {
      return null;
    }
  }

  /// Start HTTP file server on a background isolate
  Future<void> startServer(String filePath) async {
    if (_isRunning) await stopServer();

    final file = File(filePath);
    final fileName = p.basename(filePath);
    final fileBytes = await file.readAsBytes();

    _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
    _isRunning = true;

    await for (final request in _server!) {
      if (request.uri.path == '/$fileName') {
        request.response.headers.contentType = ContentType('application', 'octet-stream');
        request.response.headers.add('Content-Disposition', 'attachment; filename="$fileName"');
        request.response.contentLength = fileBytes.length;
        request.response.add(fileBytes);
        await request.response.close();
      } else if (request.uri.path == '/') {
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
          <html><body>
          <h2>CRAFT File Share</h2>
          <p>Sharing: <strong>$fileName</strong> (${_fmtSize(fileBytes.length)})</p>
          <p><a href="/$fileName" download>Download File</a></p>
          </body></html>
        ''');
        await request.response.close();
      } else {
        request.response.statusCode = 404;
        await request.response.close();
      }
    }
  }

  Future<void> stopServer() async {
    await _server?.close();
    _server = null;
    _isRunning = false;
  }

  Future<List<Map<String, String>>> discoverNearbyDevices() async {
    final devices = <Map<String, String>>[];
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
      socket.broadcastEnabled = true;

      socket.send(
        utf8.encode('CRAFT_DISCOVER'),
        InternetAddress('255.255.255.255'),
        _port,
      );

      await for (final event in socket) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final msg = utf8.decode(datagram.data);
            if (msg.startsWith('CRAFT_RESPONSE:')) {
              final parts = msg.split(':');
              if (parts.length >= 3) {
                devices.add({
                  'name': parts[1],
                  'ip': datagram.address.address,
                  'port': parts[2],
                });
              }
            }
          }
        }
        if (event == RawSocketEvent.closed) break;
      }
      socket.close();
    } catch (_) {}
    return devices;
  }

  /// Download file from remote device via HTTP
  Future<String> downloadFromDevice({
    required String host,
    required String fileName,
    required String saveDir,
  }) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('http://$host:$_port/$fileName'));
      final response = await request.close();

      if (response.statusCode != 200) {
        client.close();
        return 'Error: Server returned ${response.statusCode}';
      }

      final chunks = <List<int>>[];
      await for (final chunk in response) {
        chunks.add(chunk);
      }

      int totalLength = 0;
      for (final chunk in chunks) {
        totalLength += chunk.length;
      }
      final bytes = Uint8List(totalLength);
      int offset = 0;
      for (final chunk in chunks) {
        bytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      final savePath = p.join(saveDir, fileName);
      await File(savePath).writeAsBytes(bytes);
      client.close();
      return 'Downloaded to $savePath (${_fmtSize(bytes.length)})';
    } catch (e) {
      return 'Download failed: $e';
    }
  }

  Future<void> sendFile(FileItem file, FileItem recipient) async {
    await startServer(file.path);
  }

  Future<void> copyToClipboard(FileItem file) async {
    await Clipboard.setData(ClipboardData(text: file.path));
  }

  static Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
