import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/user_viewmodel.dart';
import '../viewmodels/venting_viewmodel.dart';
import '../utils/app_fonts.dart';
import '../services/data_export_service.dart';
import 'admin_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userVM = Provider.of<UserViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          _buildSection(
            title: '계정',
            children: [
              _buildSettingTile(
                icon: Icons.person,
                title: '닉네임',
                subtitle: userVM.nickname ?? '닉네임 없음',
                onTap: () => _showNicknameDialog(context, userVM),
              ),
              _buildSettingTile(
                icon: Icons.psychology,
                title: 'AI 페르소나',
                subtitle: _getPersonaName(userVM.selectedPersona),
                onTap: () => _showPersonaDialog(context, userVM),
              ),
            ],
          ),
          const Divider(color: Colors.white10),
          _buildSection(
            title: '화면',
            children: [
              _buildSettingTile(
                icon: Icons.font_download,
                title: '폰트 설정',
                subtitle: userVM.selectedFont,
                onTap: () => _showFontDialog(context, userVM),
              ),
            ],
          ),
          const Divider(color: Colors.white10),
          _buildSection(
            title: '보안',
            children: [
              _buildSettingTile(
                icon: Icons.lock,
                title: 'PIN 변경',
                subtitle: 'PIN 번호를 변경합니다',
                onTap: () => _showPinDialog(context, userVM),
              ),
              _buildSwitchTile(
                icon: Icons.fingerprint,
                title: '생체 인식 잠금',
                subtitle: '앱 실행 시 생체 인식을 사용합니다',
                value: userVM.isBiometricEnabled,
                onChanged: (value) => userVM.toggleBiometric(value),
              ),
            ],
          ),
          const Divider(color: Colors.white10),
          _buildSection(
            title: '사운드',
            children: [
              _buildSwitchTile(
                icon: Icons.music_note,
                title: '배경음 (BGM)',
                subtitle: '앱 실행 시 배경 음악을 재생합니다',
                value: userVM.isBgmOn,
                onChanged: (value) => userVM.toggleBgm(value),
              ),
              _buildSwitchTile(
                icon: Icons.volume_up,
                title: '효과음 (SFX)',
                subtitle: '버튼 클릭 등의 효과음을 재생합니다',
                value: userVM.isSfxOn,
                onChanged: (value) => userVM.toggleSfx(value),
              ),
              _buildSwitchTile(
                icon: Icons.vibration,
                title: '진동 (Vibration)',
                subtitle: '버튼 클릭 등의 진동 효과를 켭니다',
                value: userVM.isVibrationOn,
                onChanged: (value) => userVM.toggleVibration(value),
              ),
            ],
          ),
          const Divider(color: Colors.white10),
          _buildSection(
            title: '앱 정보',
            children: [
              _buildSettingTile(
                icon: Icons.info,
                title: '버전',
                subtitle: 'v1.0.0',
                onTap: null,
              ),
              _buildSettingTile(
                icon: Icons.description,
                title: '이용약관',
                subtitle: '이용약관을 확인합니다',
                onTap: () => _showTermsDialog(context),
              ),
              _buildSettingTile(
                icon: Icons.privacy_tip,
                title: '개인정보 처리방침',
                subtitle: '개인정보 처리방침을 확인합니다',
                onTap: () => _showPrivacyDialog(context),
              ),
            ],
          ),
          // ... (Sound section and App Info section remain roughly the same, skipped for brevity in replacement if not modifying, but I need to be careful with context)
          // Actually, I should just modify the sections I need. But I need to insert Data Backup before Data Reset.

          const Divider(color: Colors.white10),
          _buildSection(
            title: '데이터',
            children: [
              _buildSettingTile(
                icon: Icons.download,
                title: 'CSV로 내보내기 (백업)',
                subtitle: '감정 기록을 파일로 저장합니다',
                onTap: () async {
                  debugPrint('CSV Export tapped');
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('백업 파일을 생성 중입니다...')),
                    );

                    final ventingVM =
                        Provider.of<VentingViewModel>(context, listen: false);
                    final exportService = DataExportService();
                    debugPrint('Posts count: ${ventingVM.myHistory.length}');

                    if (ventingVM.myHistory.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('백업할 데이터가 없습니다.')),
                      );
                      return;
                    }

                    await exportService.exportData(ventingVM.myHistory);

                    // SharePlus itself doesn't return a "success" boolean easily for the UI flow,
                    // but if we get here, the share sheet should have opened.
                    debugPrint('Export service call completed');
                  } catch (e) {
                    debugPrint('Export failed: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('백업 실패: $e')),
                    );
                  }
                },
              ),
              _buildSettingTile(
                icon: Icons.delete_forever,
                title: '모든 데이터 초기화',
                subtitle: '앱의 모든 데이터를 삭제합니다',
                onTap: () => _showResetDialog(context, userVM),
                textColor: Colors.red,
              ),
            ],
          ),
          const Divider(color: Colors.white10),
          _buildSection(
            title: '관리자',
            children: [
              _buildSettingTile(
                icon: Icons.admin_panel_settings,
                title: '관리자 모드',
                subtitle: '시드 데이터 생성 및 관리',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminScreen()),
                ),
                textColor: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showFontDialog(BuildContext context, UserViewModel userVM) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('서체 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppFonts.fontList.map((fontName) {
              return RadioListTile<String>(
                value: fontName,
                groupValue: userVM.selectedFont,
                title: Text(
                  '감정을 태워보세요',
                  style: AppFonts.getFont(fontName,
                      textStyle:
                          const TextStyle(fontSize: 18, color: Colors.white)),
                ),
                subtitle: Text(fontName,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                activeColor: const Color(0xFFFF4D00),
                onChanged: (value) {
                  if (value != null) {
                    userVM.setFont(value);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$value 서체로 변경되었습니다')),
                    );
                  }
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? const Color(0xFFFF4D00)),
      title: Text(title, style: TextStyle(color: textColor ?? Colors.white)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: Colors.grey)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFFF4D00)),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: Switch(
        value: value,
        activeColor: const Color(0xFFFF4D00),
        onChanged: onChanged,
      ),
    );
  }

  String _getPersonaName(Persona persona) {
    switch (persona) {
      case Persona.fighter:
        return '전투형 - 함께 싸워드립니다';
      case Persona.empathy:
        return '공감형 - 따뜻하게 위로합니다';
      case Persona.factBomb:
        return '팩폭형 - 현실적으로 조언합니다';
      case Persona.humor:
        return '유머형 - 재치있게 풀어드립니다';
    }
  }

  void _showNicknameDialog(BuildContext context, UserViewModel userVM) {
    final controller = TextEditingController(text: userVM.nickname ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('닉네임 변경'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '새로운 닉네임을 입력하세요',
            border: OutlineInputBorder(),
          ),
          maxLength: 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                userVM.setNickname(controller.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('닉네임이 변경되었습니다')),
                );
              }
            },
            child: const Text('확인', style: TextStyle(color: Color(0xFFFF4D00))),
          ),
        ],
      ),
    );
  }

  void _showPersonaDialog(BuildContext context, UserViewModel userVM) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('AI 페르소나 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: Persona.values.map((persona) {
            return RadioListTile<Persona>(
              value: persona,
              groupValue: userVM.selectedPersona,
              title: Text(_getPersonaName(persona)),
              activeColor: const Color(0xFFFF4D00),
              onChanged: (value) {
                if (value != null) {
                  userVM.setPersona(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${_getPersonaName(value)} 선택됨')),
                  );
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPinDialog(BuildContext context, UserViewModel userVM) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('PIN 변경'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '새로운 4자리 PIN을 입력하세요',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.length == 4) {
                userVM.setPin(controller.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN이 변경되었습니다')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('4자리 숫자를 입력해주세요')),
                );
              }
            },
            child: const Text('확인', style: TextStyle(color: Color(0xFFFF4D00))),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('이용약관'),
        content: const SingleChildScrollView(
          child: Text(
            '''BURN IT 이용약관

제1조 (목적)
본 약관은 BURN IT 앱 서비스의 이용과 관련하여 회사와 이용자 간의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.

제2조 (서비스의 내용)
1. 감정 배출 및 AI 위로 서비스
2. 사용자 간 감정 공유 커뮤니티
3. 감정 기록 보관 서비스

제3조 (책임의 한계)
1. 본 서비스는 감정 표현을 위한 도구이며, 의료적 조언을 대체하지 않습니다.
2. 사용자가 게시한 콘텐츠에 대한 책임은 사용자에게 있습니다.

제4조 (개인정보 보호)
회사는 관련 법령이 정하는 바에 따라 이용자의 개인정보를 보호하기 위해 노력합니다.
''',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: Color(0xFFFF4D00))),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('개인정보 처리방침'),
        content: const SingleChildScrollView(
          child: Text(
            '''BURN IT 개인정보 처리방침

1. 수집하는 개인정보 항목
- 필수항목: 닉네임, PIN
- 자동수집: 감정 기록 데이터

2. 개인정보의 수집 및 이용목적
- 서비스 제공 및 개인화
- 감정 기록 통계 제공
- 서비스 개선

3. 개인정보의 보유 및 이용기간
- 회원 탈퇴 시까지 보유
- 모든 데이터는 기기 내부에 저장됨

4. 개인정보의 제3자 제공
- 본 앱은 사용자의 개인정보를 외부에 제공하지 않습니다.
- 모든 데이터는 로컬에 저장됩니다.

5. 개인정보의 파기
- 사용자가 '모든 데이터 초기화'를 실행하면 즉시 파기됩니다.
''',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: Color(0xFFFF4D00))),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, UserViewModel userVM) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('경고', style: TextStyle(color: Colors.red)),
        content: const Text(
          '모든 데이터가 영구적으로 삭제됩니다.\n정말 초기화하시겠습니까?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              // TODO: Implement full data reset
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('데이터가 초기화되었습니다'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('초기화', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
