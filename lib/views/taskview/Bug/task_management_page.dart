import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:workflow/constants/api_constants.dart';
// 导入新的添加BUG页面
import 'add_bug_page.dart';

class TaskManagementPage extends StatefulWidget {
  final String userId;
  const TaskManagementPage({super.key, required this.userId});

  @override
  State<TaskManagementPage> createState() => _TaskManagementPageState();
}

class _TaskManagementPageState extends State<TaskManagementPage> {
  Map<String, dynamic>? _realTaskData;
  bool _isLoading = true;
  String _errorMsg = "";
  List<Map<String, dynamic>> _bugList = [];
  bool _isBugLoading = false;
  bool _isSubmitting = false; // 提交状态标识

  @override
  void initState() {
    super.initState();
    _fetchRealDataFromBackend();
    _fetchBugList();
  }

  Future<void> _fetchRealDataFromBackend() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMsg = "";
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        setState(() {
          _errorMsg = "未登录，请先登录";
          _isLoading = false;
        });
        return;
      }

      // 调用真实接口获取统计数据
      final response = await http.get(
        Uri.parse('$baseUrl/api/statistics'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success']) {
          setState(() {
            _realTaskData = jsonData['data'];
          });
        }
      }
    } catch (e) {
      debugPrint('获取统计数据失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchBugList() async {
    try {
      setState(() {
        _isBugLoading = true;
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        setState(() {
          _errorMsg = "未登录，请先登录";
          _isBugLoading = false;
        });
        return;
      }

      final uri = Uri.parse('$baseUrl/api/bug').replace(
        queryParameters: {'tester': widget.userId},
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success']) {
          setState(() {
            _bugList = List<Map<String, dynamic>>.from(jsonData['data']['list'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('获取BUG列表失败: $e');
    } finally {
      setState(() {
        _isBugLoading = false;
      });
    }
  }

  // 导入Excel文件
  Future<void> _importExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? token = prefs.getString('token');
        if (token == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先登录')),
          );
          return;
        }

        final file = result.files.first;
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/bug/import'),
        );

        request.headers['Authorization'] = 'Bearer $token';
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            file.bytes!,
            filename: file.name,
          ),
        );

        final response = await request.send();
        if (response.statusCode == 201) {
          final responseBody = await response.stream.bytesToString();
          final jsonData = json.decode(responseBody);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(jsonData['message'])),
          );
          _fetchBugList(); // 刷新列表
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('导入失败，请检查文件格式')),
          );
        }
      }
    } catch (e) {
      debugPrint('导入Excel失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导入失败，请稍后重试')),
      );
    }
  }

  // 跳转到添加BUG页面
  void _navigateToAddBugPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddBugPage(
          userId: widget.userId,
          onSubmitSuccess: _fetchBugList, // 提交成功后刷新列表
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMsg.isNotEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: Center(child: Text(_errorMsg)),
      );
    }

    final Map<String, dynamic> taskData = _realTaskData ?? _getDefaultEmptyData();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopActionBar(
              onAddBug: _navigateToAddBugPage, // 修改为跳转页面
              onImportExcel: _importExcel,
              isSubmitting: _isSubmitting,
            ),
            const SizedBox(height: 12),
            _buildScrollableDataCards(taskData),
            const SizedBox(height: 20),
            const Text(
              '我的BUG列表',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: _buildBugList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableDataCards(Map<String, dynamic> taskData) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          _buildDataCard(
            title: "我的BUG总数",
            value: "${taskData["total"]}",
            color: const Color(0xFF1890FF),
          ),
          const SizedBox(width: 6),
          _buildDataCard(
            title: "进行中BUG数",
            value: "${taskData["inProgress"]}",
            color: const Color(0xFFFA8C16),
          ),
          const SizedBox(width: 6),
          _buildDataCard(
            title: "我提交的BUG数",
            value: "${taskData["overdue"]}",
            color: const Color(0xFFF5222D),
          ),
          const SizedBox(width: 6),
          _buildDataCard(
            title: "已完成BUG数",
            value: "${taskData["completed"]}",
            color: const Color(0xFF52C41A),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF86909C), fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBugList() {
    if (_isBugLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_bugList.isEmpty) {
      return const Center(
        child: Text(
          '暂无BUG数据',
          style: TextStyle(color: Color(0xFF86909C), fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _bugList.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final bug = _bugList[index];
        return ListTile(
          title: Text(bug['bugNo'] ?? '未知BUG编号', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('问题描述：${bug['problemDesc'] ?? '无'}'),
              Text('模块：${bug['moduleType'] ?? '无'} | 严重程度：${bug['severity'] ?? '无'}'),
              Text('提交时间：${bug['createTime'] ?? '未知'}'),
            ],
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // 跳转到BUG详情页
          },
        );
      },
    );
  }

  Map<String, dynamic> _getDefaultEmptyData() {
    return {
      "total": 0,
      "inProgress": 0,
      "overdue": 0,
      "completed": 0,
      "notStarted": 0,
      "statusDistribution": [
        {"name": "进行中", "value": 0, "color": "#1890FF"},
        {"name": "已完成", "value": 0, "color": "#52C41A"},
        {"name": "未开始", "value": 0, "color": "#9499A3"},
        {"name": "已逾期", "value": 0, "color": "#FA8C16"},
      ],
      "taskDivision": [
        {"role": "软件", "data": [0, 0, 0]},
        {"role": "硬件", "data": [0, 0, 0]},
        {"role": "测试", "data": [0, 0, 0]},
      ],
    };
  }
}

class _TopActionBar extends StatelessWidget {
  final VoidCallback onAddBug;
  final VoidCallback onImportExcel;
  final bool isSubmitting;
  const _TopActionBar({
    required this.onAddBug,
    required this.onImportExcel,
    required this.isSubmitting,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Wrap(
          spacing: 6,
          children: [
            TextButton.icon(
              onPressed: isSubmitting ? null : onAddBug,
              icon: isSubmitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add, size: 14),
              label: const Text("添加BUG", style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1890FF),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
            TextButton.icon(
              onPressed: isSubmitting ? null : onImportExcel,
              icon: const Icon(Icons.file_upload, size: 14),
              label: const Text("导入Excel", style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1890FF),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text("筛选我的BUG", style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF86909C),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {},
          child: const Text("全屏查看我的数据", style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1890FF),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
      ],
    );
  }
}