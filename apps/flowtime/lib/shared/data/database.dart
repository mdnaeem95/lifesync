import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'database.g.dart';

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get name => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get duration => integer()(); // in minutes
  DateTimeColumn get scheduledAt => dateTime()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get taskType => text()(); // focus, meeting, break, admin
  IntColumn get energyRequired => integer()(); // 1-5 scale
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
}

class EnergyLevels extends Table {
  TextColumn get id => text()();
  IntColumn get level => integer()(); // 1-100
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get factors => text().nullable()(); // JSON string
  
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Users, Tasks, EnergyLevels])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  @override
  int get schemaVersion => 1;
  
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle migrations here
      },
    );
  }
  
  // User queries
  Future<User?> getUserById(String id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();
  
  Future<void> insertUser(User user) => into(users).insert(user);
  
  // Task queries
  Future<List<Task>> getTasksForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return (select(tasks)
      ..where((t) => t.scheduledAt.isBetweenValues(startOfDay, endOfDay))
      ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]))
      .get();
  }
  
  Future<void> insertTask(Task task) => into(tasks).insert(task);
  
  Future<void> updateTask(Task task) => update(tasks).replace(task);
  
  // Energy level queries
  Future<List<EnergyLevel>> getEnergyLevelsForPeriod(
    DateTime start,
    DateTime end,
  ) {
    return (select(energyLevels)
      ..where((e) => e.recordedAt.isBetweenValues(start, end))
      ..orderBy([(e) => OrderingTerm.desc(e.recordedAt)]))
      .get();
  }
  
  Future<void> recordEnergyLevel(EnergyLevel level) =>
      into(energyLevels).insert(level);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, 'flowtime.db');
    
    return SqfliteQueryExecutor(
      path: dbPath,
      singleInstance: true,
      logStatements: true,
    );
  });
}

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});