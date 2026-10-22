// Pick the languages voice answers listen in, or follow the phone's language.

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../answers/voice_listener.dart';
import '../app_services.dart';
import '../core/voice_commands.dart';

class VoiceLanguagesScreen extends StatefulWidget {
  const VoiceLanguagesScreen({
    super.key,
    this.loadLanguages = recognizerLanguages,
    this.initial,
    this.onChanged,
  });

  final Future<(List<LocaleName>, LocaleName?)> Function() loadLanguages;

  /// Defaults to the saved settings; overridable for tests.
  final List<String>? initial;
  final ValueChanged<List<String>>? onChanged;

  @override
  State<VoiceLanguagesScreen> createState() => _VoiceLanguagesScreenState();
}

class _VoiceLanguagesScreenState extends State<VoiceLanguagesScreen> {
  late List<String> _selected = widget.initial ?? AppServices.instance.settings.voiceLocales;
  List<LocaleName>? _all;
  LocaleName? _phone;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    widget.loadLanguages().then((r) {
      if (!mounted) return;
      setState(() {
        _all = r.$1;
        _phone = r.$2;
      });
    });
  }

  bool get _followPhone => _selected.isEmpty;

  void _save(List<String> next) {
    setState(() => _selected = next);
    if (widget.onChanged != null) {
      widget.onChanged!(next);
    } else {
      final services = AppServices.instance;
      services.updateSettings(services.settings.copyWith(voiceLocales: next));
    }
  }

  void _toggle(String id, bool on) {
    final next = on ? [..._selected, id] : _selected.where((l) => l != id).toList();
    _save(next);
  }

  String _nameOf(String id) => _all?.where((l) => l.localeId == id).firstOrNull?.name ?? id;

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final phone = _phone;
    return Scaffold(
      appBar: AppBar(title: const Text('Voice languages')),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : all.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Speech recognition is not available, or microphone access was denied.'),
                )
              : ListView(
                  children: [
                    SwitchListTile(
                      title: const Text('Follow phone language'),
                      subtitle: Text(phone == null ? 'Phone language unknown' : phone.name),
                      value: _followPhone,
                      onChanged: (on) => _save(on ? const [] : [phone?.localeId ?? all.first.localeId]),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        '"OK" works in every language. With several languages the phone takes turns '
                        'listening in each for a few seconds, so you may need to answer twice.',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ),
                    if (!_followPhone) ...[
                      for (final id in _selected) _tile(id, _nameOf(id), selected: true),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Add a language'),
                          onChanged: (v) => setState(() => _filter = v.toLowerCase()),
                        ),
                      ),
                      for (final l in all)
                        if (!_selected.contains(l.localeId) &&
                            (l.name.toLowerCase().contains(_filter) || l.localeId.toLowerCase().contains(_filter)))
                          _tile(l.localeId, l.name, selected: false),
                    ],
                  ],
                ),
    );
  }

  Widget _tile(String id, String name, {required bool selected}) {
    final phrases = examplePhrases(id);
    return CheckboxListTile(
      value: selected,
      // Keep at least one language; to clear, follow the phone instead.
      onChanged: selected && _selected.length == 1 ? null : (on) => _toggle(id, on ?? false),
      title: Text(name),
      subtitle: Text(phrases ?? 'No built-in phrases yet: "OK" works', style: const TextStyle(fontSize: 12)),
    );
  }
}
