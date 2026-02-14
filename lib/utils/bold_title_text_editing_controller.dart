import 'package:flutter/material.dart';

/// A TextEditingController that makes the first line bold.
/// The first line ends at a newline character ('\n') or a period ('.').
class BoldTitleTextEditingController extends TextEditingController {
  BoldTitleTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // If no text, return default
    if (text.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    final String content = text;
    int splitIndex = -1;

    // Check for newline first
    int newlineIndex = content.indexOf('\n');
    int periodIndex = content.indexOf('.');

    if (newlineIndex != -1 && periodIndex != -1) {
      splitIndex = (newlineIndex < periodIndex) ? newlineIndex : periodIndex;
      // If split at period, include the period in the bold part
      if (splitIndex == periodIndex) splitIndex += 1;
    } else if (newlineIndex != -1) {
      splitIndex = newlineIndex;
    } else if (periodIndex != -1) {
      splitIndex = periodIndex + 1; // Include period
    }

    // If no separator found yet, the whole text is currently the title (bold)
    if (splitIndex == -1) {
      return TextSpan(
        style: style?.copyWith(fontWeight: FontWeight.bold),
        text: text,
      );
    }

    // Split text
    final String titlePart = content.substring(0, splitIndex);
    final String bodyPart = content.substring(splitIndex);

    return TextSpan(
      style: style,
      children: [
        TextSpan(
            text: titlePart,
            style: style?.copyWith(fontWeight: FontWeight.bold)),
        TextSpan(text: bodyPart, style: style),
      ],
    );
  }
}
