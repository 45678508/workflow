import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workflow/constants/api_constants.dart';

class UserEditPage extends StatefulWidget {
  final Map<String, dynamic> user; // 接收待编辑的用户数据

  const UserEditPage({super.key, required this.user});

  @override
  State<UserEditPage> createState() => _UserEditPageState();
}

class _UserEditPageState extends State<UserEditPage> {
  late TextEditingController _emailController;
  late TextEditingController _usernameController;
  late TextEditingController _positionController;
  late String _selectedRole;
  late String _selectedTeamRole;
  bool _isLoading = false;

  // 角色选项（匹配后端User模型）
  final List<String> _roleOptions = ['employee', 'admin'];
  // 团队角色选项（匹配后端User模型）
  final List<String> _teamRoleOptions = ['组员', '组长'];

  @override
  void initState() {
    super.initState();
    // 初始化输入框数据（移除 _companyController 相关配置）
    _emailController = TextEditingController(text: widget.user['email'] ?? '');
    _usernameController = TextEditingController(text: widget.user['username'] ?? '');
    _positionController = TextEditingController(text: widget.user['position'] ?? '');
    _selectedRole = widget.user['role'] ?? 'employee';
    _selectedTeamRole = widget.user['teamRole'] ?? '组员';
  }

  @override
  void dispose() {
    // 释放控制器（移除 _companyController 的 dispose 调用）
    _emailController.dispose();
    _usernameController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  // 提交编辑用户数据
  Future<void> _submitEdit() async {
    final String userId = widget.user['_id'];
    final Map<String, dynamic> editData = {
      'email': _emailController.text.trim(),
      'username': _usernameController.text.trim(),
      'role': _selectedRole,
      'position': _positionController.text.trim(),
      'teamRole': _selectedTeamRole, // 移除 company 字段
    };

    // 非空校验
    if (editData['email'].isEmpty || editData['username'].isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('邮箱和用户名不能为空')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.put(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(editData),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('用户编辑成功')),
        );
        Navigator.pop(context, true); // 返回上一页并通知刷新列表
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['msg'] ?? '编辑用户失败')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('网络错误: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 封装下拉框样式组件（和输入框保持一致，减少冗余代码）
  Widget _buildStyledDropdown({
    required String label,
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(4), // 和输入框圆角一致
      ),
      child: DropdownButtonHideUnderline(
        // 隐藏下拉框默认下划线，匹配输入框样式
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(label),
          disabledHint: Text(value),
          style: const TextStyle(fontSize: 14, color: Colors.black87), // 和输入框文本样式一致
          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey), // 优化下拉箭头样式
          onChanged: _isLoading ? null : (value) => onChanged(value),
          items: options.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8), // 优化选项内边距
                child: Text(option),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑用户'),
        backgroundColor: const Color(0xFF001529),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 邮箱输入框
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '邮箱',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 统一内边距
                ),
                enabled: !_isLoading,
              ),
            ),

            // 用户名输入框
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                enabled: !_isLoading,
              ),
            ),

            // 角色选择（优化样式，和输入框一致）
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '用户角色',
                    style: TextStyle(fontSize: 14, color: Colors.grey), // 和输入框标签样式一致
                  ),
                  const SizedBox(height: 8),
                  _buildStyledDropdown(
                    label: '用户角色',
                    value: _selectedRole,
                    options: _roleOptions,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedRole = value);
                      }
                    },
                  ),
                ],
              ),
            ),

            // 团队角色选择（优化样式，和输入框一致）
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '团队角色',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  _buildStyledDropdown(
                    label: '团队角色',
                    value: _selectedTeamRole,
                    options: _teamRoleOptions,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedTeamRole = value);
                      }
                    },
                  ),
                ],
              ),
            ),

            // 职位输入框（修正 label 为「职位」，之前写错为「公司」）
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _positionController,
                decoration: const InputDecoration(
                  labelText: '职位', // 修正标签文本
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                enabled: !_isLoading,
              ),
            ),

            // 提交按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitEdit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0088FF),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4), // 和输入框圆角一致
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('提交修改', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}