import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_edit_page.dart';
import 'user_create_page.dart';
import 'package:workflow/constants/api_constants.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<dynamic> _userList = []; // 原始用户列表
  List<dynamic> _filteredUserList = []; // 筛选后的用户列表
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController(); // 搜索控制器

  @override
  void initState() {
    super.initState();
    _fetchUsers(); // 加载用户列表
    _searchController.addListener(_filterUsers); // 监听搜索框输入变化
  }

  @override
  void dispose() {
    _searchController.dispose(); // 释放控制器
    super.dispose();
  }

  // 获取用户列表
  Future<void> _fetchUsers() async {
    try {
      setState(() => _isLoading = true);
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/api/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success']) {
        setState(() {
          _userList = data['data'];
          _filteredUserList = data['data']; // 初始化筛选列表
          _isLoading = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['msg'] ?? '获取用户列表失败')),
          );
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('网络错误: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  // 筛选用户（全局搜索）
  void _filterUsers() {
    final searchKeyword = _searchController.text.trim().toLowerCase();
    if (searchKeyword.isEmpty) {
      // 搜索框为空时显示全部用户
      setState(() {
        _filteredUserList = List.from(_userList);
      });
      return;
    }

    // 筛选包含关键词的用户（支持所有字段搜索）
    final filtered = _userList.where((user) {
      final username = (user['username'] ?? '').toLowerCase();
      final email = (user['email'] ?? '').toLowerCase();
      final role = (user['role'] ?? '').toLowerCase();
      final teamRole = (user['teamRole'] ?? '').toLowerCase();
      final company = (user['company'] ?? '').toLowerCase();

      // 只要任意字段包含关键词就匹配
      return username.contains(searchKeyword) ||
          email.contains(searchKeyword) ||
          role.contains(searchKeyword) ||
          teamRole.contains(searchKeyword) ||
          company.contains(searchKeyword);
    }).toList();

    setState(() {
      _filteredUserList = filtered;
    });
  }

  // 删除用户
  Future<void> _deleteUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.delete(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('用户删除成功')),
          );
        }
        await _fetchUsers(); // 重新加载列表
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['msg'] ?? '删除用户失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('网络错误: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户管理'),
        backgroundColor: const Color(0xFF001529),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 新增：搜索框
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索...',
                hintStyle: const TextStyle(color: Color(0xFF86909C), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF86909C)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF86909C)),
                  onPressed: () => _searchController.clear(), // 清空搜索框
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E6EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E6EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF0088FF)),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: const TextStyle(fontSize: 14, color: Color(0xFF4E5969)),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _filterUsers(), // 回车触发搜索
            ),
          ),
          // 原有列表内容
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUserList.isEmpty
                ? const Center(child: Text('暂无匹配的用户数据'))
                : ListView.builder(
              itemCount: _filteredUserList.length,
              itemBuilder: (context, index) {
                final user = _filteredUserList[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0088FF),
                    child: Text(
                      user['username'].substring(0, 1),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(user['username']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('邮箱: ${user['email']}'),
                      Text('角色: ${user['role']}'),
                      Text('团队角色: ${user['teamRole']}'),
                      Text('公司: ${user['company']}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 编辑按钮（跳转编辑页面，接收返回结果刷新列表）
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserEditPage(user: user),
                            ),
                          );
                          if (result == true) {
                            await _fetchUsers(); // 刷新用户列表
                          }
                        },
                      ),
                      // 删除按钮
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('确认删除'),
                              content: Text('是否删除用户 ${user['username']}？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deleteUser(user['_id']);
                                  },
                                  child: const Text('删除', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // 新增用户按钮（跳转创建页面，接收返回结果刷新列表）
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserCreatePage()),
          );
          if (result == true) {
            await _fetchUsers(); // 刷新用户列表
          }
        },
        backgroundColor: const Color(0xFF0088FF),
        child: const Icon(Icons.add),
      ),
    );
  }
}