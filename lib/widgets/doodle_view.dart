import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class DoodleView extends StatefulWidget {
  final SignatureController controller;

  const DoodleView({super.key, required this.controller});

  @override
  State<DoodleView> createState() => _DoodleViewState();
}

class _DoodleViewState extends State<DoodleView> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Signature(
          controller: widget.controller,
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}
