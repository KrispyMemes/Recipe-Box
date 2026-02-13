import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../data/recipe_repository.dart';
import '../../models/import_job.dart';

class ImportCenterScreen extends StatefulWidget {
  const ImportCenterScreen({required this.repository, super.key});

  final RecipeRepository repository;

  @override
  State<ImportCenterScreen> createState() => _ImportCenterScreenState();
}

class _ImportCenterScreenState extends State<ImportCenterScreen> {
  bool _isLoading = true;
  List<ImportJob> _jobs = const <ImportJob>[];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
    });

    final List<ImportJob> jobs = await widget.repository.listImportJobs();

    if (!mounted) {
      return;
    }

    setState(() {
      _jobs = jobs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Center')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No imports yet. Start a web import from Add Recipe.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _jobs.length,
                itemBuilder: (context, index) {
                  final ImportJob job = _jobs[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(_jobTitle(job)),
                      subtitle: Text(_jobSubtitle(job)),
                      trailing: _statusChip(job.status),
                      onTap: () {
                        if (job.status == ImportJobStatus.succeeded &&
                            job.resultRecipeInput != null) {
                          Navigator.of(context).pop(job.resultRecipeInput);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _jobTitle(ImportJob job) {
    if (job.resultRecipeInput != null &&
        job.resultRecipeInput!.title.trim().isNotEmpty) {
      return job.resultRecipeInput!.title;
    }
    return switch (job.type) {
      ImportJobType.url => 'URL Import',
      ImportJobType.photo => 'Photo Import',
      ImportJobType.paprikaFile => 'Paprika Import',
      ImportJobType.share => 'Shared Import',
    };
  }

  String _jobSubtitle(ImportJob job) {
    final String source = job.type == ImportJobType.photo
        ? p.basename(job.sourcePayload)
        : job.sourcePayload;
    switch (job.status) {
      case ImportJobStatus.pending:
        return 'Parsing: $source';
      case ImportJobStatus.succeeded:
        return 'Tap to review and save.\n$source';
      case ImportJobStatus.failed:
        final String error = job.errorMessage ?? 'Unknown import error';
        return 'Failed: $error\n$source';
    }
  }

  Widget _statusChip(ImportJobStatus status) {
    final (String label, Color color) = switch (status) {
      ImportJobStatus.pending => ('Pending', Colors.orange),
      ImportJobStatus.succeeded => ('Ready', Colors.green),
      ImportJobStatus.failed => ('Failed', Colors.red),
    };

    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      labelStyle: TextStyle(color: color),
    );
  }
}
