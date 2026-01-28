import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workflow/views/widgets/settingwiget.dart';
import 'package:workflow/utils/update_handler.dart';
import 'package:workflow/views/taskview/BUG/task_management_page.dart';
import 'package:workflow/views/widgets/changepassword.dart';
import 'dart:async';
import 'package:workflow/views/screens/query/Apply_List_Page.dart';
import 'package:workflow/dailylin/Daily_Report_Page.dart';
import 'package:workflow/views/screens/manager/User_Management_Page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainHomeScreen();
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _selectedSideIndex = 0;
  String _username = '';
  String _company = '';
  String _position = '';
  String _userId = '';
  bool _isProfilePanelShow = false;
  bool _isAdmin = false;
  Timer? _updateTimer;
  // 侧边栏菜单（匹配企业微信图标+配色）
  final List<Map<String, dynamic>> _sideMenu = [
    {"icon": Icons.dashboard, "title": "工作台"},
    {"icon": Icons.list_alt, "title": "任务管理"},
    {"icon": Icons.today, "title": "日报"},
    // {"icon": Icons.folder_copy, "title": "文档"},
    // {"icon": Icons.calendar_today, "title": "日程"},
    {"icon": Icons.people_alt, "title": "用户管理"},

  ];

  // 头像面板菜单（匹配企业微信顺序）
  final List<String> _profileMenuList = [
    "检查更新",
    "修改密码",
    "设置",
  ];

  @override
  void initState() {
    super.initState();
    _getUserInfo(); // 关键修改2：替换原来的 _getUsername 方法
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateHandler.handleCheckUpdate(context, isSilent: true);
      _startAutoUpdateCheck();
    });
  }

  // 关键：启动定时检查更新（每5秒一次）
  void _startAutoUpdateCheck() {
    // 先取消之前的定时器（避免重复创建）
    if (_updateTimer != null) {
      _updateTimer!.cancel();
    }

    // 每5秒执行一次检查（静默模式，不弹加载弹窗）
    _updateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) { // 确保组件未销毁
        UpdateHandler.handleCheckUpdate(context, isSilent: true);
      }
    });
  }

  // 关键：页面销毁时取消定时器（避免内存泄漏）
  @override
  void dispose() {
    if (_updateTimer != null) {
      _updateTimer!.cancel();
      _updateTimer = null;
    }
    super.dispose();
  }

  // 关键修改3：新增读取用户完整信息（包含userId）
  Future<void> _getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? '';
      _company = prefs.getString('company') ?? '名光微电子';
      _position = prefs.getString('position') ?? '';
      _userId = prefs.getString('userId') ?? ''; // 读取登录时存储的userId
      _isAdmin = prefs.getBool('is_admin') ?? false;
    });
  }

  void _toggleProfilePanel() {
    setState(() {
      _isProfilePanelShow = !_isProfilePanelShow;
    });
  }

  void _closeProfilePanel() {
    if (_isProfilePanelShow) {
      setState(() => _isProfilePanelShow = false);
    }
  }

  // 修复后的安全截取方法（封装成函数，复用）
  String _getAvatarText(String name) {
    final trimmedName = name.trim();
    return trimmedName.isNotEmpty ? trimmedName.substring(0, 1) : "未知";
  }

  // 面板菜单项（还原企业微信hover样式）
  Widget _buildProfileMenuItem(String title) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          setState(() => _isProfilePanelShow = false);
          if (title == "设置") {
            showDialog(
              context: context,
              barrierColor: Colors.transparent,
              builder: (context) => const DraggableSettingDialog(),
            );
          }else if (title == "检查更新") {
            UpdateHandler.handleCheckUpdate(context);
          }
          if (title == "修改密码") {
            showDialog(
              context: context,
              barrierColor: Colors.transparent,
              builder: (context) => const changepassword(),
            );
          }
        },
        hoverColor: const Color(0xFFF2F3F5),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _closeProfilePanel,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            // 左侧侧边栏（无修改）
            Container(
              width: 68,
              color: const Color(0xFF001529),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
                    child: InkWell(
                      onTap: _toggleProfilePanel,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0088FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                _getAvatarText(_username),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _getFilteredMenuList().length,
                      itemBuilder: (context, index) {
                        final menuItem = _getFilteredMenuList()[index];
                        return InkWell(
                          onTap: () => setState(() => _selectedSideIndex = index),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            color: _selectedSideIndex == index
                                ? const Color(0xFF002140)
                                : Colors.transparent,
                            child: Column(
                              children: [
                                Icon(
                                  _sideMenu[index]["icon"],
                                  color: _selectedSideIndex == index
                                      ? const Color(0xFF0088FF)
                                      : const Color(0xFF86909C),
                                  size: 26,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _sideMenu[index]["title"],
                                  style: TextStyle(
                                    color: _selectedSideIndex == index
                                        ? const Color(0xFF0088FF)
                                        : const Color(0xFF86909C),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // 右侧内容区+头像面板（无修改）
            Expanded(
              child: Stack(
                children: [
                  Container(
                    color: const Color(0xFFF7F8FA),
                    child: _buildContentByIndex(_selectedSideIndex),
                  ),
                  if (_isProfilePanelShow)
                    Positioned(
                      left: 0,
                      top: 10,
                      child: Container(
                        width: 240,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(2, 4),
                            )
                          ],
                          border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0088FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _getAvatarText(_username),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _username,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF333333),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _company,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF999999),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: "添加工作签名...",
                                  hintStyle: const TextStyle(
                                    color: Color(0xFFCCCCCC),
                                    fontSize: 13,
                                  ),
                                  border: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  isDense: true,
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF333333),
                                ),
                                maxLines: 2,
                              ),
                            ),
                            Column(
                              children: _profileMenuList
                                  .map((title) => Column(
                                children: [
                                  _buildProfileMenuItem(title),
                                  if (_profileMenuList.indexOf(title) != _profileMenuList.length - 1)
                                    const Divider(
                                      height: 0.5,
                                      color: Color(0xFFEEEEEE),
                                      indent: 16,
                                      endIndent: 16,
                                    ),
                                ],
                              ))
                                  .toList(),
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
    );
  }

  // 新增：过滤侧边栏菜单，非管理员移除用户管理项
  List<Map<String, dynamic>> _getFilteredMenuList() {
    if (_isAdmin) {
      return _sideMenu; // 管理员显示全部菜单
    } else {
      // 非管理员过滤掉用户管理项
      return _sideMenu.where((item) => item["title"] != "用户管理").toList();
    }
  }

  // 关键修改4：传递userId给TaskManagementPage
  // 修改：新增用户管理页面的分支
  Widget _buildContentByIndex(int index) {
    // 获取过滤后的菜单列表（匹配显示的菜单索引）
    final filteredMenu = _getFilteredMenuList();
    // 防止索引越界
    if (index >= filteredMenu.length) return ApplyListPage();

    switch (filteredMenu[index]["title"]) { // 改用标题匹配，避免索引错乱
      case "工作台":
        return ApplyListPage();
      case "任务管理":
        return TaskManagementPage(userId: _userId);
      case "日报":
        return DailyReportPage();
      // case "文档":
      //   return DocumentPage(); // 注意：原代码中索引3是CalendarPage，4是DocumentPage，这里按标题匹配更稳定
      // case "日程":
      //   return CalendarPage();
      case "用户管理": // 新增：用户管理页面分支
        return const UserManagementPage();
      default:
        return ApplyListPage();
    }
  }
}