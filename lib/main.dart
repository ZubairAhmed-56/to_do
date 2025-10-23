import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? false;
  runApp(MyApp(isDarkMode: isDark));
}

class MyApp extends StatefulWidget {
  final bool isDarkMode;
  const MyApp({super.key, required this.isDarkMode});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
  }

  void _toggleTheme(bool v) async {
    setState(() => _isDark = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Simple TODO',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(
        isDark: _isDark,
        onThemeChanged: _toggleTheme,
      ),
    );
  }
}

class Task {
  String id;
  String title;
  String description;
  String category; // Work, Study, Personal
  DateTime? dueDate;
  bool done;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.category = 'Personal',
    this.dueDate,
    this.done = false,
  });

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'],
        title: j['title'],
        description: j['description'] ?? '',
        category: j['category'] ?? 'Personal',
        dueDate: j['dueDate'] != null ? DateTime.parse(j['dueDate']) : null,
        done: j['done'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'dueDate': dueDate?.toIso8601String(),
        'done': done,
      };
}

class HomePage extends StatefulWidget {
  final bool isDark;
  final void Function(bool) onThemeChanged;
  const HomePage({super.key, required this.isDark, required this.onThemeChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Task> tasks = [];
  bool loading = true;
  String filterCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tasks') ?? '[]';
    final list = json.decode(raw) as List;
    tasks = list.map((e) => Task.fromJson(e)).toList();
    setState(() => loading = false);
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString('tasks', raw);
  }

  void _addTask(Task t) async {
    tasks.insert(0, t);
    await _saveTasks();
    setState(() {});
  }

  void _updateTask(Task t) async {
    final idx = tasks.indexWhere((x) => x.id == t.id);
    if (idx >= 0) tasks[idx] = t;
    await _saveTasks();
    setState(() {});
  }

  void _deleteTask(Task t) async {
    final idx = tasks.indexWhere((x) => x.id == t.id);
    if (idx >= 0) tasks.removeAt(idx);
    await _saveTasks();
    setState(() {});
  }

  int get completedCount => tasks.where((t) => t.done).length;
  int get pendingCount => tasks.where((t) => !t.done).length;

  List<Task> get filteredTasks {
    if (filterCategory == 'All') return tasks;
    return tasks.where((t) => t.category == filterCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text('Done: $completedCount | Pending: $pendingCount'),
          )),
          IconButton(
            icon: Icon(widget.isDark ? Icons.dark_mode : Icons.light_mode),
            onPressed: () {
              widget.onThemeChanged(!widget.isDark);
            },
            tooltip: 'Toggle theme',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildCategoryChips()),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadTasks,
                        tooltip: 'Reload',
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredTasks.isEmpty
                        ? Center(child: Text('No tasks. Tap + to add one.'))
                        : ListView.builder(
                            itemCount: filteredTasks.length,
                            itemBuilder: (context, index) {
                              final t = filteredTasks[index];
                              return _buildTaskCard(t);
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddDialog(),
      ),
    );
  }

  Widget _buildCategoryChips() {
    const cats = ['All', 'Work', 'Study', 'Personal'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: cats.map((c) {
          final selected = filterCategory == c;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(c),
              selected: selected,
              onSelected: (_) => setState(() => filterCategory = c),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskCard(Task t) {
    final textStyle = t.done
        ? const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 16)
        : const TextStyle(fontSize: 16);

    String dueText() {
      if (t.dueDate == null) return 'No due date';
      final now = DateTime.now();
      final diff = t.dueDate!.difference(DateTime(now.year, now.month, now.day));
      final days = diff.inDays;
      if (days == 0) return 'Due today';
      if (days > 0) return 'Due in $days day${days > 1 ? 's' : ''}';
      return 'Overdue by ${-days} day${days < -1 ? 's' : ''}';
    }

    Color categoryColor() {
      switch (t.category) {
        case 'Work':
          return Colors.blue;
        case 'Study':
          return Colors.teal;
        default:
          return Colors.grey;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Checkbox(
          value: t.done,
          onChanged: (v) {
            t.done = v ?? false;
            _updateTask(t);
          },
        ),
        title: Text(t.title, style: textStyle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (t.description.isNotEmpty) Text(t.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor().withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(t.category, style: TextStyle(color: categoryColor())),
                ),
                const SizedBox(width: 8),
                Text(dueText()),
              ],
            )
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _confirmDelete(t),
        ),
      ),
    );
  }

  void _confirmDelete(Task t) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Delete task?'),
            content: Text('Are you sure you want to delete "${t.title}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
    if (ok) _deleteTask(t);
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String cat = 'Personal';
    DateTime? due;

    showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          title: const Text('Add Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: cat,
                  items: const [
                    DropdownMenuItem(value: 'Work', child: Text('Work')),
                    DropdownMenuItem(value: 'Study', child: Text('Study')),
                    DropdownMenuItem(value: 'Personal', child: Text('Personal')),
                  ],
                  onChanged: (v) => setStateDialog(() => cat = v ?? 'Personal'),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(due == null ? 'No due date' : 'Due: ${due!.toLocal().toString().split(' ')[0]}')),
                    TextButton(
                      child: const Text('Pick Date'),
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: DateTime(now.year - 2),
                          lastDate: DateTime(now.year + 5),
                        );
                        if (picked != null) setStateDialog(() => due = picked);
                      },
                    )
                  ],
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title required')));
                  return;
                }
                final t = Task(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: title,
                  description: descCtrl.text.trim(),
                  category: cat,
                  dueDate: due,
                );
                _addTask(t);
                Navigator.pop(c);
              },
              child: const Text('Save'),
            )
          ],
        );
      }),
    );
  }
}
