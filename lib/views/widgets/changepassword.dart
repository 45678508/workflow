import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class changepassword extends StatelessWidget {
  const changepassword({super.key});

  @override
  Widget build(BuildContext context) {
    return const DraggableChangePasswordDialog(); // 包装为可拖动弹窗，与设置弹窗风格一致
  }
}

// 可拖动的修改密码弹窗
class DraggableChangePasswordDialog extends StatefulWidget {
  const DraggableChangePasswordDialog({super.key});

  @override
  State<DraggableChangePasswordDialog> createState() => _DraggableChangePasswordDialogState();
}

class _DraggableChangePasswordDialogState extends State<DraggableChangePasswordDialog> {
  // 表单控制器
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();

  // 表单校验状态
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscureOldPwd = true; // 原密码是否隐藏
  bool _obscureNewPwd = true; // 新密码是否隐藏
  bool _obscureConfirmPwd = true; // 确认新密码是否隐藏

  // 获取用户Token（从SharedPreferences中读取）
  Future<String?> _getUserToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // 核心方法：提交修改密码请求
  Future<void> _submitChangePassword() async {
    // 1. 表单校验
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 2. 加载状态开启
    setState(() {
      _isLoading = true;
    });

    try {
      // 3. 获取用户Token
      final token = await _getUserToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('用户未登录，请重新登录'), backgroundColor: Colors.red),
        );
        return;
      }

      // 4. 构造请求参数
      final Map<String, String> requestData = {
        'oldPassword': _oldPasswordController.text.trim(),
        'newPassword': _newPasswordController.text.trim(),
        'confirmNewPassword': _confirmNewPasswordController.text.trim(),
      };

      // 5. 发送POST请求（替换为你的后端接口地址，保持与其他接口域名一致）
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/update-password'), // 后端接口地址
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // 认证头，与其他接口保持一致
        },
        body: jsonEncode(requestData),
      );

      // 6. 解析响应结果
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (!mounted) return;

      if (responseData['success'] == true) {
        // 密码修改成功：提示用户 + 关闭弹窗 + 清除登录状态（可选，强制重新登录）
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['msg']), backgroundColor: Colors.green),
        );

        // 可选：清除SharedPreferences中的登录状态，强制用户重新登录
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', false);
        await prefs.remove('token');

        // 关闭弹窗并返回登录页（根据你的路由逻辑调整）
        Navigator.pop(context);
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        // 修改失败：提示错误信息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['msg']), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('网络异常，请检查后端服务'), backgroundColor: Colors.red),
      );
      print('修改密码异常：$e');
    } finally {
      // 7. 关闭加载状态
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // 释放控制器资源
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 可拖动弹窗布局（与设置弹窗风格统一）
    return GestureDetector(
      // 此处可添加拖动逻辑，与你的DraggableSettingDialog保持一致
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 弹窗标题
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '修改密码',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF001529),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 原密码输入框
                TextFormField(
                  controller: _oldPasswordController,
                  obscureText: _obscureOldPwd,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: '原密码',
                    hintText: '请输入当前登录密码',
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF0088FF)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureOldPwd ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureOldPwd = !_obscureOldPwd;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入原密码';
                    }
                    return null;
                  },
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),

                // 新密码输入框
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPwd,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: '新密码',
                    hintText: '请输入8位以上新密码',
                    prefixIcon: const Icon(Icons.lock_open_outlined, color: Color(0xFF0088FF)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPwd ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNewPwd = !_obscureNewPwd;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入新密码';
                    }
                    if (value.trim().length < 8) {
                      return '新密码长度必须至少8个字符';
                    }
                    return null;
                  },
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),

                // 确认新密码输入框
                TextFormField(
                  controller: _confirmNewPasswordController,
                  obscureText: _obscureConfirmPwd,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: '确认新密码',
                    hintText: '请再次输入新密码',
                    prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF0088FF)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPwd ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPwd = !_obscureConfirmPwd;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请确认新密码';
                    }
                    if (value.trim() != _newPasswordController.text.trim()) {
                      return '两次输入的新密码不一致';
                    }
                    return null;
                  },
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),

                // 提交按钮
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitChangePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0088FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: const Color(0xFF80C4FF),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text(
                      '确认修改',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}