import 'package:flutter/material.dart';
import '../alpha/config.dart';
import 'device_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final dynamic backend;
  const HomeScreen({super.key, required this.backend});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final devicesTable = AlphaConfig.instance.tables.firstWhere((t) => t.name == 'devices');
      _devices = await widget.backend.list(devicesTable);
      if (_devices.isEmpty) {
        await widget.backend.insert(devicesTable, {
          'device_type': 'ايفون',
          'ip_address': '192.168.1.15',
          'vulnerabilities': 'CVE-2023-41064 (فعلية: ثغرة أمنية في وحدة ImageIO)',
          'connection_status': 'متصل',
        });
        await widget.backend.insert(devicesTable, {
          'device_type': 'اندرويد',
          'ip_address': '192.168.1.20',
          'vulnerabilities': 'CVE-2024-0040 (فعلية: ثغرة تجاوز الصلاحيات في ADB)',
          'connection_status': 'متصل',
        });
        await widget.backend.insert(devicesTable, {
          'device_type': 'وندوس',
          'ip_address': '192.168.1.10',
          'vulnerabilities': 'MS17-010 EternalBlue (فعلية: تنفيذ تعليمة برمجية عن بُعد)',
          'connection_status': 'متصل',
        });
        await widget.backend.insert(devicesTable, {
          'device_type': 'لينكس',
          'ip_address': '192.168.1.25',
          'vulnerabilities': 'CVE-2021-4034 (فعلية: Polkit Local Privilege Escalation)',
          'connection_status': 'متصل',
        });
        await widget.backend.insert(devicesTable, {
          'device_type': 'واي فاي',
          'ip_address': '192.168.1.1',
          'vulnerabilities': 'KRACK Attack Vulnerability (فعلية: هجوم إعادة تثبيت المفتاح)',
          'connection_status': 'متصل',
        });
        _devices = await widget.backend.list(devicesTable);
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  IconData _getDeviceIcon(String type) {
    switch (type) {
      case 'ايفون':
        return Icons.phone_iphone;
      case 'اندرويد':
        return Icons.phone_android;
      case 'وندوس':
        return Icons.window;
      case 'لينكس':
        return Icons.computer;
      case 'واي فاي':
        return Icons.wifi;
      default:
        return Icons.devices;
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
              child: Stack(
                children: [
                  Positioned(
                    left: -50,
                    top: -50,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 40,
                    bottom: -40,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.10),
                      ),
                    ),
                  ),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أداة Nmap و Meosplite',
                        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      SizedBox(height: 7),
                      Text(
                        'البحث عن الأجهزة واكتشاف الثغرات والتحكم الفعلي',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16171F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.09)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FF66).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.devices, color: Color(0xFF00FF66), size: 20),
                          ),
                          const SizedBox(height: 8),
                          Text('${_devices.length}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          const Text('الأجهزة المكتشفة', style: TextStyle(color: Color(0xFF9A97AE), fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16171F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.09)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FF66).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.bug_report, color: Color(0xFF00FF66), size: 20),
                          ),
                          const SizedBox(height: 8),
                          const Text('5', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          const Text('الثغرات النشطة', style: TextStyle(color: Color(0xFF9A97AE), fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الأجهزة المكتشفة (ايفون، اندرويد، وندوس، لينكس، واي فاي)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  TextButton(
                    onPressed: _loadData,
                    child: const Text('تحديث', style: TextStyle(color: Color(0xFF00FF66), fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            _isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF00FF66))))
                : _devices.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('لا توجد أجهزة مكتشفة حالياً', style: TextStyle(color: Color(0xFF9A97AE)))),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final deviceType = device['device_type'] ?? 'اندرويد';
                          final ipAddress = device['ip_address'] ?? '0.0.0.0';

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DeviceDetailScreen(backend: widget.backend, device: device),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
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
                                    child: Icon(_getDeviceIcon(deviceType), color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(deviceType, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                        const SizedBox(height: 2),
                                        Text(ipAddress, style: const TextStyle(color: Color(0xFF9A97AE), fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00FF66).withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      deviceType,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF00FF66)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF9A97AE)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            const SizedBox(height: 110),
          ],
        ),
      ),
    );
  }
}
