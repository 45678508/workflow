import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 新增：导入键盘事件相关包
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:workflow/views/screens/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workflow/constants/api_constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // 控制密码是否隐藏
  bool _obscurePassword = true;
  // 登录按钮加载状态
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    // 初始化时读取保存的邮箱
    _loadSavedEmail();
  }

  // 读取本地保存的邮箱
  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email') ?? '';
    if (savedEmail.isNotEmpty) {
      setState(() {
        emailController.text = savedEmail;
      });
    }
  }

  // 保存邮箱到本地
  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', email);
  }

  Future<void> _login(BuildContext context) async {
    if (_isLoggingIn) return;
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入邮箱和密码')),
      );
      return;
    }

    setState(() => _isLoggingIn = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        // 登录成功，保存邮箱
        await _saveEmail(email);

        final token = data['token'] ?? '';
        final userId = data['user']['_id'] ?? '';
        final role = data['user']['role'] ?? 'employee';
        final username = data['user']['username'] ?? '';
        final position = data['user']['position'] ?? '';
        final company = data['user']['company'] ?? '';
        final teamRole = data['user']['teamRole'] ?? '组员';

        print('后端返回的职位：$position');
        print('后端返回的公司：$company');
        print('后端返回的用户名：$username');
        print('后端返回的user数据：${data['user']}');
        print('后端返回的团队角色：$teamRole');

        await saveLoginStatus(token, userId, role, username, position, company, teamRole);

        // 登录成功，跳转到主界面
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['msg'] ?? '登录失败')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('网络错误: $e')),
      );
    } finally {
      setState(() => _isLoggingIn = false);
    }
  }

  Future<void> saveLoginStatus(
      String token,
      String userId,
      String role,
      String username,
      String position,
      String company,
      String teamRole
      ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('token', token);
    await prefs.setString('userId', userId);
    await prefs.setString('userRole', role);
    await prefs.setString('username', username);
    await prefs.setString('position', position);
    await prefs.setString('company', company);
    await prefs.setString('teamRole', teamRole);

    bool isAdmin = role == 'admin' || role == 'user_manager' || role == 'super_admin';
    await prefs.setBool('is_admin', isAdmin);

    if (isAdmin && token.isNotEmpty) {
      await prefs.setString('admin_token', token);
      print('管理员Token已存储：$token');
    } else {
      await prefs.remove('admin_token');
    }

    print('团队角色已存储：$teamRole');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final inputWidth = screenWidth * 0.9;

    return Scaffold(
      backgroundColor: Colors.white.withValues(alpha: 0.95),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "login your acount",
                    style: TextStyle(
                      color: Color(0xFF0d120E),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                      fontSize: 22,
                    ),
                  ),
                  Text('To Explore the world exclusives',
                    style: TextStyle(
                      color: Color(0xff3a503f),
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 32),
                  // 图片区域
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Image.asset(
                      'assets/images/login.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 邮箱输入框
                  SizedBox(
                    width: inputWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: emailController,
                          decoration: InputDecoration(
                            fillColor: Colors.grey.shade50,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: const BorderSide(color: Color(0XFF00D102), width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: BorderSide.none,
                            ),
                            labelText: 'Enter your email',
                            labelStyle: const TextStyle(
                              fontSize: 14,
                              letterSpacing: 0.1,
                              color: Colors.grey,
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Image.asset(
                                'assets/icons/email.png',
                                width: 20,
                                height: 20,
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          // 邮箱框回车跳转到密码框
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).nextFocus();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 密码输入框
                  SizedBox(
                    width: inputWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Password',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            fillColor: Colors.grey.shade50,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: const BorderSide(color: Color(0XFF00D102), width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: BorderSide.none,
                            ),
                            labelText: 'Enter your password',
                            labelStyle: const TextStyle(
                              fontSize: 14,
                              letterSpacing: 0.1,
                              color: Colors.grey,
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Image.asset(
                                'assets/icons/password.png',
                                width: 20,
                                height: 20,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          // 简化版回车登录 - 兼容所有Flutter版本
                          onFieldSubmitted: (_) {
                            // 收起键盘
                            FocusScope.of(context).unfocus();
                            // 执行登录
                            _login(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(height: 20),
                  InkWell(
                    onTap: () => _login(context),
                    borderRadius: BorderRadius.circular(5),
                    splashColor: Color(0xfff1ffff),
                    child: Container(
                        width: 319,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          gradient: LinearGradient(
                            colors: [Color(0xFF102DE1), Color(0xCC0D6eFF)],
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 278,
                              top: 19,
                              child: Opacity(
                                opacity: 0.5,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      width: 12,
                                      color: Color(0xFF103DE5),
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                                left: 311,
                                top: 36,
                                child: Opacity(
                                  opacity: 0.3,
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(3)
                                    ),
                                  ),
                                )
                            ),
                            Positioned(
                              left: 281,
                              top: -10,
                              child: Opacity(
                                opacity: 0.3,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: _isLoggingIn
                                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                  : Text(
                                'Sign in',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          ],
                        )
                    ),
                  )
                ]
            ),
          ),
        ),
      ),
    );
  }
}