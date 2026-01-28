import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workflow/views/authentication_screens/login_screen.dart';

class DraggableSettingDialog extends StatefulWidget {
  const DraggableSettingDialog({super.key});

  @override
  State<DraggableSettingDialog> createState() => _DraggableSettingDialogState();
}

class _DraggableSettingDialogState extends State<DraggableSettingDialog> {
  String _username = '';
  String _company = '';
  String _position = '';
  Offset _offset = const Offset(250, 100);

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _offset += details.delta;
    });
  }

  @override
  void initState() {
    super.initState();
    _getUserInfo();
  }

  Future<void> _getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? '';
      _company = prefs.getString('company') ?? '名光微电子';
      _position = prefs.getString('position') ?? '';
    });
  }

  String _getUserAvatarText() {
    if (_username.isEmpty) {
      return "未知";
    }
    return _username.substring(0, 1);
  }

  // 退出登录时保留邮箱，只清除登录状态相关数据
  void _logout() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("确认退出"),
        content: const Text("您确定要退出当前账号吗？"),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("取消", style: TextStyle(color: Colors.black87)),
          ),
          TextButton(
            onPressed: () async {
              try {
                final prefs = await SharedPreferences.getInstance();
                // 只清除登录状态，保留saved_email
                await prefs.setBool('isLoggedIn', false);
                await prefs.remove('token');
                await prefs.remove('userId');
                await prefs.remove('userRole');
                await prefs.remove('username');
                await prefs.remove('role');
                await prefs.remove('position');
                await prefs.remove('company');
                await prefs.remove('teamRole');
                await prefs.remove('admin_token');

                Navigator.pop(dialogContext);
                Navigator.pop(context);

                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (Route<dynamic> route) => false,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("已成功退出登录"),
                      backgroundColor: Colors.blue,
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                print("退出登录异常：$e");
                if (mounted) {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("退出"),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingMenuItem(String title, {bool isSelected = false}) {
    return InkWell(
      onTap: () {},
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? const Color(0xFFF7F8FA) : Colors.transparent,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0088FF) : const Color(0xFF333333),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: _offset.dx,
          top: _offset.dy,
          child: GestureDetector(
            onPanUpdate: _onPanUpdate,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 600,
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(2, 2),
                    )
                  ],
                  border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "设置",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Color(0xFF999999)),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 160,
                            padding: const EdgeInsets.only(top: 16),
                            decoration: const BoxDecoration(
                              border: Border(right: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSettingMenuItem("个人资料", isSelected: true),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children:  [
                                          Text(_company, style: const TextStyle(fontSize: 14, color: Color(0xFF999999))),
                                          const SizedBox(height: 4),
                                          Text(_username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 4),
                                          Text(_position, style: const TextStyle(fontSize: 14, color: Color(0xFF999999))),
                                        ],
                                      ),
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0088FF),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child:  Center(
                                          child: Text(
                                            _getUserAvatarText(),
                                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 32),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: _logout,
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.black),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        backgroundColor: Colors.white,
                                      ),
                                      child: const Text(
                                        "退出",
                                        style: TextStyle(
                                            color: Color(0xFF333333),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}