import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppFonts {
  static const String notoSansKr = '기본 (고딕)';
  static const String nanumPenScript = '나눔 펜 (손글씨)';
  static const String hiMelody = '하이 멜로디 (귀여움)';
  static const String gamjaFlower = '감자 꽃 (투박함)';
  static const String poorStory = '푸어 스토리 (동화책)';

  static final List<String> fontList = [
    notoSansKr,
    nanumPenScript,
    hiMelody,
    gamjaFlower,
    poorStory,
  ];

  static TextStyle getFont(String fontName, {TextStyle? textStyle}) {
    switch (fontName) {
      case nanumPenScript:
        return GoogleFonts.nanumPenScript(textStyle: textStyle);
      case hiMelody:
        return GoogleFonts.hiMelody(textStyle: textStyle);
      case gamjaFlower:
        return GoogleFonts.gamjaFlower(textStyle: textStyle);
      case poorStory:
        return GoogleFonts.poorStory(textStyle: textStyle);
      case notoSansKr:
      default:
        return GoogleFonts.notoSansKr(textStyle: textStyle);
    }
  }
}
