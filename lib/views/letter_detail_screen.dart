import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/letter_model.dart';
import 'package:intl/intl.dart';

class LetterDetailScreen extends StatefulWidget {
  final Letter letter;

  const LetterDetailScreen({super.key, required this.letter});

  @override
  State<LetterDetailScreen> createState() => _LetterDetailScreenState();
}

class _LetterDetailScreenState extends State<LetterDetailScreen> {
  bool _isSaving = false;
  final GlobalKey _repaintKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  // Parsed content
  String _cleanContent = '';
  String _sentimentText = '';
  String _momentumText = '';

  @override
  void initState() {
    super.initState();
    _parseContent();
  }

  void _parseContent() {
    String content = widget.letter.content;
    String cleanContent = content;
    String sentimentText = '';
    String momentumText = '';

    final List<String> lines = content.split('\n');
    final List<String> bodyLines = [];
    bool foundBoard = false;

    for (var line in lines) {
      if (line.contains('🎯') && line.contains('초점')) {
        foundBoard = true;
        final parts = line.split('|');
        for (var part in parts) {
          if (part.contains('정서')) {
            final subParts = part.split(':');
            if (subParts.length > 1) sentimentText = subParts[1].trim();
          }
        }
        continue;
      }
      if (foundBoard && (line.contains('⚙️') || line.contains('🔄'))) {
        final parts = line.split('|');
        for (var part in parts) {
          if (part.contains('모멘텀') ||
              part.contains('작동') ||
              part.contains('상태')) {
            final subParts = part.split(':');
            if (subParts.length > 1) momentumText = subParts[1].trim();
          }
        }
        continue;
      }
      if (foundBoard) {
        if (line.contains('🛡️') ||
            line.contains('✨') ||
            line.contains('📌') ||
            line.contains('🧭') ||
            line.trim() == '***' ||
            line.trim() == '---') {
          continue;
        }
        if (line.startsWith('#') || line.trim().isNotEmpty) {
          foundBoard = false;
          bodyLines.add(line);
        }
      } else {
        bodyLines.add(line);
      }
    }

    cleanContent = bodyLines.join('\n').trim();

    setState(() {
      _cleanContent = cleanContent;
      _sentimentText = sentimentText;
      _momentumText = momentumText;
    });
  }

  // Build rich text with highlighted strategic anchors (markdown bold symbols **)
  List<TextSpan> _buildHighlightedText(String text) {
    List<TextSpan> spans = [];

    // Pattern to catch **bold text**
    final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (final Match match in boldRegex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: const TextStyle(color: Color(0xFFE0E0E0)),
        ));
      }

      // Add the bold text with highlighting style
      spans.add(TextSpan(
        text: match.group(1), // Use the text inside ** **
        style: TextStyle(
          color: const Color(0xFFFFB74D), // Warm emphasis color
          fontWeight: FontWeight.w600,
          backgroundColor: const Color(0xFFFFB74D).withOpacity(0.12),
        ),
      ));

      lastMatchEnd = match.end;
    }

    // Add remaining text
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: const TextStyle(color: Color(0xFFE0E0E0)),
      ));
    }

    return spans;
  }

  // Build paragraph widgets with highlighted text
  Widget _buildContentWidget() {
    final paragraphs = _cleanContent.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((para) {
        final trimmed = para.trim();
        if (trimmed.isEmpty) return const SizedBox(height: 8);

        // Check for headers
        if (trimmed.startsWith('# ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 12),
            child: Text(
              trimmed.substring(2),
              style: GoogleFonts.poorStory(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFFD700),
              ),
            ),
          );
        }
        if (trimmed.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 10),
            child: Text(
              trimmed.substring(3),
              style: GoogleFonts.poorStory(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFFD700),
              ),
            ),
          );
        }

        // Check for blockquote
        if (trimmed.startsWith('>')) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              border: Border(
                left: BorderSide(color: Color(0xFFFFD700), width: 3),
              ),
            ),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poorStory(
                  fontSize: 15,
                  height: 1.8,
                  color: const Color(0xFFCCCCCC),
                  fontStyle: FontStyle.italic,
                ),
                children: _buildHighlightedText(trimmed.substring(1).trim()),
              ),
            ),
          );
        }

        // Regular paragraph with highlighted keywords
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: RichText(
            textAlign: TextAlign.justify,
            text: TextSpan(
              style: GoogleFonts.poorStory(
                fontSize: 16,
                height: 1.85,
                color: const Color(0xFFE0E0E0),
              ),
              children: _buildHighlightedText(trimmed),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Build the full letter card (for capture)
  Widget _buildLetterCard() {
    final dateStr = DateFormat('yyyy. MM. dd.').format(widget.letter.timestamp);

    return Container(
      color: const Color(0xFF121212),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header decoration
          Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFFFD700).withOpacity(0.6),
                  const Color(0xFFFFD700),
                  const Color(0xFFFFD700).withOpacity(0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            widget.letter.title,
            style: GoogleFonts.poorStory(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFD700),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Subtitle (sender & date)
          Text(
            'From. ${widget.letter.sender}  |  $dateStr',
            style: GoogleFonts.poorStory(
              fontSize: 12,
              color: const Color(0xFFAAAAAA),
              letterSpacing: 1.5,
            ),
          ),

          // Sentiment & Momentum tags
          if (_sentimentText.isNotEmpty || _momentumText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                if (_sentimentText.isNotEmpty)
                  _buildTag('💗 정서', _sentimentText),
                if (_momentumText.isNotEmpty) _buildTag('🔄 상태', _momentumText),
              ],
            ),
          ],

          const SizedBox(height: 24),
          Container(
            width: 60,
            height: 1,
            color: const Color(0xFF333333),
          ),
          const SizedBox(height: 24),

          // Content
          _buildContentWidget(),

          const SizedBox(height: 40),

          // Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 20),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF333333), width: 1),
              ),
            ),
            child: Text(
              '마음 우체통 • EmotionTok',
              style: GoogleFonts.poorStory(
                fontSize: 11,
                color: const Color(0xFF666666),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.poorStory(
          fontSize: 12,
          color: const Color(0xFFFFD700),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _saveAsImage() async {
    setState(() => _isSaving = true);

    try {
      // Allow the UI to settle
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('캡처 영영을 찾을 수 없습니다.');

      // Capture the boundary (which is now wrapping the entire content card)
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) throw Exception('이미지 변환에 실패했습니다.');

      final pngBytes = byteData.buffer.asUint8List();
      await _shareImage(pngBytes);
    } catch (e) {
      debugPrint('Image Save Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공유에 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareImage(Uint8List pngBytes) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String fileName =
        'Letter_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';
    final File imageFile = File('${tempDir.path}/$fileName');
    await imageFile.writeAsBytes(pngBytes);

    if (!mounted) return;

    await Share.shareXFiles(
      [XFile(imageFile.path)],
      text: widget.letter.title,
      subject: '마음 우체통 - ${widget.letter.title}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          widget.letter.title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.share_rounded),
            onPressed: _isSaving ? null : _saveAsImage,
            tooltip: '이미지로 공유',
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: RepaintBoundary(
          key: _repaintKey,
          child: _buildLetterCard(),
        ),
      ),
    );
  }
}
