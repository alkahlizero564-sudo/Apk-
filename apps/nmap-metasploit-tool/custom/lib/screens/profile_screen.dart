import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final dynamic backend;
  const ProfileScreen({super.key, required this.backend});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: MediaQuery.of(context).padding.top + 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00FF66), Color(0xFF1F2937)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16171F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.09)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF00FF66), Color(0xFF1F2937)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Text('ت', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('سارة محمد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            SizedBox(height: 2),
                            Text('عضو منذ ٢٠٢٦', style: TextStyle(color: Color(0xFF9A97AE), fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF16171F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.09)),
                    ),
                    child: Column(
                      children: [
                        _kvRow('الإشعارات', 'مفعّلة', showDivider: true),
                        _kvRow('اللغة', 'العربية', showDivider: true),
                        _kvRow('المظهر', 'داكن', showDivider: false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حفظ الإعدادات بنجاح')),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFF16171F),
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.09)),
                            padding: const EdgeInsets.all(15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.settings, size: 18),
                          label: const Text('الإعدادات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 110),
          ],
        ),
      ),
    );
  }

  Widget _kvRow(String label, String value, {required bool showDivider}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: showDivider ? Border(bottom: BorderSide(color: Colors.white.withOpacity(0.09))) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(color: Color(0xFF9A97AE))),
        ],
      ),
    );
  }
}
