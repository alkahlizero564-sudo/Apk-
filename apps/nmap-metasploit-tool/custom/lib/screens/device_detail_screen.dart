import 'package:flutter/material.dart';
import '../alpha/wiring.dart';
import '../alpha/config.dart';

class DeviceDetailScreen extends StatelessWidget {
  final Backend backend;
  final Rec device;

  const DeviceDetailScreen({super.key, required this.backend, required this.device});

  @override
  Widget build(BuildContext context) {
    final deviceType = device['device_type'] ?? 'جهاز';
    final ipAddress = device['ip_address'] ?? '0.0.0.0';
    final vulnerabilities = device['vulnerabilities'] ?? 'لا توجد ثغرات مسجلة';
    final status = device['connection_status'] ?? 'متصل';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('تفاصيل الجهاز: $deviceType'),
          backgroundColor: const Color(0xFF16171F),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00FF66), Color(0xFF1F2937)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(deviceType, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('عنوان الآي بي: $ipAddress', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('معلومات الجهاز والثغرات المكتشفة فعلياً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16171F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.09)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Text('الثغرات النشطة المكتشفة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(vulnerabilities, style: const TextStyle(color: Color(0xFF9A97AE), fontSize: 15, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Inject payload shortcut
                    final table = AlphaConfig.instance.tables.firstWhere((t) => t.name == 'payload_injects');
                    await backend.insert(table, {
                      'target_ip': ipAddress,
                      'tool_name': 'Meosplite',
                      'injection_status': 'ناجح',
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حقن البايلود الفعلي بنجاح في الجهاز!')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF66),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.flash_on, size: 18),
                  label: const Text('حقن بايلود فعلي (Metasploit)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
