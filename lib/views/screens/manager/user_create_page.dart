import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workflow/constants/api_constants.dart';


class UserCreatePage extends StatefulWidget {
  const UserCreatePage({super.key});

  @override
  State<UserCreatePage> createState() => _UserCreatePageState();
}

class _UserCreatePageState extends State<UserCreatePage> {
  late TextEditingController _emailController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _positionController;
  late TextEditingController _companyController;
  late String _selectedRole;
  late String _selectedTeamRole;
  bool _isLoading = false;

  // 角色选项：移除 user_manager（仅保留 employee 和 admin）
  final List<String> _roleOptions = ['employee', 'admin'];
  // 团队角色选项（匹配后端User模型）
  final List<String> _teamRoleOptions = ['组员', '组长'];

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _positionController = TextEditingController();
    _companyController = TextEditingController();
    _selectedRole = 'employee'; // 默认值仍为 employee（已移除 user_manager，无影响）
    _selectedTeamRole = '组员';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _positionController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  // 提交创建用户数据
  Future<void> _submitCreate() async {
    final Map<String, dynamic> createData = {
      'email': _emailController.text.trim(),
      'username': _usernameController.text.trim(),
      'password': _passwordController.text.trim(),
      'role': _selectedRole,
      'position': _positionController.text.trim(),
      'company': _companyController.text.trim(),
      'teamRole': _selectedTeamRole,
    };

    // 非空校验
    if (createData['email'].isEmpty || createData['username'].isEmpty || createData['password'].isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('邮箱、用户名、密码不能为空')),
      );
      return;
    }

    // 补充：密码长度校验（匹配后端8位以上要求）
    if (createData['password'].length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码长度不能少于8位')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/api/users/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(createData),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('用户创建成功')),
        );
        Navigator.pop(context, true); // 返回上一页并通知刷新列表
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['msg'] ?? '创建用户失败')),
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

  // 封装下拉框样式组件（和输入框保持一致，与 UserEditPage 统一）
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
        title: const Text('创建用户'),
        backgroundColor: const Color(0xFF001529),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 邮箱输入框
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '邮箱',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // 用户名输入框
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // 密码输入框
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码（至少8位）',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // 角色选择：使用封装的样式组件（移除 user_manager 后，仅显示 employee 和 admin）
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '用户角色',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
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
            const SizedBox(height: 16),

            // 团队角色选择：使用封装的样式组件
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 16),

            // 职位输入框
            TextField(
              controller: _positionController,
              decoration: const InputDecoration(
                labelText: '职位',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // 公司输入框
            TextField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: '公司',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24), // 直接设置较大间距，替代原有 Padding 优化

            // 提交按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0088FF),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('创建用户', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}