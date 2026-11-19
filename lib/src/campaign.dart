import 'dart:convert';

import 'package:flutter/services.dart';

const worldsPerCampaign = 14;
const campaignSize = worldsPerCampaign * 2;

class LabCase {
  const LabCase(this.label, this.input, this.expected, this.provided);
  final String label;
  final String input;
  final String expected;
  final Map<String, String> provided;

  factory LabCase.fromJson(Map<String, dynamic> json) => LabCase(
    json['label'] as String,
    json['input'] as String,
    json['expected'] as String,
    Map<String, String>.from(json['provided'] as Map),
  );

  Map<String, Object> toJson() => {
    'input': input,
    'expected': expected,
    'provided': provided,
  };
}

class Lab {
  const Lab({
    required this.id,
    required this.title,
    required this.topic,
    required this.story,
    required this.lesson,
    required this.example,
    required this.trace,
    required this.goal,
    required this.files,
    required this.editable,
    required this.hints,
    required this.tests,
    required this.blueprint,
  });

  final String id, title, topic, story, example, trace, goal;
  final List<String> lesson, hints, editable, blueprint;
  final Map<String, String> files;
  final List<LabCase> tests;

  String get language => id.split('-').first;

  factory Lab.fromJson(Map<String, dynamic> json) => Lab(
    id: json['id'] as String,
    blueprint: List<String>.from((json['blueprint'] as List?) ?? const []),
    title: json['title'] as String,
    topic: json['topic'] as String,
    story: json['story'] as String,
    lesson: List<String>.from(json['lesson'] as List),
    example: json['example'] as String,
    trace: json['trace'] as String,
    goal: json['goal'] as String,
    files: Map<String, String>.from(json['files'] as Map),
    editable: List<String>.from(json['editable'] as List),
    hints: List<String>.from(json['hints'] as List),
    tests: (json['tests'] as List)
        .cast<Map<String, dynamic>>()
        .map(LabCase.fromJson)
        .toList(),
  );
}

Future<List<Lab>> loadCampaign() async {
  final raw = await rootBundle.loadString('assets/campaign.json');
  return (jsonDecode(raw) as List)
      .cast<Map<String, dynamic>>()
      .map(Lab.fromJson)
      .toList();
}

bool worldUnlocked(int index, Set<int> completed) =>
    index % worldsPerCampaign == 0 || completed.contains(index - 1);
