import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../data/blog_data.dart';
import '../models/blog_post.dart';
import '../widgets/ui.dart';

class BlogListScreen extends StatelessWidget {
  const BlogListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Car care tips')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 4, AppSpace.page, 32),
        itemCount: blogPosts.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
        itemBuilder: (_, i) => _BlogCard(post: blogPosts[i]),
      ),
    );
  }
}

class _BlogCard extends StatelessWidget {
  final BlogPost post;
  const _BlogCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/blog/${post.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pill(post.category, tone: PillTone.brand),
          const Spacer(),
          Text(post.readTime, style: AppText.caption),
        ]),
        const SizedBox(height: 10),
        Text(post.title, style: AppText.h3),
        const SizedBox(height: 6),
        Text(post.excerpt,
            maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.small),
        const SizedBox(height: 10),
        Text(post.date, style: AppText.caption),
      ]),
    );
  }
}
