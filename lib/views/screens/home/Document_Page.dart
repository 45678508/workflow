import 'package:flutter/material.dart';

class DocumentPage extends StatelessWidget {
  const DocumentPage({super.key});

  // 必须实现 StatelessWidget 的 build 方法
  @override
  Widget build(BuildContext context) {
    // 调用你定义的页面构建方法
    return _buildDocumentPage();
  }

  // 你的页面布局私有方法
  Widget _buildDocumentPage() {
    return Column(
      children: [
        // 顶部搜索+筛选栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              // 搜索框
              Expanded(
                child: TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: "搜索文档",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF2F3F5),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 筛选按钮（纯视觉）
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.filter_list, color: Colors.grey, size: 16),
                    SizedBox(width: 4),
                    Text("筛选",
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 文档列表骨架（纯界面，无数据）
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_copy, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "暂无文档",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "点击上传或创建新文档",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}