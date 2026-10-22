import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../audio/external_media.dart';
import '../core/positions.dart';
import '../data/book.dart';
import 'book_screen.dart';
import 'external_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _services = AppServices.instance;
  bool _importing = false;

  Future<void> _addBook() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    if (files.isEmpty) return;
    setState(() => _importing = true);
    try {
      final book = await _services.library.import(files);
      _toast('Added "${book.title}"');
    } catch (e) {
      _toast('Could not import: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _delete(Book book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${book.title}"?'),
        content: const Text('Removes the audio files from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _services.library.delete(book);
    setState(() {});
  }

  void _toast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final books = _services.library.sorted;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audiobook to Sleep'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Settings',
            onPressed: () => _open(const SettingsScreen()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _addBook,
        icon: _importing
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
        label: Text(_importing ? 'Importing…' : 'Add audiobook'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (ExternalMedia.supported) ...[
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: const Icon(Icons.cast_connected),
                title: const Text('Control another app'),
                subtitle: const Text('Spotify, Audible, or anything playing on this phone'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(const ExternalScreen()),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text('Your books', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (books.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Add an audiobook to get started. Pick one file, or select all the parts of a book at once.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
            ),
          for (final book in books)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BookTile(
                book: book,
                onTap: () => _open(BookScreen(book: book)),
                onDelete: () => _delete(book),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, required this.onTap, required this.onDelete});

  final Book book;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final length = book.length;
    final progress = length.inMilliseconds == 0 ? 0.0 : book.position.inMilliseconds / length.inMilliseconds;
    final parts = book.tracks.length > 1 ? ' · ${book.tracks.length} parts' : '';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress.clamp(0, 1), borderRadius: BorderRadius.circular(2)),
                    const SizedBox(height: 6),
                    Text('${formatDuration(book.position)} of ${formatDuration(length)}$parts',
                        style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close, size: 20), tooltip: 'Delete', onPressed: onDelete),
            ],
          ),
        ),
      ),
    );
  }
}
