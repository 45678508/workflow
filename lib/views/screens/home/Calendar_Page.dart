import 'package:flutter/material.dart';

class CalendarPage extends StatelessWidget{
  CalendarPage({super.key});

  @override
  Widget build( BuildContext context) {
    return Column(
      children: [
        // 顶部日期选择栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "2026年1月7日 星期三",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Color(0xFF0088FF), size: 18),
                  SizedBox(width: 4),
                  Text("切换视图", style: TextStyle(color: Color(0xFF0088FF), fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
        // 日程列表骨架（纯界面，无数据）
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "今日暂无日程",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "点击添加新日程",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 底部添加日程按钮（纯视觉）
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {}, // 空点击事件
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0088FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text("新建日程", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
// 3. 日程页面（纯界面骨架）


