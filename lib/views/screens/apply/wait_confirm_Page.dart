import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;
import 'package:workflow/constants/api_constants.dart';
import 'apply_todo_detail_page.dart';
import 'apply_models.dart';

// -------------- 组长待办申请列表页 --------------
class LeaderTodoApplyListPage extends StatefulWidget {
  const LeaderTodoApplyListPage({super.key});

  @override
  State<LeaderTodoApplyListPage> createState() => _LeaderTodoListPageState();
}

class _LeaderTodoListPageState extends State<LeaderTodoApplyListPage> {
  List<ApplyTodoModel> _originalTodoList = [];
  List<ApplyTodoModel> _filteredTodoList = [];
  bool _isLoading = true;
  String _errorMsg = '';
  bool _isRequesting = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMyTodoTasks();
    _searchController.addListener(_filterTodoList);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 同时按客户名称和申请人筛选列表
  void _filterTodoList() {
    final String searchKeyword = _searchController.text.trim().toLowerCase();
    if (searchKeyword.isEmpty) {
      setState(() {
        _filteredTodoList = List.from(_originalTodoList);
      });
      return;
    }
    final filtered = _originalTodoList.where((todo) {
      bool matchCustomer = todo.customer.toLowerCase().contains(searchKeyword);
      bool matchApplicant = todo.applicant.toLowerCase().contains(searchKeyword);
      return matchCustomer || matchApplicant;
    }).toList();
    setState(() {
      _filteredTodoList = filtered;
    });
  }

  // 获取当前组长的待确认申请单（添加状态过滤逻辑）
  Future<void> _fetchMyTodoTasks() async {
    dev.log('========== 开始获取用户待办任务 ==========', name: 'TodoTaskPage._fetchMyTodoTasks');
    if (_isRequesting) {
      dev.log('待办任务请求已在进行中，忽略重复调用', name: 'TodoTaskPage._fetchMyTodoTasks');
      return;
    }

    setState(() {
      _isRequesting = true;
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      // 1. 获取 Token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      dev.log('从本地缓存获取Token：$token', name: 'TodoTaskPage._fetchMyTodoTasks');
      final requestUrl = '$baseUrl/api/public/leader-todo-applies';
      dev.log('请求待办任务接口：$requestUrl', name: 'TodoTaskPage._fetchMyTodoTasks');

      if (token.isEmpty) {
        throw Exception('未获取到登录信息，请重新登录');
      }

      // 2. 发送HTTP请求
      final response = await http.get(
        Uri.parse(requestUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // 3. 处理响应
      dev.log('待办任务接口响应状态码：${response.statusCode}', name: 'TodoTaskPage._fetchMyTodoTasks');
      dev.log('待办任务接口响应体：${response.body}', name: 'TodoTaskPage._fetchMyTodoTasks');
      final result = json.decode(response.body);

      if (response.statusCode == 200 && result['success'] == true) {
        dev.log('待办任务请求成功，开始解析数据', name: 'TodoTaskPage._fetchMyTodoTasks');
        List<ApplyTodoModel> todoList = [];
        if (result['data'] is List) {
          for (var item in result['data']) {
            todoList.add(ApplyTodoModel.fromJson(item));
          }
        }

        // ========== 核心修改：添加状态过滤 ==========
        // 过滤掉已完成(completed)和已取消/暂停(pause/paused)的任务
        todoList = todoList.where((todo) {
          // 需要排除的状态列表
          final excludedStatus = ['completed', 'cancelled'];
          // 只保留不在排除列表中的任务
          return !excludedStatus.contains(todo.overallStatus);
        }).toList();

        // 按applyTime降序排列，最新的申请单排在最前面
        todoList.sort((a, b) => b.applyTime.compareTo(a.applyTime));

        if (mounted) {
          setState(() {
            _originalTodoList = todoList;
            _filteredTodoList = todoList;
            _isLoading = false;
            _isRequesting = false;
          });
        }
        dev.log('待办任务解析完成，共${todoList.length}条数据', name: 'TodoTaskPage._fetchMyTodoTasks');
      } else {
        dev.log('待办任务请求失败，错误信息：${result['msg']}', name: 'TodoTaskPage._fetchMyTodoTasks');
        if (mounted) {
          setState(() {
            _errorMsg = result['msg'] ?? '查询待办任务失败';
            _isLoading = false;
            _isRequesting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('获取待办任务失败：${result['msg']}')),
          );
        }
      }
    } catch (e) {
      dev.log('获取待办任务异常：$e', name: 'TodoTaskPage._fetchMyTodoTasks', error: e);
      if (mounted) {
        setState(() {
          _errorMsg = '网络异常或服务器错误：$e';
          _isLoading = false;
          _isRequesting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取待办任务失败：$e')),
        );
      }
    }
    dev.log('========== 获取用户待办任务结束 ==========', name: 'TodoTaskPage._fetchMyTodoTasks');
  }

  // 跳转到申请单详情页
  void _navigateToDetailPage(ApplyTodoModel todo) {
    // 1. 模型转换：ApplyTodoModel → DetailApplyTodoModel（详情页专属模型）
    final DetailApplyTodoModel detailTodo = DetailApplyTodoModel(
      id: todo.id,
      customer: todo.customer,
      business: todo.business,
      applicant: todo.applicant,
      applyTime: todo.applyTime,
      leaderName: todo.leaderName,
      expectedCompletionTime: todo.expectedCompletionTime,
      // 子模型转换：ResponsiblePerson → DetailTaskPerson
      responsibles: todo.responsibles.map((resp) {
        return DetailTaskPerson(
          role: resp.role,
          userId: resp.userId,
          username: resp.username,
          personalStatus: resp.personalStatus,
          taskContent: resp.taskContent,
          startTime: resp.startTime,
          completeTime: resp.completeTime,
        );
      }).toList(),
      overallStatus: todo.overallStatus, // 补充传递整体状态
      applyFiles: todo.applyFiles, // 补充传递文件列表
    );

    // 2. 跳转详情页，传递转换后的模型
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyTodoDetailPage(
          todo: detailTodo,
          onResponsibleAdded: _fetchMyTodoTasks,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务列表'),
        backgroundColor: const Color(0xFF0088FF),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMyTodoTasks,
        color: const Color(0xFF0088FF),
        child: _buildPageContent(),
      ),
    );
  }

  // 构建页面内容
  Widget _buildPageContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0088FF)),
      );
    }

    if (_errorMsg.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _errorMsg,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '输入客户名称或申请人搜索',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF86909C)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFF2F3F5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFF2F3F5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0088FF)),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),

        // 列表
        Expanded(
          child: _filteredTodoList.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  '暂无匹配的待办任务',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredTodoList.length,
            itemBuilder: (context, index) {
              final todo = _filteredTodoList[index];

              return InkWell(
                onTap: () => _navigateToDetailPage(todo),
                splashColor: const Color(0xFF0088FF).withOpacity(0.1),
                highlightColor: const Color(0xFF0088FF).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '客户：${todo.customer}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '申请人：${todo.applicant}',
                              style: const TextStyle(
                                color: Color(0xFF86909C),
                                fontSize: 14,
                              ),
                            ),
                          ]),
                      Text(
                        '任务状态：${todo.overallStatusChinese}',
                        style: TextStyle(
                          color: todo.overallStatusColor,
                          fontSize: 14,
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
    );
  }
}