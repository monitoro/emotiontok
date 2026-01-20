import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/user_viewmodel.dart';
import 'main_navigation_screen.dart';

class PersonaSelectionScreen extends StatelessWidget {
  const PersonaSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('AI 페르소나 선택'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              '당신의 감정을 보듬어줄\n상대방을 골라주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: const [
                  _PersonaCard(
                    title: '전투형',
                    description: '같이 욕하며 스트레스 타파!',
                    icon: Icons.flash_on,
                    persona: Persona.fighter,
                  ),
                  _PersonaCard(
                    title: '공감형',
                    description: '따뜻한 위로와 경청',
                    icon: Icons.favorite,
                    persona: Persona.empathy,
                  ),
                  _PersonaCard(
                    title: '팩폭형',
                    description: '냉철한 분석과 팩트 체크',
                    icon: Icons.psychology,
                    persona: Persona.factBomb,
                  ),
                  _PersonaCard(
                    title: '유머형',
                    description: '웃음으로 승화시키기',
                    icon: Icons.sentiment_very_satisfied,
                    persona: Persona.humor,
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

class _PersonaCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Persona persona;

  const _PersonaCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.persona,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final userVM = Provider.of<UserViewModel>(context, listen: false);
        userVM.setPersona(persona);
        userVM.login();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFF4D00).withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: const Color(0xFFFF4D00)),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
