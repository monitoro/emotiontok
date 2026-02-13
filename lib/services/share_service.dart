import 'dart:io';

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  static Future<void> captureAndShare(GlobalKey key) async {
    try {
      // 1. Capture the widget
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        debugPrint("ShareService: Boundary is null");
        return;
      }

      // High pixel ratio for better quality
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // 2. Save to temporary file
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/burn_it_share_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(pngBytes);

      // 3. Share
      await Share.shareXFiles([XFile(path)], text: '오늘의 감정 영수증 #BurnIt');
    } catch (e) {
      debugPrint("Error sharing: $e");
    }
  }
}
