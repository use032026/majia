import 'package:flutter/material.dart';

import '../domain/revision_session.dart';
import '../l10n/app_strings.dart';

class ChangesPage extends StatelessWidget {
  const ChangesPage({required this.session, super.key});

  final RevisionSession session;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final changed = session.passages
        .where((passage) => passage.wasChanged)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(strings.compareTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: changed.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        strings.noChanges,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    itemCount: changed.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final passage = changed[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${index + 1}',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                strings.before,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 5),
                              SelectableText(passage.original),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Divider(),
                              ),
                              Text(
                                strings.after,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 5),
                              SelectableText(passage.revised),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
