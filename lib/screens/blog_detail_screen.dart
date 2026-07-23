import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../data/blog_data.dart';
import '../models/blog_post.dart';

class BlogDetailScreen extends StatelessWidget {
  final String id;
  const BlogDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final post = blogPosts.where((p) => p.id == id).firstOrNull;
    if (post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post Not Found')),
        body: const Center(child: Text('Blog post not found.')),
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
      backgroundColor: kBgBlack,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: kBgBlack,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.open_in_browser, color: kGray400),
                onPressed: () => launchUrl(
                  Uri.parse('https://cleancruisers.in/blog/${post.id}'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        post.categoryColor.withAlpha(20),
                        kBgBlack,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: post.categoryColor.withAlpha(26),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: post.categoryColor.withAlpha(77)),
                          ),
                          child: Text(post.category,
                              style: TextStyle(
                                  color: post.categoryColor,
                                  fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        Text(post.readTime,
                            style: const TextStyle(
                                color: kGray400, fontSize: 12)),
                      ]),
                      const SizedBox(height: 14),
                      Text(post.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22, fontWeight: FontWeight.w800,
                              height: 1.25)),
                      const SizedBox(height: 14),
                      Row(children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: kGreen400,
                          backgroundImage: const AssetImage('assets/images/logo.png'),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CleanCruisers Team',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(post.date,
                                style: const TextStyle(
                                    color: kGray400, fontSize: 11)),
                          ],
                        ),
                      ]),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: MarkdownBody(
                    data: post.content,
                    styleSheet: _mdStyle(context),
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        launchUrl(Uri.parse(href),
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 40),
                // CTA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        kGreen500.withAlpha(26),
                        kBgCard,
                      ]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kGreen400.withAlpha(77)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Keep Your Car Clean',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        const Text(
                          'Book a professional doorstep car wash with CleanCruisers. No advance payment, 7 days a week.',
                          style: TextStyle(color: kGray400, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => context.push('/booking'),
                            child: const Text('Book Now — Free'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _mdStyle(BuildContext context) {
    return MarkdownStyleSheet(
      h1: const TextStyle(
          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800,
          height: 1.3),
      h2: const TextStyle(
          color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700,
          height: 1.3),
      h3: const TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600,
          height: 1.3),
      p: const TextStyle(
          color: Color(0xFFD1D5DB), fontSize: 15, height: 1.7),
      strong: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700),
      em: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
      a: const TextStyle(
          color: kGreen400,
          decoration: TextDecoration.underline,
          decorationColor: kGreen400),
      listBullet: const TextStyle(color: kGreen400),
      listIndent: 20,
      blockquoteDecoration: BoxDecoration(
        color: kGreen400.withAlpha(13),
        border: const Border(
            left: BorderSide(color: kGreen400, width: 3)),
        borderRadius: BorderRadius.circular(4),
      ),
      blockquotePadding: const EdgeInsets.all(14),
      blockquote: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
      code: const TextStyle(
          color: kGreen400,
          backgroundColor: Color(0xFF1C2326),
          fontSize: 13),
      codeblockDecoration: BoxDecoration(
        color: kBgCard2,
        borderRadius: BorderRadius.circular(10),
      ),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kGray700, width: 0.5)),
      ),
      h1Padding: const EdgeInsets.only(top: 24, bottom: 8),
      h2Padding: const EdgeInsets.only(top: 22, bottom: 8),
      h3Padding: const EdgeInsets.only(top: 16, bottom: 6),
      pPadding: const EdgeInsets.only(bottom: 12),
    );
  }
}
