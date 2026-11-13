import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../widgets/neuomorphic.dart';
import '../theme/app_theme.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});
  Future<List<dynamic>> _releases() async =>
      jsonDecode(await rootBundle.loadString('assets/release_history.json'))
          as List;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('What’s new')),
        body: AppBackground(
            child: FutureBuilder<List<dynamic>>(
          future: _releases(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                  child: Text('Release notes could not be loaded.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(padding: const EdgeInsets.all(20), children: [
              Text(
                  'This build: ${AppConfig.buildName} (${AppConfig.buildNumber})',
                  style: Theme.of(context).textTheme.titleMedium),
              Text(AppConfig.releaseChannel == 'beta'
                  ? 'Internal testing build'
                  : 'Production candidate'),
              const SizedBox(height: 18),
              for (final raw in snapshot.data!) ...[
                NeuPane(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(raw['title'] as String,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text('${raw['date'] as String} · ${raw['status'] as String}'),
                      const SizedBox(height: 10),
                      for (final change in raw['changes'] as List)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('• $change')),
                    ])),
                const SizedBox(height: 16),
              ],
            ]);
          },
        )),
      );
}
