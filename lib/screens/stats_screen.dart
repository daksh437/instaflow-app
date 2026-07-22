import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/instagram_provider.dart';
import '../widgets/main_navigation_wrapper.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InstagramProvider>().bootstrapStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainNavigationWrapper(
      currentIndex: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('Full Analytics Dashboard')),
        body: Consumer<InstagramProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!provider.isConnected) {
              return Center(
                child: ElevatedButton(
                  onPressed: () => provider.connect(),
                  child: const Text('Connect Instagram'),
                ),
              );
            }

            final statsErr = provider.error;
            if (statsErr != null && statsErr.isNotEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(statsErr, textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => provider.refreshStats(forceRefresh: true),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => provider.refreshStats(forceRefresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      title: const Text('Followers'),
                      trailing: Text(provider.followers.toString()),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: const Text('Total Posts'),
                      trailing: Text(provider.posts.toString()),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
