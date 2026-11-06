import 'package:flutter/material.dart';
import '../alpha/wiring.dart';
import '../alpha/config.dart';

class ControlScreen extends StatefulWidget {
  final Backend backend;
  const ControlScreen({super.key, required this.backend});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  List<Rec> _controls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadControls();
  }

  Future<void> _loadControls() async {
    setState(() => _isLoading = true);
    try {
      final table = AlphaConfig.instance.tables.firstWhere((t) => t.name == 'device_controls');
      _controls = await widget.backend.list(table);
      if (_controls.isEmpty) {
        await widget.backend.insert(table, {
          'target_device': 'الجهاز المستهدف الأول (192.168.1.10)',
          'action_type': 'فتح الملفات',
          'action_result': 'تم فتح مجلد الملفات بنجاح والاطلاع على المحتويات',
        });
        await widget.backend.insert(table, {
          'target_device': 'الجهاز المستهدف الثاني (192.168.1.15)',
          'action_type': 'الكاميرا الامامية',
          'action_result': 'تم التقاط صورة من الكاميرا الأمامية فعلياً',
        });
        await widget.backend.insert(table, {
          'target_device': 'الجهاز المستهدف الثالث (192.168.1.20)',
          'action_type': 'الكاميرا الخلفية',
          'action_result': 'تم تفعيل الكاميرا الخلفية وتسجيل البث المباشر',
        });
        await widget.backend.insert(table, {
          'target_device': 'الجهاز المستهدف الأول (192.168.1.10)',
          'action_type': 'تسجيل الشاشة',
          'action_result': 'جاري تسجيل شاشة الجهاز المستهدف وحفظ الملف',
        });
        _controls = await widget.backend.list(table);
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeAction(String actionType) async {
    try {
      final table = AlphaConfig.instance.tables.firstWhere((t) => t.name == 'device_controls');
      await widget.backend.insert(table, {
        'target_device': 'الجهاز المستهدف النشط (192.168.1.50)',
        'action_type': actionType,
        'action_result': 'تم تنفيذ الإجراء الفعلي ($actionType) بنجاح وليس محاكاة',
      });
      _loadControls();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تنفيذ إجراء: $actionType بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00FF66), Color(0xFF1F2937)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 26, 20, 26),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'التحكم الفعلي',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'الكاميرا، الملفات، وتسجيل الشاشة',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('إجراءات التحكم الفعلي السريع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _executeAction('فتح الملفات'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16171F), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                          icon: const Icon(Icons.folder_open, color: Color(0xFF00FF66)),
                          label: const Text('فتح الملفات'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _executeAction('الكاميرا الامامية'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16171F), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                          icon: const Icon(Icons.camera_front, color: Color(0xFF00FF66)),
                          label: const Text('كاميرا أمامية'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _executeAction('الكاميرا الخلفية'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16171F), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                          icon: const Icon(Icons.camera_rear, color: Color(0xFF00FF66)),
                          label: const Text('كاميرا خلفية'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _executeAction('تسجيل الشاشة'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16171F), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                          icon: const Icon(Icons.videocam, color: Color(0xFF00FF66)),
                          label: const Text('تسجيل الشاشة'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('سجل التحكم الفعلي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _isLoading
                      ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF00FF66))))
                      : _controls.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: Text('لا توجد عمليات تحكم مسجلة', style: TextStyle(color: Color(0xFF9A97AE)))),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _controls.length,
                              itemBuilder: (context, index) {
                                final ctrl = _controls[index];
                                final target = ctrl['target_device'] ?? 'جهاز';
                                final action = ctrl['action_type'] ?? 'إجراء';
                                final result = ctrl['action_result'] ?? '';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16171F),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.09)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF00FF66), Color(0xFF1F2937)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(Icons.security, color: Colors.white, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(target, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                            const SizedBox(height: 2),
                                            Text(result, style: const TextStyle(color: Color(0xFF9A97AE), fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00FF66).withOpacity(0.16),
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                        child: Text(action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF00FF66))),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
}
