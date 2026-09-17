import 'package:flutter/material.dart';

import 'tabs/admin_content_tab.dart';
import 'tabs/admin_dashboard_tab.dart';
import 'tabs/admin_users_tab.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Адміністрування'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Огляд', icon: Icon(Icons.dashboard_outlined)),
            Tab(text: 'Користувачі', icon: Icon(Icons.people_outline)),
            Tab(text: 'Контент', icon: Icon(Icons.edit_note_outlined)),
          ]),
        ),
        body: const TabBarView(children: [
          AdminDashboardTab(),
          AdminUsersTab(),
          AdminContentTab(),
        ]),
      ),
    );
  }
}
