// Persistence: the library and night log as JSON files in app storage, and
// settings in shared preferences. Audio files are copied into app storage so
// they're available every night without picking them again.

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../session/app_settings.dart';
import '../session/night_record.dart';
import 'book.dart';

class LibraryStore {
  LibraryStore(this.root);

  final Directory root;
  List<Book> books = [];

  static Future<LibraryStore> open() async {
    final store = LibraryStore(await getApplicationSupportDirectory());
    await store._load();
    return store;
  }

  File get _index => File(p.join(root.path, 'library.json'));
  Directory bookDir(Book book) => Directory(p.join(root.path, 'books', book.id));
  String trackPath(Book book, int index) => p.join(bookDir(book).path, book.tracks[index].fileName);

  Future<void> _load() async {
    if (!await _index.exists()) return;
    final list = jsonDecode(await _index.readAsString()) as List;
    books = [for (final b in list) Book.fromJson((b as Map).cast())];
  }

  Future<void> save() async {
    await root.create(recursive: true);
    final tmp = File('${_index.path}.tmp');
    await tmp.writeAsString(jsonEncode([for (final b in books) b.toJson()]));
    await tmp.rename(_index.path);
  }

  List<Book> get sorted => [...books]
    ..sort((a, b) => (b.lastPlayedAt ?? b.addedAt).compareTo(a.lastPlayedAt ?? a.addedAt));

  Future<Book> import(List<PlatformFile> picked) async {
    final files = [...picked]..sort((a, b) => naturalCompare(a.name, b.name));
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final dir = Directory(p.join(root.path, 'books', id));
    await dir.create(recursive: true);

    final probe = AudioPlayer();
    final tracks = <BookTrack>[];
    try {
      for (var i = 0; i < files.length; i++) {
        // Prefix with the index so names stay unique and ordered.
        final name = '${i.toString().padLeft(3, '0')}_${files[i].name}';
        final dest = File(p.join(dir.path, name));
        final sink = dest.openWrite();
        await sink.addStream(files[i].readAsByteStream());
        await sink.close();
        final duration = await probe.setFilePath(dest.path) ?? Duration.zero;
        tracks.add(BookTrack(fileName: name, duration: duration));
      }
    } catch (_) {
      await dir.delete(recursive: true);
      rethrow;
    } finally {
      await probe.dispose();
    }

    final book = Book(
      id: id,
      title: guessTitle([for (final f in files) f.name]),
      tracks: tracks,
      addedAt: DateTime.now(),
    );
    books.add(book);
    await save();
    return book;
  }

  Future<void> delete(Book book) async {
    books.removeWhere((b) => b.id == book.id);
    await save();
    final dir = bookDir(book);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

class NightLog {
  NightLog(this._file);

  final File _file;
  List<NightRecord> nights = [];

  static Future<NightLog> open() async {
    final dir = await getApplicationSupportDirectory();
    final log = NightLog(File(p.join(dir.path, 'nights.json')));
    if (await log._file.exists()) {
      final list = jsonDecode(await log._file.readAsString()) as List;
      log.nights = [for (final n in list) NightRecord.fromJson((n as Map).cast())];
    }
    return log;
  }

  NightRecord? latestFor(String sourceId) =>
      nights.lastWhereOrNull((n) => n.sourceId == sourceId);

  Future<void> add(NightRecord record) async {
    nights = [...nights, record];
    if (nights.length > 100) nights = nights.sublist(nights.length - 100);
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode([for (final n in nights) n.toJson()]));
  }
}

class SettingsStore {
  static const _key = 'settings';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson((jsonDecode(raw) as Map).cast());
    } catch (_) {
      return const AppSettings();
    }
  }

  static Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}

extension<T> on List<T> {
  T? lastWhereOrNull(bool Function(T) test) {
    for (var i = length - 1; i >= 0; i--) {
      if (test(this[i])) return this[i];
    }
    return null;
  }
}
