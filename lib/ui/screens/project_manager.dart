import 'package:flutter/material.dart';
import 'package:kontinuum/ui/screens/project_screen.dart' as screens;

class ProjectManager extends StatelessWidget {
  const ProjectManager({super.key});

  static const Color kBg = Color(0xFF0F151A);
  static const Color kCard = Color(0xFF0A0E11);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        title: const Text(
          'Project Manager',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 500),
                pageBuilder: (_, __, ___) => const screens.ProjectScreen(),
              ),
            );
          },
          child: Hero(
            tag: "create_project_card",
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  "Create Project",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
