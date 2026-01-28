import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'dart:developer' as dev;
import 'package:intl/intl.dart';
// 请确保这些常量和页面文件路径正确
import 'package:workflow/constants/api_constants.dart';
import 'package:workflow/views/screens/apply/Apply_Form_Page.dart';
import 'apply_detail_page.dart' hide ApplyModel, NoCompletePage;
import 'package:workflow/views/screens/query/pdf_generator.dart';
import 'package:workflow/views/screens/apply/wait_confirm_Page.dart';
import 'apply_model.dart';

// 新增：布局模式枚举
enum LayoutMode {
  list, // 列表模式（原有样式）
  grid, // 网格模式（一排5个）
}

// 新增：筛选状态枚举
enum FilterStatus {
  all, // 全部
  completed, // 已完成
  inProgress, // 进行中
  overdue, // 逾期
  notStarted, // 未开始
  paused, // 暂停
  cancelled, // 已取消
}

// 新增：统计项数据类（修复类型错误）
class StatItem {
  final String label;
  final String value;
  final Color color;
  final FilterStatus status;

  StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.status,
  });
}

class ApplyListPage extends StatefulWidget {
  const ApplyListPage({super.key});

  @override
  State<ApplyListPage> createState() => _ApplyListPageState();
}

class _ApplyListPageState extends State<ApplyListPage> {
  // 明确指定泛型，强化类型推断
  late List<ApplyModel> _allApplyList;
  late List<ApplyModel> _filteredApplyList;
  bool _isLoading = true;
  String _errorMsg = '';
  bool _isGenerating = false;
  bool _showCancelledTasks = false;
  String? _lastSavePath;
  final TextEditingController _searchController = TextEditingController();
  String _userRole = 'employee'; // 默认普通员工
  String _teamRole = '组员'; // 默认组员

  DateTime? _startDate;
  DateTime? _endDate;
  // 时间格式化工具 - 统一格式定义
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');
  final DateFormat _fullDateTimeFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
  late DateTime _oneMonthAgo;

  // 新增：布局模式状态
  LayoutMode _currentLayoutMode = LayoutMode.list;

  // 新增：筛选状态
  FilterStatus _currentFilterStatus = FilterStatus.all;
  // 新增：记录当前选中的统计项索引
  int _selectedStatIndex = 0;

  // ========== 新增：任务统计数据（基于全量数据） ==========
  int _totalCount = 0;        // 总任务数
  int _completedCount = 0;    // 已完成
  int _inProgressCount = 0;   // 进行中
  int _overdueCount = 0;      // 逾期
  int _notStartedCount = 0;   // 未开始
  int _pausedCount = 0;       // 暂停
  int _cancelledCount = 0;    // 已取消（新增）

  _ApplyListPageState() {
    _oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
    _allApplyList = [];
    _filteredApplyList = [];
  }

  @override
  void initState() {
    super.initState();
    _initUserInfo();
    _fetchAllApplyList(); // 替换为正确的加载方法
    _searchController.addListener(_onSearch); // 修复：绑定正确的监听方法
    _loadLayoutMode();
    _loadLastSavePath();
    _showCancelledTasks = false;
  }

  // 初始化用户权限信息
  Future<void> _initUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('userRole') ?? 'employee';
      _teamRole = prefs.getString('teamRole') ?? '组员';
    });
  }

  // 修复：正确的_onSearch方法（搜索监听）
  void _onSearch() {
    final keyword = _searchController.text.trim();
    if (keyword.isNotEmpty) {
      // 有搜索关键词：调用搜索接口（能查到所有人的任务）
      _searchApplies(keyword);
    } else {
      // 无搜索关键词：重新加载默认数据（按权限过滤）
      _fetchAllApplyList();
    }
  }

  // 时间格式化工具方法 - 统一解析后端返回的时间格式
  String formatExpectedTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '未设置';

    try {
      // 先尝试解析完整格式 (yyyy-MM-dd HH:mm:ss)
      DateTime date = _fullDateTimeFormatter.parse(timeStr);
      return _dateFormatter.format(date);
    } catch (e) {
      try {
        // 再尝试解析仅日期格式 (yyyy-MM-dd)
        DateTime date = _dateFormatter.parse(timeStr);
        return _dateFormatter.format(date);
      } catch (e) {
        // 解析ISO格式
        try {
          DateTime date = DateTime.parse(timeStr);
          return _dateFormatter.format(date);
        } catch (e) {
          dev.log('时间解析失败: $timeStr, 错误: $e', name: '时间格式化');
          return '格式错误';
        }
      }
    }
  }

  // 解析ISO时间字符串为DateTime对象
  DateTime? parseIsoDateTime(String? isoStr) {
    if (isoStr == null || isoStr.isEmpty) return null;
    try {
      return DateTime.parse(isoStr);
    } catch (e) {
      dev.log('解析ISO时间失败: $isoStr, 错误: $e', name: '时间解析');
      return null;
    }
  }

  // 新增搜索接口调用方法
  Future<void> _searchApplies(String keyword) async {
    try {
      dev.log('搜索任务：$keyword', name: '搜索');
      final prefs = await SharedPreferences.getInstance();
      final String userToken = prefs.getString('token') ?? '';

      if (userToken.isEmpty) {
        _showSnackBar('用户未登录，无法搜索', isError: true);
        return;
      }

      final String requestUrl = '$baseUrl/api/public/search-applies?keyword=${Uri.encodeComponent(keyword)}';
      final response = await http.get(
        Uri.parse(requestUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userToken',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _showSnackBar('搜索失败，状态码：${response.statusCode}', isError: true);
        return;
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        _showSnackBar(data['msg'] ?? '搜索失败', isError: true);
        return;
      }

      List<ApplyModel> list = [];
      if (data['data'] != null && data['data'] is List) {
        for (var item in data['data']) {
          try {
            ApplyModel model = ApplyModel.fromJson(item);
            list.add(model);
          } catch (e) {
            dev.log('搜索结果解析失败：$e', name: '搜索');
            continue;
          }
        }
      }

      // ========== 新增：按申请时间降序排序 ==========
      list.sort((a, b) {
        if (a.applyDateTime == null && b.applyDateTime == null) return 0;
        if (a.applyDateTime == null) return 1;
        if (b.applyDateTime == null) return -1;
        return b.applyDateTime!.compareTo(a.applyDateTime!);
      });
      // ========== 排序逻辑结束 ==========

      setState(() {
        _allApplyList = list;
        _filteredApplyList = list;
        _calculateTaskStats(); // 搜索后重新计算统计
      });

      dev.log('搜索完成，找到${list.length}条结果（已排序）', name: '搜索');
    } catch (e) {
      dev.log('搜索异常：$e', name: '搜索', error: e);
      _showSnackBar('搜索出错：$e', isError: true);
    }
  }

  // 新增：加载保存的布局模式
  Future<void> _loadLayoutMode() async {
    final prefs = await SharedPreferences.getInstance();
    // 读取保存的布局模式，默认是列表模式
    String? savedMode = prefs.getString('layout_mode');
    setState(() {
      // _currentLayoutMode = savedMode == 'grid' ? LayoutMode.grid : LayoutMode.list;
      _currentLayoutMode = savedMode == null ? LayoutMode.grid : (savedMode == 'grid' ? LayoutMode.grid : LayoutMode.list);
    });
    dev.log('加载保存的布局模式：${_currentLayoutMode.name}', name: '布局模式');
  }

  // 新增：保存布局模式到本地
  Future<void> _saveLayoutMode(LayoutMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('layout_mode', mode.name);
    dev.log('保存布局模式：${mode.name}', name: '布局模式');
  }

  Future<void> _loadLastSavePath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSavePath = prefs.getString('pdf_last_save_path');
    });
    dev.log('加载历史保存路径：${_lastSavePath ?? '无'}', name: 'PDF生成');
  }

  Future<void> _saveLastSavePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pdf_last_save_path', path);
    setState(() {
      _lastSavePath = path;
    });
    dev.log('保存历史路径：$path', name: 'PDF生成');
  }

  // 新增：切换布局模式（包含保存逻辑）
  void _toggleLayoutMode() {
    setState(() {
      _currentLayoutMode = _currentLayoutMode == LayoutMode.list
          ? LayoutMode.grid
          : LayoutMode.list;
    });
    // 切换后立即保存
    _saveLayoutMode(_currentLayoutMode);

    // 显示切换提示
    String modeText = _currentLayoutMode == LayoutMode.list ? '列表模式' : '网格模式（一排5个）';
    _showSnackBar('已切换为$modeText', isError: false);
  }

  // ========== 核心修复：重新实现任务统计逻辑 ==========
  void _calculateTaskStats() {
    if (_allApplyList.isEmpty) {
      setState(() {
        _totalCount = 0;
        _completedCount = 0;
        _inProgressCount = 0;
        _overdueCount = 0;
        _notStartedCount = 0;
        _pausedCount = 0;
        _cancelledCount = 0;
      });
      return;
    }

    // 先过滤掉已取消的任务（非管理员）
    List<ApplyModel> statsList = _allApplyList.where((apply) {
      if (_userRole == 'admin' && _showCancelledTasks) {
        return true; // 管理员且显示已取消：包含所有
      }
      return apply.overallStatus != 'cancelled'; // 非管理员：排除已取消
    }).toList();

    // 逐个统计（修复：增加状态值的容错判断）
    int completed = 0;
    int inProgress = 0;
    int overdue = 0;
    int notStarted = 0;
    int paused = 0;
    int cancelled = 0;

    for (var apply in _allApplyList) {
      String status = apply.overallStatus?.toLowerCase() ?? '';

      // 兼容不同的状态值写法
      if (status == 'completed' || status == '已完成') {
        completed++;
      } else if (status == 'in_progress' || status == 'inprogress' || status == '进行中') {
        inProgress++;
      } else if (status == 'overdue' || status == '逾期') {
        overdue++;
      } else if (status == 'not_started' || status == 'notstarted' || status == '未开始') {
        notStarted++;
      } else if (status == 'paused' || status == '暂停') {
        paused++;
      } else if (status == 'cancelled' || status == '已取消') {
        cancelled++;
      }
    }

    setState(() {
      _totalCount = statsList.length;
      _completedCount = completed;
      _inProgressCount = inProgress;
      _overdueCount = overdue;
      _notStartedCount = notStarted; // 修复：正确赋值未开始数量
      _pausedCount = paused;
      _cancelledCount = cancelled;
    });

    dev.log('统计完成：总=$_totalCount, 已完成=$_completedCount, 未开始=$_notStartedCount', name: '任务统计');
  }

  void _showPdfGenerateOptionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('选择PDF生成模式'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1. 生成负责人详细信息（一页1排4列）'),
              SizedBox(height: 8),
              Text('2. 不生成详细信息（一页5排6列）'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _generatePdfByMode(PdfGenerateMode.withDetailInfo);
              },
              child: const Text('选项1'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _generatePdfByMode(PdfGenerateMode.withoutDetailInfo);
              },
              child: const Text('选项2'),
            ),
          ],
        );
      },
    );
  }

  void _generatePdfByMode(PdfGenerateMode mode) {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    PdfGenerator.generateTaskPdf(
      taskList: _filteredApplyList,
      mode: mode,
      lastSavePath: _lastSavePath,
      startDate: _startDate,
      endDate: _endDate,
      searchKeyword: _searchController.text,
      onSuccess: (String filePath) {
        setState(() => _isGenerating = false);
        _saveLastSavePath(Directory(filePath).parent.path);
        dev.log('PDF生成成功，保存路径：$filePath', name: 'PDF生成');
        OpenFile.open(filePath);
      },
      onError: (String errorMsg) {
        setState(() => _isGenerating = false);
        _showSnackBar(
          errorMsg,
          isError: errorMsg.startsWith('❌') || errorMsg.startsWith('⚠️'),
        );
      },
    );
  }

  // ========== 核心修复：重新实现筛选逻辑 ==========
  void _filterList() {
    final searchKeyword = _searchController.text.trim().toLowerCase();
    // 显式复制列表，确保类型安全
    List<ApplyModel> tempList = List<ApplyModel>.from(_allApplyList);

    // 第一步：过滤已取消任务（非管理员）
    if (!(_userRole == 'admin' && _showCancelledTasks)) {
      tempList = tempList.where((apply) {
        String status = apply.overallStatus?.toLowerCase() ?? '';
        return status != 'cancelled' && status != '已取消';
      }).toList();
    }

    // 第二步：应用日期筛选 - 使用ISO时间解析
    if (_startDate != null) {
      final endDate = _endDate ?? DateTime.now();
      tempList = tempList.where((apply) {
        DateTime? applyDateTime = apply.applyDateTime;
        if (applyDateTime == null) return false;

        return applyDateTime.isAfter(_startDate!.subtract(const Duration(seconds: 1))) &&
            applyDateTime.isBefore(endDate.add(const Duration(seconds: 1)));
      }).toList();
    } else {
      tempList = tempList.where((apply) {
        DateTime? applyDateTime = apply.applyDateTime;
        if (applyDateTime == null) return false;
        return applyDateTime.isAfter(_oneMonthAgo);
      }).toList();
    }

    // 第三步：应用状态筛选（核心修复）
    if (_currentFilterStatus != FilterStatus.all) {
      tempList = tempList.where((apply) {
        String status = apply.overallStatus?.toLowerCase() ?? '';

        switch(_currentFilterStatus) {
          case FilterStatus.completed:
            return status == 'completed' || status == '已完成';
          case FilterStatus.inProgress:
            return status == 'in_progress' || status == 'inprogress' || status == '进行中';
          case FilterStatus.overdue:
            return status == 'overdue' || status == '逾期';
          case FilterStatus.notStarted: // 修复：未开始状态的判断
            return status == 'not_started' || status == 'notstarted' || status == '未开始';
          case FilterStatus.paused:
            return status == 'paused' || status == '暂停';
          case FilterStatus.cancelled:
            return status == 'cancelled' || status == '已取消';
          default:
            return true;
        }
      }).toList();
    }

    // 第四步：应用关键词搜索
    if (searchKeyword.isNotEmpty) {
      tempList = tempList.where((apply) {
        final customer = (apply.customer ?? '').toLowerCase();
        final business = (apply.business ?? '').toLowerCase();
        final applicant = (apply.applicant ?? '').toLowerCase();
        final leaderName = (apply.leaderName ?? '').toLowerCase();
        final hardwareHandlers = (apply.hardwareHandlers?.join('、') ?? '').toLowerCase();
        final softwareHandlers = (apply.softwareHandlers?.join('、') ?? '').toLowerCase();
        final testHandlers = (apply.testHandlers?.join('、') ?? '').toLowerCase();
        final overallStatus = (apply.overallStatus ?? '').toLowerCase();
        final overallStatusCn = (apply.overallStatusCn ?? '').toLowerCase();
        final overdueDaysStr = (apply.overdueDays ?? 0).toString();
        final progressStr = (apply.completionProgress ?? 0 * 100).toStringAsFixed(0);

        return customer.contains(searchKeyword) ||
            business.contains(searchKeyword) ||
            applicant.contains(searchKeyword) ||
            leaderName.contains(searchKeyword) ||
            hardwareHandlers.contains(searchKeyword) ||
            softwareHandlers.contains(searchKeyword) ||
            testHandlers.contains(searchKeyword) ||
            overallStatus.contains(searchKeyword) ||
            overallStatusCn.contains(searchKeyword) ||
            overdueDaysStr.contains(searchKeyword) ||
            progressStr.contains(searchKeyword);
      }).toList();
    }

    setState(() {
      _filteredApplyList = tempList;
    });

    dev.log('筛选完成：状态=${_currentFilterStatus.name}，结果数=${tempList.length}', name: '任务筛选');
  }

  Future<void> _selectStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate ?? _oneMonthAgo,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF0088FF),
            colorScheme: const ColorScheme.light(primary: Color(0xFF0088FF)),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _startDate = pickedDate;
      });
      _filterList();
    }
  }

  Future<void> _selectEndDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF0088FF),
            colorScheme: const ColorScheme.light(primary: Color(0xFF0088FF)),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _endDate = pickedDate;
      });
      _filterList();
    }
  }

  void _resetDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
    });
    _filterList();
    _showSnackBar('已重置时间筛选为近一个月', isError: false);
  }

  void _showSnackBar(String message, {required bool isError, bool showAction = false, VoidCallback? onActionPressed}) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: isError ? Colors.redAccent : Colors.greenAccent,
      duration: showAction ? const Duration(seconds: 10) : const Duration(seconds: 3),
      action: showAction && onActionPressed != null
          ? SnackBarAction(
        label: '打开文件',
        textColor: Colors.white,
        onPressed: onActionPressed,
      )
          : null,
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // 替换原有 _fetchAllApplyList 方法
  Future<void> _fetchAllApplyList() async {
    try {
      dev.log('开始获取所有申请列表数据（全量）', name: '数据加载');
      final prefs = await SharedPreferences.getInstance();
      final String userToken = prefs.getString('token') ?? '';
      final String userId = prefs.getString('userId') ?? '';

      if (userToken.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMsg = '用户Token为空，请先登录';
          });
        }
        dev.log('用户Token为空，无法请求全量数据', name: '数据加载');
        return;
      }

      String requestUrl = '$baseUrl/api/public/all-completed-applies';

      dev.log('请求数据：$requestUrl', name: '数据加载');

      final response = await http.get(
        Uri.parse(requestUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userToken',
        },
      ).timeout(const Duration(seconds: 15));

      dev.log('数据请求响应状态码：${response.statusCode}', name: '数据加载');
      if (response.statusCode != 200) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMsg = '获取数据失败，状态码：${response.statusCode}';
          });
        }
        dev.log('数据请求响应体：${response.body}', name: '数据加载');
        return;
      }

      final data = jsonDecode(response.body);
      dev.log('数据请求解析结果：$data', name: '数据加载');

      if (data['success'] != true) {
        String errorMsg = data['msg'] ?? '获取申请单记录失败';
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMsg = errorMsg;
          });
        }
        dev.log('数据请求失败：$errorMsg', name: '数据加载');
        return;
      }

      List<ApplyModel> list = [];
      if (data['data'] != null && data['data'] is List) {
        dev.log('后端返回数据条数：${data['data'].length}', name: '数据加载');
        for (var item in data['data']) {
          try {
            ApplyModel model = ApplyModel.fromJson(item);
            // 打印每条数据的状态，便于调试
            dev.log('申请单${model.customer}：状态=${model.overallStatus}', name: '数据解析');
            list.add(model);
          } catch (e) {
            dev.log('单个申请单数据解析失败：$e，数据：$item', name: '数据加载');
            continue;
          }
        }
      }

      // 按申请时间降序排序
      list.sort((a, b) {
        if (a.applyDateTime == null && b.applyDateTime == null) return 0;
        if (a.applyDateTime == null) return 1;
        if (b.applyDateTime == null) return -1;
        return b.applyDateTime!.compareTo(a.applyDateTime!);
      });

      dev.log('前端解析到${list.length}条申请数据（已排序）', name: '数据加载');

      if (mounted) {
        setState(() {
          _allApplyList = list;
          _isLoading = false;
        });
        _calculateTaskStats(); // 数据加载后立即计算统计
        _filterList(); // 应用默认筛选
      }
    } catch (e) {
      dev.log('数据加载失败：$e', name: '数据加载', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = '网络错误或请求超时：$e';
        });
      }
    }
  }

  // ========== 修改：构建统计数据展示栏（添加点击事件） ==========
  Widget _buildStatsBar() {
    // 定义统计项数据（强类型，修复类型错误）
    final stats = [
      StatItem(label: '总任务', value: _totalCount.toString(), color: Colors.black87, status: FilterStatus.all),
      StatItem(label: '已完成', value: _completedCount.toString(), color: Colors.green, status: FilterStatus.completed),
      StatItem(label: '进行中', value: _inProgressCount.toString(), color: Colors.blue, status: FilterStatus.inProgress),
      StatItem(label: '逾期', value: _overdueCount.toString(), color: Colors.redAccent, status: FilterStatus.overdue),
      StatItem(label: '未开始', value: _notStartedCount.toString(), color: Colors.grey, status: FilterStatus.notStarted),
      StatItem(label: '暂停', value: _pausedCount.toString(), color: Colors.yellow[700]!, status: FilterStatus.paused),
      if (_userRole == 'admin')
        StatItem(label: '已取消', value: _cancelledCount.toString(), color: Colors.purple, status: FilterStatus.cancelled),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E6EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(stats.length, (index) {
          final stat = stats[index];
          return _buildStatItem(
            label: stat.label,
            value: stat.value,
            color: stat.color,
            isSelected: _selectedStatIndex == index,
            onTap: () => _filterByStatus(stat.status, index),
          );
        }),
      ),
    );
  }

  // ========== 修改：构建单个统计项（添加点击事件和选中状态） ==========
  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: color.withOpacity(0.3), width: 1) : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? color : const Color(0xFF86909C),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索',
              hintStyle: const TextStyle(color: Color(0xFF86909C), fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF86909C)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, color: Color(0xFF86909C)),
                onPressed: () {
                  _searchController.clear();
                },
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
            onSubmitted: (value) {
              _filterList();
            },
          ),
        ),
        // 时间筛选栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectStartDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E6EB)),
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF86909C), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _startDate != null
                              ? _dateFormatter.format(_startDate!)
                              : '开始日期 (近30天)',
                          style: TextStyle(
                            color: _startDate != null ? const Color(0xFF4E5969) : const Color(0xFF86909C),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _selectEndDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E6EB)),
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF86909C), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _endDate != null
                              ? _dateFormatter.format(_endDate!)
                              : '结束日期 (今天)',
                          style: TextStyle(
                            color: _endDate != null ? const Color(0xFF4E5969) : const Color(0xFF86909C),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF0088FF), size: 20),
                onPressed: _resetDateFilter,
                tooltip: '重置时间筛选',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========== 修改：筛选状态方法，补全已取消状态处理 ==========
  void _filterByStatus(FilterStatus status, int index) {
    setState(() {
      _currentFilterStatus = status;
      _selectedStatIndex = index;
    });
    _filterList();

    // 显示筛选提示
    String statusText = '';
    switch(status) {
      case FilterStatus.all:
        statusText = '全部任务';
        break;
      case FilterStatus.completed:
        statusText = '已完成任务';
        break;
      case FilterStatus.inProgress:
        statusText = '进行中任务';
        break;
      case FilterStatus.overdue:
        statusText = '逾期任务';
        break;
      case FilterStatus.notStarted:
        statusText = '未开始任务';
        break;
      case FilterStatus.paused:
        statusText = '暂停中任务';
        break;
      case FilterStatus.cancelled:
        statusText = '已取消任务';
        break;
    }
    _showSnackBar('已筛选：$statusText', isError: false);
  }

  // 辅助方法：处理负责人列表显示 - 移除截断逻辑
  String getHandlersText(List<String>? handlers) {
    if (handlers == null || handlers.isEmpty) return '未分配';
    return handlers.join('、');
  }

  // 原有列表模式的任务项 - 优化负责人显示，确保完整展示
  Widget _buildTaskListItem(ApplyModel apply) {
    // 逾期提示文本（确保显示）
    String overdueText = (apply.overdueDays ?? 0) > 0 ? '逾期${apply.overdueDays}天' : '';
    // 进度文本
    String progressText = '${((apply.completionProgress ?? 0) * 100).toStringAsFixed(0)}%';
    // 格式化预计完成时间
    String formattedExpectedTime = formatExpectedTime(apply.expectedCompletionTime);

    // 处理负责人显示 - 完整显示所有负责人
    String softwareHandlersText = getHandlersText(apply.softwareHandlers);
    String hardwareHandlersText = getHandlersText(apply.hardwareHandlers);
    String testHandlersText = getHandlersText(apply.testHandlers);

    return InkWell(
      onTap: () async {
        // 等待详情页返回结果
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ApplyDetailPage(applyModel: apply),
          ),
        );

        // 判断是否需要刷新列表
        if (result == 'need_refresh') {
          _fetchAllApplyList();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: (apply.overallStatus == 'overdue' || apply.overallStatus == '逾期')
              ? Colors.red.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: (apply.overallStatus == 'overdue' || apply.overallStatus == '逾期')
                ? Colors.redAccent
                : const Color(0xFFE5E6EB),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  apply.customer ?? '未知客户',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF001529),
                  ),
                ),
                Row(
                  children: [
                    if (overdueText.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          overdueText,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: apply.overallStatusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: apply.overallStatusColor, width: 1),
                      ),
                      child: Text(
                        apply.overallStatusCn ?? '未知状态',
                        style: TextStyle(
                          color: apply.overallStatusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '业务：${apply.business ?? '未知'}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF4E5969)),
                ),
                const SizedBox(width: 12),
                Text(
                  '申请人：${apply.applicant ?? '未知'}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF4E5969)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '软件负责人：$softwareHandlersText',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF4E5969)),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '硬件负责人：$hardwareHandlersText',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF4E5969)),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '测试负责人：$testHandlersText',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF4E5969)),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '预计完成：$formattedExpectedTime',
                style: TextStyle(
                  fontSize: 12,
                  color: (apply.overallStatus == 'overdue' || apply.overallStatus == '逾期') ? Colors.redAccent : Color(0xFF86909C),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '完成进度：',
                      style: TextStyle(fontSize: 12, color: Color(0xFF86909C)),
                    ),
                    Text(
                      progressText,
                      style: TextStyle(
                        fontSize: 12,
                        color: (apply.completionProgress ?? 0) == 1.0
                            ? Colors.green
                            : (apply.completionProgress ?? 0) > 0
                            ? Colors.orangeAccent
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: apply.completionProgress ?? 0,
                  backgroundColor: const Color(0xFFE5E6EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    (apply.completionProgress ?? 0) == 1.0
                        ? Colors.green
                        : (apply.completionProgress ?? 0) > 0
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 优化：网格模式的任务卡片 - 完整显示负责人信息
  Widget _buildTaskGridItem(ApplyModel apply) {
    // 处理负责人显示 - 完整显示所有负责人
    String softwareHandlersText = getHandlersText(apply.softwareHandlers);
    String hardwareHandlersText = getHandlersText(apply.hardwareHandlers);
    String testHandlersText = getHandlersText(apply.testHandlers);

    // 客户名称和业务仅做必要截断，负责人信息完整显示
    String shortCustomer = (apply.customer ?? '未知客户').length > 10 ? '${(apply.customer ?? '未知客户').substring(0, 10)}...' : (apply.customer ?? '未知客户');
    String shortBusiness = (apply.business ?? '未知业务').length > 12 ? '${(apply.business ?? '未知业务').substring(0, 12)}...' : (apply.business ?? '未知业务');
    String shortApplicant = (apply.applicant ?? '未知').length > 6 ? '${(apply.applicant ?? '未知').substring(0, 6)}' : (apply.applicant ?? '未知');

    String overdueText = (apply.overdueDays ?? 0) > 0 ? '逾期${apply.overdueDays}天' : '';
    String progressText = '${((apply.completionProgress ?? 0) * 100).toStringAsFixed(0)}%';
    String formattedExpectedTime = formatExpectedTime(apply.expectedCompletionTime);
    String shortExpectedTime = formattedExpectedTime.length > 8 ? formattedExpectedTime : formattedExpectedTime;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ApplyDetailPage(applyModel: apply),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: (apply.overallStatus == 'overdue' || apply.overallStatus == '逾期')
              ? Colors.red.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: (apply.overallStatus == 'overdue' || apply.overallStatus == '逾期')
                ? Colors.redAccent.withOpacity(0.3)
                : const Color(0xFFE5E6EB),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    shortCustomer,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF001529),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (overdueText.isNotEmpty)
                  Text(
                    overdueText,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: (apply.overallStatus == 'cancelled' || apply.overallStatus == '已取消')
                    ? Colors.purple.withOpacity(0.1)
                    : apply.overallStatusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: (apply.overallStatus == 'cancelled' || apply.overallStatus == '已取消')
                      ? Colors.purple.withOpacity(0.5)
                      : apply.overallStatusColor.withOpacity(0.5),
                  width: 0.5,
                ),
              ),
              child: Text(
                (apply.overallStatus == 'cancelled' || apply.overallStatus == '已取消')
                    ? '已取消'
                    : (apply.overallStatusCn ?? '未知状态'),
                style: TextStyle(
                  color: (apply.overallStatus == 'cancelled' || apply.overallStatus == '已取消')
                      ? Colors.purple
                      : apply.overallStatusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '业务：$shortBusiness',
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF4E5969),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              '软件：$softwareHandlersText',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF4E5969),
              ),
              maxLines: 3,
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
            const SizedBox(height: 1),
            Text(
              '硬件：$hardwareHandlersText',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF4E5969),
              ),
              maxLines: 2,
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
            const SizedBox(height: 1),
            Text(
              '测试：$testHandlersText',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF4E5969),
              ),
              maxLines: 2,
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
            const SizedBox(height: 1),
            Text(
              '预计：$shortExpectedTime',
              style: TextStyle(
                fontSize: 12,
                color: (apply.overallStatus == 'overdue' || apply.overallStatus == '逾期') ? Colors.redAccent : Color(0xFF86909C),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '进度：',
                      style: TextStyle(fontSize: 12, color: Color(0xFF86909C)),
                    ),
                    Text(
                      progressText,
                      style: TextStyle(
                        fontSize: 8,
                        color: (apply.completionProgress ?? 0) == 1.0
                            ? Colors.green
                            : (apply.completionProgress ?? 0) > 0
                            ? Colors.blue
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                LinearProgressIndicator(
                  value: apply.completionProgress ?? 0,
                  backgroundColor: const Color(0xFFE5E6EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    (apply.completionProgress ?? 0) == 1.0
                        ? Colors.green
                        : (apply.completionProgress ?? 0) > 0
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  minHeight: 2,
                  borderRadius: BorderRadius.circular(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 新增：打开申请表单弹窗
  void _openApplyForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF2F3F5), width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "提交申请",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF001529),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF86909C)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
            ),
            const Expanded(child: ApplyFormPage()),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        backgroundColor: const Color(0xFF0088FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_ind, color: Colors.white, size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LeaderTodoApplyListPage(),
                ),
              );
            },
            tooltip: '确认负责人',
            disabledColor: Colors.grey,
            splashRadius: 24,
            padding: const EdgeInsets.all(8),
          ),
          if (_userRole == 'admin')
            Switch(
              value: _showCancelledTasks,
              onChanged: (value) {
                setState(() {
                  _showCancelledTasks = value;
                });
                _filterList();
                _showSnackBar(
                    value ? '已显示已取消的任务' : '已隐藏已取消的任务',
                    isError: false
                );
              },
              activeColor: Colors.white,
              activeTrackColor: Colors.greenAccent,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () {
              _openApplyForm(context);
            },
            tooltip: '申请',
            disabledColor: Colors.grey,
          ),
          IconButton(
            icon: Icon(
              _currentLayoutMode == LayoutMode.list
                  ? Icons.grid_view
                  : Icons.list,
              color: Colors.white,
            ),
            onPressed: _toggleLayoutMode,
            tooltip: _currentLayoutMode == LayoutMode.list
                ? '切换为网格模式'
                : '切换为列表模式',
          ),
          IconButton(
            icon: _isGenerating
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Icon(Icons.save_alt),
            onPressed: _isGenerating ? null : _showPdfGenerateOptionDialog,
            tooltip: '生成PDF文件',
            disabledColor: Colors.grey,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsBar(),
          _buildFilterBar(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0088FF)));
    }

    if (_errorMsg.isNotEmpty) {
      return Center(
        child: Text(
          _errorMsg,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    }

    if (_filteredApplyList.isEmpty) {
      String emptyText = '';
      switch(_currentFilterStatus) {
        case FilterStatus.all:
          emptyText = _startDate != null
              ? '暂无该时间段和关键词的匹配数据'
              : '暂无近一个月和关键词的匹配数据';
          break;
        case FilterStatus.completed:
          emptyText = '暂无已完成的任务数据';
          break;
        case FilterStatus.inProgress:
          emptyText = '暂无进行中的任务数据';
          break;
        case FilterStatus.overdue:
          emptyText = '暂无逾期的任务数据';
          break;
        case FilterStatus.notStarted:
          emptyText = '暂无未开始的任务数据';
          break;
        case FilterStatus.paused:
          emptyText = '暂无暂停中的任务数据';
          break;
        case FilterStatus.cancelled:
          emptyText = '暂无已取消的任务数据';
          break;
      }

      return Center(
        child: Text(
          emptyText,
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    if (_currentLayoutMode == LayoutMode.list) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredApplyList.length,
        itemBuilder: (context, index) {
          final apply = _filteredApplyList[index];
          return _buildTaskListItem(apply);
        },
      );
    } else {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 230,
          crossAxisSpacing: 3,
          mainAxisSpacing: 4,
          childAspectRatio: 0.85,
        ),
        itemCount: _filteredApplyList.length,
        itemBuilder: (context, index) {
          final apply = _filteredApplyList[index];
          return _buildTaskGridItem(apply);
        },
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}