import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;
import 'dart:async';
import 'package:workflow/constants/api_constants.dart';
// 新增导入
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:mime/mime.dart';
// 新增：剪贴板导入
import 'package:flutter/services.dart';

// 申请表单页面（移除组长填写，直接提交）
class ApplyFormPage extends StatefulWidget {
  const ApplyFormPage({super.key});

  @override
  State<ApplyFormPage> createState() => _ApplyFormPageState();
}

class _ApplyFormPageState extends State<ApplyFormPage> {
  // 基础表单控制器（移除组长相关控制器）
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _businessController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();
  final TextEditingController _applicantController = TextEditingController();
  // 新增：自定义内容控制器（支持文本和链接）
  final TextEditingController _customContentController = TextEditingController();

  // ========== 新增：业务下拉选择相关状态 ==========
  final List<String> _businessOptions = ['陈梓锋', '高垣成', '刘真','喻培忠','吴建桓','潘志远','刘建龙','王子柱','陈东','石跃江','张浩然','章佳凯'];
  // 选中的业务选项（用于下拉选中态标记）
  String? _selectedBusiness;
  // ==============================================

  // 移除组长相关变量
  // 日期选择相关
  DateTime? _selectedDeadline;
  late final ThemeData _datePickerTheme;
  bool _isDatePickerShowing = false;

  // 提交按钮加载状态
  bool _isSubmitting = false;

  // 新增：文件上传相关
  bool _isUploadingFile = false;
  File? _selectedFile;
  String? _tempFileUrl; // 临时文件URL
  String? _fileName; // 上传的文件名
  String? _fileType; // 文件类型

  // 当前登录用户信息
  String _currentUserId = '';
  String _currentUsername = '';

  @override
  void initState() {
    super.initState();
    dev.log('申请表单页面初始化开始', name: 'ApplyFormPage.initState');
    // 初始化日期选择器主题
    _datePickerTheme = ThemeData.light().copyWith(
      colorScheme: const ColorScheme.light(primary: Color(0xFF0088FF)),
      buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
    );
    // 获取当前登录用户信息
    _loadCurrentUserInfo();
  }

  // 加载当前登录用户信息（自动填充申请人）
  Future<void> _loadCurrentUserInfo() async {
    dev.log('========== 开始加载当前登录用户信息 ==========', name: 'ApplyFormPage._loadCurrentUserInfo');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('userId') ?? '';
      _currentUsername = prefs.getString('username') ?? '';
      _applicantController.text = _currentUsername;
    });
    dev.log('当前登录用户信息加载完成：ID=$_currentUserId，用户名=$_currentUsername', name: 'ApplyFormPage._loadCurrentUserInfo');
  }

  // 日期选择方法（保持不变）
  Future<void> _selectDeadline() async {
    dev.log('========== 开始选择预计完成日期 ==========', name: 'ApplyFormPage._selectDeadline');
    if (_isDatePickerShowing) {
      dev.log('日期选择器已在显示中，忽略重复调用', name: 'ApplyFormPage._selectDeadline');
      return;
    }
    setState(() => _isDatePickerShowing = true);

    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2027),
        builder: (context, child) => Theme(data: _datePickerTheme, child: child!),
        initialEntryMode: DatePickerEntryMode.calendarOnly,
      );

      if (picked != null) {
        dev.log('用户选择了日期：$picked', name: 'ApplyFormPage._selectDeadline');
        setState(() {
          _selectedDeadline = picked;
          _deadlineController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        });
      } else {
        dev.log('用户取消了日期选择', name: 'ApplyFormPage._selectDeadline');
      }
    } finally {
      setState(() => _isDatePickerShowing = false);
    }
    dev.log('========== 日期选择流程结束 ==========', name: 'ApplyFormPage._selectDeadline');
  }

  // 新增：清空自定义内容
  void _clearCustomContent() {
    setState(() {
      _customContentController.clear();
    });
  }

  // 新增：选择并上传文件
  Future<void> _selectAndUploadFile() async {
    if (_isUploadingFile) return;

    try {
      // 选择文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null) return;

      File file = File(result.files.single.path!);
      _selectedFile = file;
      _fileName = result.files.single.name;
      _fileType = lookupMimeType(file.path) ?? 'application/octet-stream';

      setState(() => _isUploadingFile = true);

      // 获取token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // 创建multipart请求上传临时文件
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/public/upload-temp-file'),
      );

      // 添加请求头
      request.headers['Authorization'] = 'Bearer $token';

      // 添加文件
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: _fileName,
          contentType: http.MediaType.parse(_fileType!),
        ),
      );

      // 发送请求
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var data = jsonDecode(responseData);

      if (response.statusCode == 200 && data['success']) {
        // 保存临时文件URL
        setState(() {
          _tempFileUrl = data['data']['fileUrl'];
        });
        _showSnackBar('文件上传成功');
      } else {
        _showSnackBar('文件上传失败：${data['msg'] ?? '未知错误'}', isError: true);
      }
    } catch (e) {
      dev.log('文件上传异常：$e', name: 'ApplyFormPage._selectAndUploadFile');
      _showSnackBar('文件上传失败：$e', isError: true);
    } finally {
      setState(() => _isUploadingFile = false);
    }
  }

  // 新增：删除临时文件
  Future<void> _deleteTempFile() async {
    if (_tempFileUrl == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/api/public/delete-temp-file'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'fileUrl': _tempFileUrl,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success']) {
        setState(() {
          _tempFileUrl = null;
          _fileName = null;
          _selectedFile = null;
          _fileType = null;
        });
        _showSnackBar('文件已删除');
      } else {
        _showSnackBar('文件删除失败：${data['msg']}', isError: true);
      }
    } catch (e) {
      dev.log('删除临时文件异常：$e', name: 'ApplyFormPage._deleteTempFile');
      _showSnackBar('文件删除失败：$e', isError: true);
    }
  }

  // 提交申请方法（修改：增加文件关联逻辑和自定义内容）
  Future<void> _submitApply() async {
    // 防止重复提交
    if (_isSubmitting) return;
    dev.log('========== 开始提交申请表单 ==========', name: 'ApplyFormPage._submitApply');
    setState(() => _isSubmitting = true);

    // 1. 表单校验（移除组长合法性校验）
    final customer = _customerController.text.trim();
    final business = _businessController.text.trim();
    final deadline = _deadlineController.text.trim();
    final applicant = _applicantController.text.trim();
    // 新增：获取自定义内容
    final customContent = _customContentController.text.trim();

    if (customer.isEmpty ||
        business.isEmpty ||
        applicant.isEmpty ||
        deadline.isEmpty) {
      dev.log('表单校验失败：存在空字段', name: 'ApplyFormPage._submitApply');
      _showSnackBar('请填写完整信息', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }

    // 2. 获取当前登录用户ID
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    if (userId == null) {
      dev.log('用户未登录，无法提交申请', name: 'ApplyFormPage._submitApply');
      _showSnackBar('请先登录', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }

    // 3. 构造请求体（增加文件信息和自定义内容）
    final Map<String, dynamic> applyData = {
      'userId': userId,
      'applicant': applicant,
      'customer': customer,
      'business': business,
      'expectedCompletionTime': deadline,
      // 新增：自定义内容
      'customContent': customContent,
      // 新增：文件信息（如果有）
      'fileUrl': _tempFileUrl,
      'fileName': _fileName,
      'fileType': _fileType,
    };

    try {
      // 4. 调用提交接口
      final token = prefs.getString('token') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/api/submit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(applyData),
      );

      final data = jsonDecode(response.body);

      if (data['success']) {
        _showSnackBar('申请提交成功');
        // 提交成功，关闭弹窗并返回刷新指令
        Navigator.pop(context, 'need_refresh');
      } else {
        _showSnackBar(data['msg'] ?? '提交失败', isError: true);
        // 申请失败，删除临时文件
        if (_tempFileUrl != null) {
          await _deleteTempFile();
        }
      }
    } catch (e) {
      dev.log('提交申请异常：$e', name: 'ApplyFormPage._submitApply', error: e);
      _showSnackBar('提交失败：$e', isError: true);
      // 异常失败，删除临时文件
      if (_tempFileUrl != null) {
        await _deleteTempFile();
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // 新增：显示提示消息
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 3 : 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 统一输入框样式（保持不变）
    InputDecoration _buildInputDecoration({
      required String labelText,
      required String hintText,
      Widget? suffixIcon,
      bool enabled = true,
    }) {
      dev.log('构建输入框样式，标签：$labelText，提示文字：$hintText', name: 'ApplyFormPage._buildInputDecoration');
      return InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: const TextStyle(color: Color(0xFF86909C), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE5E6EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0088FF), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE5E6EB)),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        suffixIcon: suffixIcon,
        isDense: true,
        enabled: enabled,
      );
    }

    // 清空输入框的通用方法（保持不变）
    void _clearTextController(TextEditingController controller) {
      String controllerName = '';
      if (controller == _customerController) {
        controllerName = '客户';
      } else if (controller == _businessController) {
        controllerName = '业务';
        // 清空业务输入框时，重置选中的选项
        setState(() => _selectedBusiness = null);
      } else if (controller == _deadlineController) {
        controllerName = '预计完成时间';
      } else if (controller == _applicantController) {
        controllerName = '申请人';
      } else if (controller == _customContentController) { // 新增
        controllerName = '内容';
      }
      dev.log('清空$controllerName输入框，当前值：${controller.text}', name: 'ApplyFormPage._clearTextController');
      setState(() {
        if (controller == _applicantController) {
          controller.text = _currentUsername;
        } else {
          controller.clear();
        }
      });
      dev.log('$controllerName输入框已处理，新值：${controller.text}', name: 'ApplyFormPage._clearTextController');
    }

    dev.log('开始构建申请表单页面UI', name: 'ApplyFormPage.build');
    return RepaintBoundary(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 申请人（只读，自动填充）
            TextField(
              controller: _applicantController,
              readOnly: true,
              decoration: _buildInputDecoration(
                labelText: '申请人',
                hintText: '当前登录用户',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.person, color: Color(0xFF0088FF), size: 20),
                  onPressed: () => _clearTextController(_applicantController),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40),
                ),
              ),
              autocorrect: false,
              enableSuggestions: false,
            ),
            const SizedBox(height: 12),

            // 2. 客户
            TextField(
              controller: _customerController,
              decoration: _buildInputDecoration(
                labelText: '客户',
                hintText: '输入客户名称',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF86909C), size: 20),
                  onPressed: () => _clearTextController(_customerController),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40),
                ),
              ),
              autocorrect: false,
              enableSuggestions: false,
            ),
            const SizedBox(height: 12),

            // ========== 核心修复：业务字段下拉选择框 ==========
            Autocomplete<String>(
              // 选中选项时的回调：填充输入框+标记选中态
              onSelected: (String selectedOption) {
                setState(() {
                  _selectedBusiness = selectedOption;
                  // 仅在选择选项时同步到业务控制器
                  _businessController.text = selectedOption;
                });
              },
              // 选项过滤逻辑：输入任意字符，仅显示包含该字符的选项（不区分大小写）
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _businessOptions;
                }
                final String query = textEditingValue.text.toLowerCase();
                return _businessOptions
                    .where((option) => option.toLowerCase().contains(query));
              },
              // 自定义输入框样式：和原表单样式完全统一
              fieldViewBuilder: (BuildContext context, TextEditingController fieldController,
                  FocusNode focusNode, VoidCallback onFieldSubmitted) {
                // 仅初始化时同步业务控制器的内容
                if (fieldController.text.isEmpty && _businessController.text.isNotEmpty) {
                  fieldController.text = _businessController.text;
                }
                // 仅在输入内容变化时，更新业务控制器（单向同步，避免循环）
                fieldController.addListener(() {
                  if (fieldController.text != _businessController.text) {
                    _businessController.text = fieldController.text;
                    // 只有输入内容与选中项完全不一致时，才重置选中态
                    if (_selectedBusiness != null && fieldController.text != _selectedBusiness) {
                      setState(() => _selectedBusiness = null);
                    }
                  }
                });
                return TextField(
                  controller: fieldController,
                  focusNode: focusNode,
                  decoration: _buildInputDecoration(
                    labelText: '业务',
                    hintText: '输入/选择',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFF86909C), size: 20),
                      onPressed: () {
                        _clearTextController(_businessController);
                        // 清空时同步清空fieldController
                        fieldController.clear();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40),
                    ),
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                );
              },
              // 自定义下拉选项样式：和原表单视觉统一，带选中态
              optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: MediaQuery.of(context).size.width - 32,
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String option = options.elementAt(index);
                          return ListTile(
                            title: Text(
                              option,
                              style: const TextStyle(fontSize: 14, color: Color(0xFF4E5969)),
                            ),
                            onTap: () => onSelected(option),
                            selected: option == _selectedBusiness,
                            selectedTileColor: const Color(0xFFE8F3FF),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            // ==========================================================
            const SizedBox(height: 12),

            // 新增：6. 自定义内容（支持文本和链接）
            TextField(
              controller: _customContentController,
              maxLines: 2, // 设置多行输入，方便输入长链接和文本
              decoration: _buildInputDecoration(
                labelText: '内容',
                hintText: '',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 清空按钮
                    IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFF86909C), size: 20),
                      onPressed: () => _clearTextController(_customContentController),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40),
                      tooltip: '清空内容',
                    ),
                  ],
                ),
              ),
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 12),
            // 5. 预计完成时间
            TextField(
              controller: _deadlineController,
              readOnly: true,
              onTap: _selectDeadline,
              decoration: _buildInputDecoration(
                labelText: '预计完成时间',
                hintText: '点击选择日期',
                suffixIcon: const Icon(Icons.calendar_today, color: Color(0xFF0088FF), size: 20),
              ),
              autocorrect: false,
              enableSuggestions: false,
            ),
            const SizedBox(height: 12),

            // 新增：文件上传区域
            const Text(
              '项目附件（可选）',
              style: TextStyle(fontSize: 14, color: Color(0xFF86909C)),
            ),
            const SizedBox(height: 8),
            // 文件上传按钮
            ElevatedButton.icon(
              onPressed: _isUploadingFile ? null : _selectAndUploadFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5F7FA),
                foregroundColor: const Color(0xFF0088FF),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFE5E6EB)),
                ),
              ),
              icon: _isUploadingFile
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Color(0xFF0088FF),
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.upload_file, size: 20),
              label: const Text('上传开案信息', style: TextStyle(fontSize: 14)),
            ),
            // 已上传文件显示
            if (_fileName != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF0088FF), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, color: Color(0xFF0088FF), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fileName!,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF4E5969)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _fileType ?? '未知文件类型',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF86909C)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                      onPressed: _deleteTempFile,
                      tooltip: '删除文件',
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // 提交按钮（移除组长合法性校验，直接启用）
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0088FF),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text(
                  '提交申请',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    dev.log('申请表单页面销毁，开始释放资源', name: 'ApplyFormPage.dispose');
    _customerController.dispose();
    _businessController.dispose();
    _deadlineController.dispose();
    _applicantController.dispose();
    _customContentController.dispose(); // 新增：释放自定义内容控制器
    // 移除组长验证定时器（已无相关逻辑）
    dev.log('所有输入框控制器已释放，页面销毁完成', name: 'ApplyFormPage.dispose');
    super.dispose();
  }
}