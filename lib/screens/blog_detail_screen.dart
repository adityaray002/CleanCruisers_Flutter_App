import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../data/blog_data.dart';
import '../models/blog_post.dart';
import '../widgets/contact_actions.dart';
import '../widgets/ui.dart';

class BlogDetailScreen extends StatelessWidget {
  final String id;
  const BlogDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final post = blogPosts.where((p) => p.id == id).firstOrNull;
    if (post == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: EmptyState(
            icon: Icons.article_outlined,
            title: 'Article not found',
            message: 'It may have been moved.',
            action: PrimaryButton(
                label: 'All tips',
                expand: false,
                onPressed: () => context.go('/blog')),
          ),
        ),
      );
    }
    return _PostView(post: post);
  }
}

class _PostView extends StatelessWidget {
  final BlogPost post;
  const _PostView({required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            tooltip: 'Open on website',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => openLink(context, '$kWebsite/blog/${post.id}'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 4, AppSpace.page, 40),
        children: [
          Row(children: [
            Pill(post.category, tone: PillTone.brand),
            const SizedBox(width: 10),
            Text('${post.readTime} · ${post.date}', style: AppText.caption),
          ]),
          const SizedBox(height: 14),
          Text(post.title, style: AppText.h1),
          const SizedBox(height: 6),
          Text('By the CleanCruisers team', style: AppText.caption),
          const SizedBox(height: 10),
          MarkdownBody(
            data: post.content,
            styleSheet: _mdStyle(),
            onTapLink: (text, href, title) {
              if (href != null) openLink(context, href);
            },
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Want us to handle it?',
                  style: AppText.h3.copyWith(color: Colors.white)),
              const SizedBox(height: 6),
              Text('Book a doorstep wash or detailing. Pay after the service.',
                  style:
                      AppText.small.copyWith(color: const Color(0xFFD1D5DB))),
              const SizedBox(height: 14),
              PrimaryButton(
                  label: 'See services & prices',
                  onPressed: () => context.go('/services')),
            ]),
          ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _mdStyle() {
    final p = AppText.body
        .copyWith(color: const Color(0xFF374151), fontSize: 16, height: 1.7);
    return MarkdownStyleSheet(
      h1: AppText.h1,
      h2: AppText.h2,
      h3: AppText.h3,
      p: p,
      listBullet: p.copyWith(color: AppColors.primary),
      strong: p.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
      em: p.copyWith(fontStyle: FontStyle.italic),
      a: p.copyWith(
          color: AppColors.primary, decoration: TextDecoration.underline),
      blockquote: p.copyWith(color: AppColors.primaryDk, fontSize: 15),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border:
            const Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.all(14),
      code: AppText.small.copyWith(backgroundColor: AppColors.surfaceAlt),
      codeblockDecoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      h1Padding: const EdgeInsets.only(top: 24, bottom: 8),
      h2Padding: const EdgeInsets.only(top: 22, bottom: 8),
      h3Padding: const EdgeInsets.only(top: 16, bottom: 6),
      pPadding: const EdgeInsets.only(bottom: 12),
    );
  }
}
