import 'package:shared_preferences/shared_preferences.dart';

class UserUtils {
  // 判断是否拥有用户管理权限（admin/user_manager）
  static Future<bool> hasUserManagePermission() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole') ?? 'employee';
    return ['admin', 'user_manager'].contains(role);
  }

  // 获取当前用户角色
  static Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userRole') ?? 'employee';
  }
}