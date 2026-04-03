import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/instagram_model.dart';
import '../providers/instagram_provider.dart';

const _bgDark = Color(0xFF0D0D0F);
const _cardDark = Color(0xFF16161A);
const _neon = Color(0xFF7B2CBF);
const _neonLight = Color(0xFF9D4EDD);
const _textPrimary = Color(0xFFE8E8EA);
const _textSecondary = Color(0xFF8E8E93);

class YourStatsScreen extends StatefulWidget {
  const YourStatsScreen({super.key});

  @override
  State<YourStatsScreen> createState() => _YourStatsScreenState();
}

class _YourStatsScreenState extends State<YourStatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InstagramProvider>().checkConnection();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        title: const Text('Your Stats', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: _bgDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textPrimary),
        actions: [
          Consumer<InstagramProvider>(
            builder: (context, prov, _) {
              if (!prov.isConnected) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: prov.isLoading ? null : () => prov.loadAll(),
              );
            },
          ),
        ],
      ),
      body: Consumer<InstagramProvider>(
        builder: (context, prov, _) {
          if (prov.isConnecting) return _buildLoading();
          if (prov.error != null && !prov.isConnected) return _buildError(prov);
          if (!prov.isConnected) return _buildConnect(prov);
          if (prov.isLoading && prov.profile == null) return _buildLoading();
          return _buildDashboard(prov);
        },
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(_neon),
            ),
          ),
          const SizedBox(height: 20),
          Text('Loading...', style: TextStyle(color: _textSecondary, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildError(InstagramProvider prov) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              prov.error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                prov.clearError();
                prov.connect();
              },
              icon: const Icon(Icons.refresh, color: _neon),
              label: const Text('Retry', style: TextStyle(color: _neon)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnect(InstagramProvider prov) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_neon.withOpacity(0.3), _neonLight.withOpacity(0.2)],
              ),
            ),
            child: const Icon(Icons.camera_alt_rounded, size: 72, color: _neon),
          ),
          const SizedBox(height: 32),
          const Text(
            'Connect Instagram Business',
            style: TextStyle(color: _textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Link your Facebook account with an Instagram Business or Creator account to see real stats.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: prov.isConnecting ? null : () async {
                final ok = await prov.connect();
                if (!mounted) return;
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Connected'), backgroundColor: _neon),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(prov.error ?? 'Connection failed'), backgroundColor: Colors.red),
                  );
                }
              },
              icon: prov.isConnecting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.facebook_rounded),
              label: Text(prov.isConnecting ? 'Connecting...' : 'Continue with Facebook'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _neon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(InstagramProvider prov) {
    final profile = prov.profile;
    final insights = prov.insights;
    if (profile == null) return _buildLoading();

    return RefreshIndicator(
      onRefresh: () => prov.loadAll(),
      color: _neon,
      backgroundColor: _cardDark,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileCard(profile: profile),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _StatCard(title: 'Followers', value: _formatNum(profile.followersCount), icon: Icons.people_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Reach', value: _formatNum(insights?.reach ?? 0), icon: Icons.trending_up_rounded)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCard(title: 'Impressions', value: _formatNum(insights?.impressions ?? 0), icon: Icons.visibility_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Profile views', value: _formatNum(insights?.profileViews ?? 0), icon: Icons.person_rounded)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCard(title: 'Following', value: _formatNum(profile.followsCount), icon: Icons.person_add_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Posts', value: profile.mediaCount.toString(), icon: Icons.grid_on_rounded)),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Media', style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('${prov.media.length} items', style: const TextStyle(color: _textSecondary, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),
            _MediaGrid(media: prov.media, onTap: (media) => _openMediaDetails(context, media, prov)),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: _cardDark,
                    title: const Text('Disconnect', style: TextStyle(color: _textPrimary)),
                    content: const Text(
                      'Disconnect Instagram Business from this app?',
                      style: TextStyle(color: _textSecondary),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Disconnect', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await prov.disconnect();
                }
              },
              icon: const Icon(Icons.link_off_rounded, size: 20, color: _textSecondary),
              label: const Text('Disconnect account', style: TextStyle(color: _textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  void _openMediaDetails(BuildContext context, IgMedia media, InstagramProvider prov) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _MediaDetailsSheet(media: media, prov: prov),
    );
  }

  static String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1e3).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _ProfileCard extends StatelessWidget {
  final IgProfile profile;

  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neon.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: _neon.withOpacity(0.2),
            backgroundImage: profile.profilePictureUrl != null ? NetworkImage(profile.profilePictureUrl!) : null,
            child: profile.profilePictureUrl == null ? const Icon(Icons.person_rounded, size: 40, color: _neon) : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${profile.username}', style: const TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${profile.followersCount} followers · ${profile.mediaCount} posts',
                  style: const TextStyle(color: _textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neon.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _neon, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: _textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  final List<IgMedia> media;
  final ValueChanged<IgMedia> onTap;

  const _MediaGrid({required this.media, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Text('No media yet', style: TextStyle(color: _textSecondary, fontSize: 15)),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final m = media[index];
        return GestureDetector(
          onTap: () => onTap(m),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _cardDark,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (m.mediaUrl != null)
                  Image.network(
                    m.mediaUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _neon)),
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: _textSecondary),
                  )
                else
                  const Icon(Icons.image_rounded, color: _textSecondary, size: 40),
                Positioned(
                  bottom: 6,
                  left: 6,
                  right: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_rounded, size: 14, color: Colors.white.withOpacity(0.9)),
                      const SizedBox(width: 4),
                      Text('${m.likeCount}', style: TextStyle(color: Colors.white, fontSize: 12, shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
                      const SizedBox(width: 10),
                      Icon(Icons.chat_bubble_rounded, size: 14, color: Colors.white.withOpacity(0.9)),
                      const SizedBox(width: 4),
                      Text('${m.commentsCount}', style: TextStyle(color: Colors.white, fontSize: 12, shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MediaDetailsSheet extends StatefulWidget {
  final IgMedia media;
  final InstagramProvider prov;

  const _MediaDetailsSheet({required this.media, required this.prov});

  @override
  State<_MediaDetailsSheet> createState() => _MediaDetailsSheetState();
}

class _MediaDetailsSheetState extends State<_MediaDetailsSheet> {
  @override
  void initState() {
    super.initState();
    widget.prov.loadComments(widget.media.id);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    final comments = widget.prov.commentsFor(m.id);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: _textSecondary.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              if (m.mediaUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    m.mediaUrl!,
                    height: 280,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 280, color: _cardDark, child: const Icon(Icons.broken_image_rounded, color: _textSecondary)),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _miniStat(Icons.favorite_rounded, m.likeCount.toString()),
                  const SizedBox(width: 24),
                  _miniStat(Icons.chat_bubble_rounded, m.commentsCount.toString()),
                ],
              ),
              if (m.caption != null && m.caption!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(m.caption!, style: const TextStyle(color: _textSecondary, fontSize: 14)),
              ],
              const SizedBox(height: 20),
              const Text('Recent comments', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Text('No comments', style: TextStyle(color: _textSecondary)),
                )
              else
                ...comments.take(15).map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 16, backgroundColor: _neon.withOpacity(0.3), child: Text((c.username ?? '?').isNotEmpty ? (c.username!.substring(0, 1).toUpperCase()) : '?', style: const TextStyle(color: _neon))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c.username ?? 'Unknown', style: const TextStyle(color: _neonLight, fontWeight: FontWeight.w600)), if (c.text != null) Text(c.text!, style: const TextStyle(color: _textPrimary))])),
                        ],
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }

  Widget _miniStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _neon),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
