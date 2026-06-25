import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class NotesApp extends StatefulWidget {
  const NotesApp({super.key});
  @override
  State<NotesApp> createState() => _NotesAppState();
}

class _NotesAppState extends State<NotesApp> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  List<_NoteFile> _notes = [];
  _NoteFile? _selectedNote;
  String? _notesDir;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initDir();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _initDir() async {
    final docs = await getApplicationDocumentsDirectory();
    _notesDir = p.join(docs.path, 'CRAFT_Notes');
    await Directory(_notesDir!).create(recursive: true);
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    if (_notesDir == null) return;
    final dir = Directory(_notesDir!);
    if (!await dir.exists()) return;
    final files = await dir.list().where((e) => e is File && p.extension(e.path) == '.txt').cast<File>().toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    setState(() {
      _notes = files.map((f) => _NoteFile(f)).toList();
      _loading = false;
    });
  }

  Future<void> _saveNote() async {
    if (_notesDir == null || _titleCtrl.text.trim().isEmpty) return;
    final safeName = _titleCtrl.text.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(p.join(_notesDir!, '$safeName.txt'));
    final content = '${_titleCtrl.text.trim()}\n---\n${_bodyCtrl.text}';
    await file.writeAsString(content);
    _titleCtrl.clear();
    _bodyCtrl.clear();
    await _loadNotes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note saved: $safeName.txt'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _loadNote(_NoteFile note) async {
    final content = await note.file.readAsString();
    final parts = content.split('\n---\n');
    setState(() {
      _selectedNote = note;
      _titleCtrl.text = parts.isNotEmpty ? parts[0].trim() : '';
      _bodyCtrl.text = parts.length > 1 ? parts.sublist(1).join('\n---\n') : '';
    });
  }

  Future<void> _deleteNote(_NoteFile note) async {
    await note.file.delete();
    if (_selectedNote?.file.path == note.file.path) {
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _selectedNote = null;
    }
    await _loadNotes();
  }

  Future<void> _deleteCurrent() async {
    if (_selectedNote == null) return;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Note'),
      content: Text('Delete "${_titleCtrl.text}"?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
    ));
    if (confirm == true) {
      await _selectedNote!.file.delete();
      _titleCtrl.clear();
      _bodyCtrl.clear();
      setState(() => _selectedNote = null);
      await _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = theme.extension<AppColors>()!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          if (_selectedNote != null)
            IconButton(icon: const Icon(Icons.delete_rounded, color: Color(0xFFE57373)), onPressed: _deleteCurrent),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: ac.primary))
          : Row(
              children: [
                if (_notes.isNotEmpty)
                  SizedBox(width: 200, child: _buildSidebar(theme, ac)),
                Container(width: 1, color: ac.outline.withAlpha(80)),
                Expanded(child: _buildEditor(theme, ac)),
              ],
            ),
    );
  }

  Widget _buildSidebar(ThemeData theme, AppColors ac) {
    return Container(
      color: ac.surfaceVariant,
      child: ListView.builder(
        itemCount: _notes.length,
        itemBuilder: (_, i) {
          final note = _notes[i];
          final isSelected = _selectedNote?.file.path == note.file.path;
          final name = p.basenameWithoutExtension(note.file.path);
          final date = DateFormat('MM/dd').format(note.file.lastModifiedSync());
          return Container(
            decoration: BoxDecoration(
              color: isSelected ? ac.primaryContainer.withAlpha(100) : Colors.transparent,
              border: isSelected ? Border(right: BorderSide(color: ac.primary, width: 2)) : null,
            ),
            child: ListTile(
              dense: true,
              selected: isSelected,
              title: Text(name, style: TextStyle(color: ac.cream, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(date, style: TextStyle(color: ac.onSurfaceDim, fontSize: 10)),
              onTap: () => _loadNote(note),
              trailing: IconButton(
                iconSize: 16,
                icon: Icon(Icons.close_rounded, color: ac.onSurfaceDim.withAlpha(100)),
                onPressed: () => _deleteNote(note),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditor(ThemeData theme, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _titleCtrl,
            style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Note title...',
              prefixIcon: Icon(Icons.title_rounded, color: ac.onSurfaceDim),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _bodyCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(color: ac.cream),
              decoration: const InputDecoration(
                hintText: 'Write your notes here...',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: ac.primary.withAlpha(50), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: FilledButton.icon(
              onPressed: _saveNote,
              icon: const Icon(Icons.save_rounded),
              label: Text(_selectedNote != null ? 'Update Note' : 'Save Note'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteFile {
  final File file;
  const _NoteFile(this.file);
}
