import 'package:flutter/material.dart';

class BlogPost {
  final String id;
  final String title;
  final String excerpt;
  final String content;
  final String category;
  final String date;
  final String readTime;
  final Color categoryColor;

  const BlogPost({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.category,
    required this.date,
    required this.readTime,
    required this.categoryColor,
  });
}
