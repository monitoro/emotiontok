import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/venting_viewmodel.dart';
import '../models/letter_model.dart';
import 'letter_detail_screen.dart';

class MailboxScreen extends StatelessWidget {
  const MailboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ventingVM = Provider.of<VentingViewModel>(context);
    final letters = ventingVM.letters;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title:
            Text('마음 우체통', style: GoogleFonts.poorStory(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: letters.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mark_email_unread_outlined,
                      size: 64, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  Text('도착한 편지가 없어요.',
                      style: GoogleFonts.poorStory(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: letters.length,
              itemBuilder: (context, index) {
                final letter = letters[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildLetterCard(context, letter, ventingVM),
                );
              },
            ),
    );
  }

  Widget _buildLetterCard(
      BuildContext context, Letter letter, VentingViewModel vm) {
    return GestureDetector(
      onTap: () {
        vm.markLetterAsRead(letter.id);
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => LetterDetailScreen(letter: letter)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              letter.isRead ? const Color(0xFF1E1E1E) : const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(12),
          border: letter.isRead
              ? null
              : Border.all(color: const Color(0xFFFF4D00).withOpacity(0.5)),
          boxShadow: [
            if (!letter.isRead)
              BoxShadow(
                color: const Color(0xFFFF4D00).withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 1,
              )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mail_outline, color: Colors.white70),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          letter.title,
                          style: GoogleFonts.poorStory(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!letter.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF4D00),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${letter.sender} • ${DateFormat('MM/dd HH:mm').format(letter.timestamp)}',
                    style:
                        GoogleFonts.poorStory(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    letter.previewText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poorStory(
                      color: letter.isRead ? Colors.grey : Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
