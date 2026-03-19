import 'package:flutter/material.dart';

import '../../../../core/ui/app_feedback.dart';
import '../../data/repositories/bug_report_repository.dart';

class BugReportActionButton extends StatelessWidget {
  final String sourcePage;
  final int? campaignId;
  final String? mapId;
  final String? characterId;
  final Map<String, dynamic> extraContext;

  const BugReportActionButton({
    super.key,
    required this.sourcePage,
    this.campaignId,
    this.mapId,
    this.characterId,
    this.extraContext = const {},
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.bug_report_outlined),
      tooltip: 'Signaler un bug',
      onPressed: () => _showBugReportDialog(
        context,
        sourcePage: sourcePage,
        campaignId: campaignId,
        mapId: mapId,
        characterId: characterId,
        extraContext: extraContext,
      ),
    );
  }

  static Future<void> show(
    BuildContext context, {
    required String sourcePage,
    int? campaignId,
    String? mapId,
    String? characterId,
    Map<String, dynamic> extraContext = const {},
  }) {
    return _showBugReportDialog(
      context,
      sourcePage: sourcePage,
      campaignId: campaignId,
      mapId: mapId,
      characterId: characterId,
      extraContext: extraContext,
    );
  }
}

Future<void> _showBugReportDialog(
  BuildContext context, {
  required String sourcePage,
  int? campaignId,
  String? mapId,
  String? characterId,
  Map<String, dynamic> extraContext = const {},
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _BugReportDialog(
      sourcePage: sourcePage,
      campaignId: campaignId,
      mapId: mapId,
      characterId: characterId,
      extraContext: extraContext,
    ),
  );
}

class _BugReportDialog extends StatefulWidget {
  final String sourcePage;
  final int? campaignId;
  final String? mapId;
  final String? characterId;
  final Map<String, dynamic> extraContext;

  const _BugReportDialog({
    required this.sourcePage,
    this.campaignId,
    this.mapId,
    this.characterId,
    required this.extraContext,
  });

  @override
  State<_BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<_BugReportDialog> {
  final BugReportRepository _repository = BugReportRepository();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _actualController = TextEditingController();
  final TextEditingController _expectedController = TextEditingController();
  final TextEditingController _stepsController = TextEditingController();

  String _category = 'gameplay';
  String _severity = 'major';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _actualController.dispose();
    _expectedController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty ||
        _actualController.text.trim().isEmpty) {
      AppFeedback.warning(
        context,
        'Titre et constat observes sont requis.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _repository.submitReport(
        title: _titleController.text,
        category: _category,
        severity: _severity,
        actual: _actualController.text,
        expected: _expectedController.text,
        steps: _stepsController.text,
        sourcePage: widget.sourcePage,
        campaignId: widget.campaignId,
        mapId: widget.mapId,
        characterId: widget.characterId,
        extraContext: widget.extraContext,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.success(context, 'Bug enregistre pour l’alpha.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppFeedback.error(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Signaler un bug alpha'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ContextChip(label: 'Page: ${widget.sourcePage}'),
                  if (widget.campaignId != null)
                    _ContextChip(label: 'Campagne: ${widget.campaignId}'),
                  if (widget.mapId != null)
                    _ContextChip(label: 'Carte: ${widget.mapId}'),
                  if (widget.characterId != null)
                    _ContextChip(label: 'Perso: ${widget.characterId}'),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre court',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: 'Categorie',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'gameplay',
                          child: Text('Gameplay'),
                        ),
                        DropdownMenuItem(
                          value: 'ui',
                          child: Text('UI'),
                        ),
                        DropdownMenuItem(
                          value: 'sync',
                          child: Text('Sync'),
                        ),
                        DropdownMenuItem(
                          value: 'combat',
                          child: Text('Combat'),
                        ),
                        DropdownMenuItem(
                          value: 'rules',
                          child: Text('Regles'),
                        ),
                        DropdownMenuItem(
                          value: 'performance',
                          child: Text('Performance'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('Autre'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _category = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _severity,
                      decoration: const InputDecoration(
                        labelText: 'Gravite',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'blocking',
                          child: Text('Bloquant'),
                        ),
                        DropdownMenuItem(
                          value: 'major',
                          child: Text('Majeur'),
                        ),
                        DropdownMenuItem(
                          value: 'minor',
                          child: Text('Mineur'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _severity = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _actualController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Ce qui s’est passe',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _expectedController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ce qui etait attendu',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _stepsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Etapes pour reproduire',
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.extraContext.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Contexte auto: ${widget.extraContext}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: const Text('Envoyer'),
        ),
      ],
    );
  }
}

class _ContextChip extends StatelessWidget {
  final String label;

  const _ContextChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.white70),
      ),
    );
  }
}
