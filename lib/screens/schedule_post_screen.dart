import 'package:flutter/material.dart';

import 'post_creation/post_creation_flow.dart';

/// Entry route for Instagram-style multi-step scheduling (`/schedule-post`).
class SchedulePostScreen extends StatelessWidget {
  const SchedulePostScreen({super.key});

  @override
  Widget build(BuildContext context) => const PostCreationFlow();
}
