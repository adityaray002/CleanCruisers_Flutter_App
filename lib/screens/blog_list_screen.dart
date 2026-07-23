import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../data/blog_data.dart';
import '../models/blog_post.dart';

class BlogListScreen extends StatelessWidget {
  const BlogListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: kBgBlack,
            title: const Text('Car Care Blog',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 0.5, color: kGray700),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _BlogCard(post: blogPosts[i]),
                childCount: blogPosts.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlogCard extends StatelessWidget {
  final BlogPost post;
  const _BlogCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/blog/${post.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kBgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGray700.withAlpha(128)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: post.categoryColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: post.categoryColor.withAlpha(77)),
                ),
                child: Text(post.category,
                    style: TextStyle(
                        color: post.categoryColor,
                        fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Text(post.readTime,
                  style: const TextStyle(color: kGray400, fontSize: 11)),
            ]),
            const SizedBox(height: 10),
            Text(post.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 8),
            Text(post.excerpt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: kGray400, fontSize: 13, height: 1.4)),
            const SizedBox(height: 12),
            Row(children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: kGreen400,
                backgroundImage: const AssetImage('assets/images/logo.png'),
              ),
              const SizedBox(width: 8),
              const Text('CleanCruisers Team',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Text(post.date,
                  style: const TextStyle(color: kGray400, fontSize: 11)),
            ]),
          ],
        ),
      ),
    );
  }
}
