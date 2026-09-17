import 'package:flutter/material.dart';

import 'subtabs/admin_citizenship_subtab.dart';
import 'subtabs/admin_flashcards_subtab.dart';
import 'subtabs/admin_lessons_subtab.dart';
import 'subtabs/admin_topics_subtab.dart';
import 'subtabs/admin_videos_subtab.dart';

class AdminContentTab extends StatelessWidget {
  const AdminContentTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Теми'),
                Tab(text: 'Уроки'),
                Tab(text: 'Картки'),
                Tab(text: 'Громадянство'),
                Tab(text: 'Відео'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(children: [
              AdminTopicsSubtab(),
              AdminLessonsSubtab(),
              AdminFlashcardsSubtab(),
              AdminCitizenshipSubtab(),
              AdminVideosSubtab(),
            ]),
          ),
        ],
      ),
    );
  }
}
