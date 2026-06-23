import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class ModelViewer3D extends StatefulWidget {
  final String filePath;

  const ModelViewer3D({super.key, required this.filePath});

  @override
  State<ModelViewer3D> createState() => _ModelViewer3DState();
}

class _ModelViewer3DState extends State<ModelViewer3D>
    with SingleTickerProviderStateMixin {
  ObjModel? _model;
  String? _error;
  bool _loading = true;

  double _rotationX = 0;
  double _rotationY = 0;
  double _scale = 1.0;
  Offset? _lastFocalPoint;
  double _baseRotationX = 0;
  double _baseRotationY = 0;
  bool _autoRotate = true;
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _loadModel();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    if (_autoRotate && mounted) {
      setState(() => _rotationY += 0.005);
    }
  }

  Future<void> _loadModel() async {
    try {
      final file = File(widget.filePath);
      if (!file.existsSync()) {
        setState(() { _error = 'File not found'; _loading = false; });
        return;
      }

      final ext = widget.filePath.split('.').last.toLowerCase();
      if (ext == 'obj') {
        final content = await file.readAsString();
        _model = await Isolate.run(() => ObjModel.parse(content));
      } else if (ext == 'stl') {
        final bytes = await file.readAsBytes();
        _model = await Isolate.run(() => StlModel.parse(bytes));
      } else {
        setState(() { _error = 'Unsupported format: .$ext'; _loading = false; });
        return;
      }

      if (_model == null || _model!.vertices.isEmpty) {
        setState(() { _error = 'No valid geometry found'; _loading = false; });
        return;
      }

      _model!.normalize();
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null || _model == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_rounded, size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(_error ?? 'Unknown error', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            FilledButton.tonal(onPressed: _loadModel, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onScaleStart: (details) {
              _lastFocalPoint = details.focalPoint;
              _baseRotationX = _rotationX;
              _baseRotationY = _rotationY;
              _autoRotate = false;
            },
            onScaleEnd: (_) => _autoRotate = true,
            onScaleUpdate: (details) {
              setState(() {
                if (_lastFocalPoint != null) {
                  final dx = details.focalPoint.dx - _lastFocalPoint!.dx;
                  final dy = details.focalPoint.dy - _lastFocalPoint!.dy;
                  _rotationY = _baseRotationY + dx * 0.008;
                  _rotationX = (_baseRotationX + dy * 0.008)
                      .clamp(-pi / 2.5, pi / 2.5);
                }
                _scale = (_scale * details.scale).clamp(0.1, 10.0);
                _lastFocalPoint = details.focalPoint;
              });
            },
            child: CustomPaint(
              painter: _ObjPainter(
                model: _model!,
                rotationX: _rotationX,
                rotationY: _rotationY,
                scale: _scale,
                color: theme.colorScheme.primary,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.touch_app_rounded, size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Text('Drag to rotate · Pinch to zoom',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              const Spacer(),
              Text('${_model!.vertices.length} verts · ${_model!.faces.length} faces',
                  style: theme.textTheme.bodySmall),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.restart_alt_rounded),
                onPressed: () {
                  setState(() { _rotationX = 0; _rotationY = 0; _scale = 1.0; _autoRotate = true; });
                },
                tooltip: 'Reset view',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Real OBJ file parser
class ObjModel {
  final List<vm.Vector3> vertices;
  final List<List<int>> faces;
  final List<vm.Vector3> normals;

  ObjModel({required this.vertices, required this.faces, required this.normals});

  factory ObjModel.parse(String content) {
    final verts = <vm.Vector3>[];
    final norms = <vm.Vector3>[];
    final faces = <List<int>>[];

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.isEmpty) continue;

      switch (parts[0]) {
        case 'v':
          if (parts.length >= 4) {
            verts.add(vm.Vector3(
              double.tryParse(parts[1]) ?? 0,
              double.tryParse(parts[2]) ?? 0,
              double.tryParse(parts[3]) ?? 0,
            ));
          }
          break;
        case 'vn':
          if (parts.length >= 4) {
            norms.add(vm.Vector3(
              double.tryParse(parts[1]) ?? 0,
              double.tryParse(parts[2]) ?? 0,
              double.tryParse(parts[3]) ?? 0,
            ));
          }
          break;
        case 'f':
          if (parts.length >= 4) {
            final face = <int>[];
            for (var i = 1; i < parts.length; i++) {
              final idx = parts[i].split('/').first;
              final vi = (int.tryParse(idx) ?? 1) - 1;
              if (vi >= 0 && vi < verts.length) {
                face.add(vi);
              }
            }
            if (face.length >= 3) faces.add(face);
          }
          break;
      }
    }

    return ObjModel(vertices: verts, faces: faces, normals: norms);
  }

  void normalize() {
    if (vertices.isEmpty) return;

    final center = vm.Vector3(0, 0, 0);
    for (final v in vertices) { center.add(v); }
    center.scale(1.0 / vertices.length);

    double maxDist = 0;
    for (final v in vertices) {
      final d = (v - center).length;
      if (d > maxDist) maxDist = d;
    }

    final s = maxDist > 0 ? 1.0 / maxDist : 1.0;
    for (final v in vertices) {
      v.sub(center);
      v.scale(s);
    }
  }
}

/// Real STL (binary) file parser
class StlModel {
  static ObjModel parse(Uint8List bytes) {
    final verts = <vm.Vector3>[];
    final faces = <List<int>>[];
    int offset = 80;

    if (bytes.length < 84) return ObjModel(vertices: verts, faces: faces, normals: []);

    final triangleCount = ByteData.sublistView(bytes, 80, 84).getUint32(0, Endian.little);

    for (int i = 0; i < triangleCount && offset + 50 <= bytes.length; i++) {
      offset += 12;
      for (int j = 0; j < 3; j++) {
        final x = ByteData.sublistView(bytes, offset, offset + 4).getFloat32(0, Endian.little);
        final y = ByteData.sublistView(bytes, offset + 4, offset + 8).getFloat32(0, Endian.little);
        final z = ByteData.sublistView(bytes, offset + 8, offset + 12).getFloat32(0, Endian.little);
        verts.add(vm.Vector3(x, y, z));
        offset += 12;
      }
      faces.add([i * 3, i * 3 + 1, i * 3 + 2]);
      offset += 2;
    }

    return ObjModel(vertices: verts, faces: faces, normals: []);
  }
}

class _ObjPainter extends CustomPainter {
  final ObjModel model;
  final double rotationX;
  final double rotationY;
  final double scale;
  final Color color;

  _ObjPainter({
    required this.model,
    required this.rotationX,
    required this.rotationY,
    required this.scale,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (model.vertices.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final s = min(size.width, size.height) * 0.4 * scale;

    final rx = vm.Matrix4.rotationX(rotationX);
    final ry = vm.Matrix4.rotationY(rotationY);
    final transform = rx.multiplied(ry);

    final projected = <_ProjectedVert>[];
    for (int i = 0; i < model.vertices.length; i++) {
      final v = model.vertices[i];
      final t = transform.transform3(v);
      final depth = 2.0 - t.z * 0.5;
      final perspective = depth > 0 ? 1.0 / depth : 1.0;
      final x = center.dx + t.x * s * perspective;
      final y = center.dy + t.y * s * perspective;
      projected.add(_ProjectedVert(Offset(x, y), t.z));
    }

    final facePaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final edgePaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final sortedFaces = List.generate(model.faces.length, (i) {
      final face = model.faces[i];
      double zSum = 0;
      for (final vi in face) {
        if (vi < projected.length) zSum += projected[vi].z;
      }
      return MapEntry(i, zSum / face.length);
    });
    sortedFaces.sort((a, b) => b.value.compareTo(a.value));

    for (final sf in sortedFaces) {
      final face = model.faces[sf.key];
      if (face.length < 3) continue;

      final path = Path();
      path.moveTo(projected[face[0]].pos.dx, projected[face[0]].pos.dy);
      for (var j = 1; j < face.length; j++) {
        path.lineTo(projected[face[j]].pos.dx, projected[face[j]].pos.dy);
      }
      path.close();
      canvas.drawPath(path, facePaint);

      for (var j = 0; j < face.length; j++) {
        canvas.drawLine(
          projected[face[j]].pos,
          projected[face[(j + 1) % face.length]].pos,
          edgePaint,
        );
      }
    }

    if (projected.length < 200) {
      final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
      for (final p in projected) { canvas.drawCircle(p.pos, 2, dotPaint); }
    }

    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 0.5;

    final floorY = center.dy + s * 0.9;
    for (var i = -5; i <= 5; i++) {
      canvas.drawLine(
        Offset(center.dx + i * 25.0 * scale, floorY),
        Offset(center.dx + i * 25.0 * scale, floorY + 30 * scale),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ObjPainter old) =>
      old.rotationX != rotationX ||
      old.rotationY != rotationY ||
      old.scale != scale;
}

class _ProjectedVert {
  final Offset pos;
  final double z;
  _ProjectedVert(this.pos, this.z);
}
