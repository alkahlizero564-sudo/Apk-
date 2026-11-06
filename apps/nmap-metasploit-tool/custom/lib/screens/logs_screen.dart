import 'package:flutter/material.dart';
import '../alpha/wiring.dart';
import '../alpha/config.dart';

class LogsScreen extends StatefulWidget {
  final Backend backend;
  const LogsScreen({super.key, required this.backend});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Rec> _logs = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final table = AlphaConfig.instance.tables.firstWhere((t) => t.name == 'search_logs');
      _logs = await widget.backend.list(table);
      if (_logs.isEmpty) {
        await widget.backend.insert(table, {
          'search_date': DateTime.now().toIso8601String(),
          'target_device': 'الجهاز المستهدف الأول (192.168.1.10)',
          'search_results': 'تم فحص البورتات بنجاح واكتشاف 3 ثغرات خطيرة',
        });
        await widget.backend.insert(table, {
          'search_date': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          'target_device': 'الجهاز المستهدف الثاني (192.168.1.15)',
          'search_results': 'بحث Nmap اكتشف أجهزة الهواتف المتصلة بالشبكة',
        });
        await widget.backend.insert(table, {
          'search_date': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
          'target_device': 'الجهاز المستهدف الثالث (192.168.1.20)',
          'search_results': 'فحص شامل لشبكة الواي فاي وثغرات الأمان',
        });
        _logs = await widget.backend.list(table);
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _logs.where((log) {
      final target = (log['target_device'] ?? '').toString();
      final results = (log['search_results'] ?? '').toString();
      return target.contains(_searchQuery) || results.contains(_searchQuery);
    }).toList();

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
                    'سجل البحث',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'سجل عمليات البحث والنتائج السابقة',
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16171F),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white.withOpacity(0.09)),
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search, color: Color(0xFF9A97AE), size: 18),
                        hintText: 'بحث في سجل البحث…',
                        hintStyle: TextStyle(color: Color(0xFF9A97AE)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('سجل البحث الفعلي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _isLoading
                      ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF00FF66))))
                      : filteredLogs.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: Text('لا توجد سجلات بحث مطابقة', style: TextStyle(color: Color(0xFF9A97AE)))),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredLogs.length,
                              itemBuilder: (context, index) {
                                final log = filteredLogs[index];
                                final target = log['target_device'] ?? 'جهاز';
                                final results = log['search_results'] ?? '';
                                final date = log['search_date'] ?? '';

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
                                        child: const Icon(Icons.history, color: Colors.white, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(target, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                            const SizedBox(height: 2),
                                            Text(results, style: const TextStyle(color: Color(0xFF9A97AE), fontSize: 13)),
                                            const SizedBox(height: 2),
                                            Text('$date', style: const TextStyle(color: Color(0xFF00FF66), fontSize: 11)),
                                          ],
                                        ),
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
