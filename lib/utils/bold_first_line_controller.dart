import 'package:flutter/material.dart';

class BoldFirstLineController extends TextEditingController {
  BoldFirstLineController({String? text}) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final String text = value.text;
    if (text.isEmpty) {
      return TextSpan(text: '', style: style);
    }

    final int newlineIndex = text.indexOf('\n');
    if (newlineIndex == -1) {
      // No newline, whole text is first line
      return TextSpan(
        style: style,
        children: [
          TextSpan(
            text: text,
            style: style?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    // Split into first line and rest
    final String firstLine = text.substring(0, newlineIndex + 1);
    final String rest = text.substring(newlineIndex + 1);

    return TextSpan(
      style: style,
      children: [
        TextSpan(
          text: firstLine,
          style: style?.copyWith(fontWeight: FontWeight.bold),
        ),
        TextSpan(text: rest, style: style),
      ],
    );
  }
}
