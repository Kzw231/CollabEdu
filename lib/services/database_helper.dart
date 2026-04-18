import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../models/comment.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const String projectsTable = 'projects';
  static const String tasksTable = 'tasks';
  static const String commentsTable = 'comments';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'collabedu.db');
    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $projectsTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        deadline INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        members TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tasksTable (
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        assignedTo TEXT NOT NULL,
        startDate INTEGER NOT NULL,
        deadline INTEGER NOT NULL,
        actualStartDate INTEGER,
        progressPercent INTEGER NOT NULL DEFAULT 0,
        estimatedHours INTEGER NOT NULL DEFAULT 0,
        isCompleted INTEGER NOT NULL,
        completedAt INTEGER,
        priority INTEGER NOT NULL DEFAULT 1,
        tags TEXT NOT NULL DEFAULT '',
        createdAt INTEGER NOT NULL,
        parentTaskId TEXT,
        FOREIGN KEY (projectId) REFERENCES $projectsTable (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE $commentsTable (
        id TEXT PRIMARY KEY,
        taskId TEXT NOT NULL,
        author TEXT NOT NULL,
        content TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (taskId) REFERENCES $tasksTable (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $projectsTable ADD COLUMN description TEXT NOT NULL DEFAULT ""');
      await db.execute('ALTER TABLE $tasksTable ADD COLUMN description TEXT NOT NULL DEFAULT ""');
      await db.execute('ALTER TABLE $tasksTable ADD COLUMN priority INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE $tasksTable ADD COLUMN tags TEXT NOT NULL DEFAULT ""');
      await db.execute('''
        CREATE TABLE $commentsTable (
          id TEXT PRIMARY KEY,
          taskId TEXT NOT NULL,
          author TEXT NOT NULL,
          content TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          FOREIGN KEY (taskId) REFERENCES $tasksTable (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE $tasksTable ADD COLUMN startDate INTEGER');
      await db.execute('ALTER TABLE $tasksTable ADD COLUMN progressPercent INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE $tasksTable ADD COLUMN estimatedHours INTEGER NOT NULL DEFAULT 0');
      await db.rawUpdate('UPDATE $tasksTable SET startDate = createdAt');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE $tasksTable ADD COLUMN completedAt INTEGER');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE $tasksTable ADD COLUMN parentTaskId TEXT');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE $tasksTable ADD COLUMN actualStartDate INTEGER');
    }
  }

  // Projects
  Future<List<Project>> getAllProjects() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(projectsTable);
    return List.generate(maps.length, (i) => Project.fromMap(maps[i]));
  }

  Future<void> insertProject(Project project) async {
    final db = await database;
    await db.insert(projectsTable, project.toMap());
  }

  Future<void> updateProject(Project project) async {
    final db = await database;
    await db.update(projectsTable, project.toMap(), where: 'id = ?', whereArgs: [project.id]);
  }

  Future<void> deleteProject(String id) async {
    final db = await database;
    await db.delete(tasksTable, where: 'projectId = ?', whereArgs: [id]);
    await db.delete(projectsTable, where: 'id = ?', whereArgs: [id]);
  }

  // Tasks
  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tasksTable);
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<Task?> getTaskById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tasksTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  Future<List<Task>> getSubtasks(String parentTaskId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tasksTable,
      where: 'parentTaskId = ?',
      whereArgs: [parentTaskId],
    );
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<void> insertTask(Task task) async {
    final db = await database;
    await db.insert(tasksTable, task.toMap());
  }

  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update(tasksTable, task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete(tasksTable, where: 'parentTaskId = ?', whereArgs: [id]);
    await db.delete(commentsTable, where: 'taskId = ?', whereArgs: [id]);
    await db.delete(tasksTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTasksForProject(Project project) async {
    final db = await database;
    final tasks = await getAllTasks();
    final batch = db.batch();
    for (var t in tasks) {
      if (t.projectId == project.id) {
        if (t.deadline.isAfter(project.deadline)) t.deadline = project.deadline;
        if (!project.members.contains(t.assignedTo)) {
          t.assignedTo = project.members.isNotEmpty ? project.members.first : "Unassigned";
        }
        batch.update(tasksTable, t.toMap(), where: 'id = ?', whereArgs: [t.id]);
      }
    }
    await batch.commit(noResult: true);
  }

  // Comments
  Future<List<Comment>> getCommentsForTask(String taskId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      commentsTable,
      where: 'taskId = ?',
      whereArgs: [taskId],
      orderBy: 'createdAt ASC',
    );
    return List.generate(maps.length, (i) => Comment.fromMap(maps[i]));
  }

  Future<void> insertComment(Comment comment) async {
    final db = await database;
    await db.insert(commentsTable, comment.toMap());
  }

  Future<void> deleteComment(String id) async {
    final db = await database;
    await db.delete(commentsTable, where: 'id = ?', whereArgs: [id]);
  }
}