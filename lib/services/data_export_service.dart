import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import '../viewmodels/venting_viewmodel.dart';

class DataExportService {
  Future<void> exportData(List<PrivatePost> posts) async {
    // 1. Convert posts to List<List<dynamic>> for CSV
    List<List<dynamic>> rows = [];

    // Header
    rows.add(
        ["Date", "Time", "Anger Level (%)", "Content", "AI Response", "Tags"]);

    // Data
    for (var post in posts) {
      rows.add([
        DateFormat('yyyy-MM-dd').format(post.timestamp),
        DateFormat('HH:mm:ss').format(post.timestamp),
        post.angerLevel.toInt(),
        post.content,
        post.aiResponse ?? "",
        post.tags.join(", ")
      ]);
    }

    // 2. Generate CSV String
    String csvData = const ListToCsvConverter().convert(rows);

    // 3. Save to temporary file
    final directory = await getTemporaryDirectory();
    final String path =
        '${directory.path}/emotiontok_backup_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    final File file = File(path);
    await file.writeAsString(csvData, flush: true);

    // 4. Share file
    await Share.shareXFiles([XFile(path)], text: 'EmotionTok 감정 기록 백업');
  }
}
