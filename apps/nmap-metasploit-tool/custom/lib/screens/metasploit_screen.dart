import 'package:flutter/material.dart';
import '../alpha/wiring.dart';
import '../alpha/config.dart';

class MetasploitScreen extends StatefulWidget {
  final Backend backend;
  const MetasploitScreen({super.key, required this.backend});

  @override
  State<MetasploitScreen> createState() => _MetasploitScreenState();
}

class _MetasploitScreenState extends State<MetasploitScreen> {
  final _ipController = TextEditingController(text: '192.168.1.50');
  String _selectedTool = 'Meosplite';
  String _selectedStatus = 'ناجح';
  bool _isInjecting = false;
  List<Rec> _injects = [];

  @override
  void initState() {
    super.initState();
    _loadInjects();
  }

  Future<void> _loadInjects() async {
    try {
      final table = AlphaConfig.instance.tables.firstWhere((t) => t.name == 'payload_injects');
      _injects = await widget.backend.list(table);
      setState(() {});
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _saveInject() async {
    setState(() => _isInjecting = true);
    try {
      final table = AlphaConfig.instance.tables.firstWhere((t) => t.name == 'payload_injects');
      await widget.backend.insert(table, {
        'target_ip': _ipController.text,
        'tool_name': _selectedTool,
        'injection_status': _selectedStatus,
      });
      await _loadInjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حقن البايلود الفعلي بنجاح وحفظ السجل')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      setState(() => _isInjecting = false);
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
                    'قائمة Meosplite',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'حقن البايلود الفعلي والأوامر',
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
                      Text('إضافة إلى حقن البايلود', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('الكل', style: TextStyle(color: Color(0xFF00FF66), fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('عنوان آي بي المستهدف', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF9A97AE))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _ipController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF16171F),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.09))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.09))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('اسم الأداة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF9A97AE))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedTool,
                    dropdownColor: const Color(0xFF16171F),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF16171F),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.09))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.09))),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Nmap', child: Text('Nmap')),
                      DropdownMenuItem(value: 'Meosplite', child: Text('Meosplite')),
                    ],
                    onChanged: (val) => setState(() => _selectedTool = val ?? 'Meosplite'),
                  ),
                  const SizedBox(height: 12),
                  const Text('حالة الحقن', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF9A97AE))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    dropdownColor: const Color(0xFF16171F),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF16171F),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.09))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.09))),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ناجح', child: Text('ناجح')),
                      DropdownMenuItem(value: 'فاشل', child: Text('فاشل')),
                    ],
                    onChanged: (val) => setState(() => _selectedStatus = val ?? 'ناجح'),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isInjecting ? null : _saveInject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF66),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.all(15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(_isInjecting ? 'جاري الحقن...' : 'حقن وحفظ', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('سجل الحقن السابق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ..._injects.map((inj) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16171F),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.09)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('الآي بي: ${inj['target_ip']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('الأداة: ${inj['tool_name']}', style: const TextStyle(color: Color(0xFF00FF66))),
                            Text('الحالة: ${inj['injection_status']}', style: const TextStyle(color: Color(0xFF9A97AE))),
                          ],
                        ),
                      )),
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
