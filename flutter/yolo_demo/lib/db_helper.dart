import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:developer';
import 'models/pill_data.dart';

class DBHelper {
  static const _databaseName = 'pilly_app.db';
  static Database? _db;

  // 데이터베이스 접근 함수
  static Future<Database> get database async {
    if (_db != null) return _db!;
    log('📦 DB 초기화 중...');
    _db = await _initDB();
    log('✅ DB 열림!');
    return _db!;
  }

  static String get databaseName => _databaseName;

  // DB 초기화
  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: 12,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS favorite_pills');
        await db.execute('DROP TABLE IF EXISTS recent_pills');
        await db.execute('DROP TABLE IF EXISTS folders');
        await _onCreate(db, newVersion);
      }
    );
  }

  // 테이블 생성
  static Future<void> _onCreate(Database db, int version) async {
    // 최근 검색 테이블 (sqlite)
    await db.execute('''
      CREATE TABLE recent_pills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_seq TEXT NOT NULL,
        item_name TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        user_id TEXT,
        UNIQUE(item_seq, user_id)
      )
    ''');

    // 즐겨찾기 테이블 (sqlite & mongodb)
    await db.execute('''
      CREATE TABLE favorite_pills (
        folder_name TEXT DEFAULT '기본 폴더',
        item_seq TEXT,
        item_name TEXT NOT NULL,
        image_url TEXT,
        timestamp TEXT NOT NULL,
        user_id TEXT,
        PRIMARY KEY (item_seq, folder_name)
      )
    ''');

    // 즐겨찾기 폴더
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folder_name TEXT UNIQUE NOT NULL,
        folder_description TEXT
      )
    ''');

    // 기본 폴더 자동 생성
    await db.insert('folders', {
      'folder_name': '기본 폴더',
      'folder_description' : '즐겨찾기 기본 폴더입니다.'
    });
  }

  // 최근 검색 알약 추가
  static Future<void> addRecentPill({
    required String itemSeq,
    required String itemName,
    required String userId,
    required String timestamp,
  }) async {
    try {
      final db = await database;

      // 1. 중복 체크
      final existing = await db.query(
        'recent_pills',
        where: 'item_seq = ? AND user_id = ?',
        whereArgs: [itemSeq, userId],
      );

      if (existing.isNotEmpty) {
        // 2. 이미 있으면 timestamp만 갱신
        await db.update(
          'recent_pills',
          {
            'timestamp': timestamp,
          },
          where: 'item_seq = ? AND user_id = ?',
          whereArgs: [itemSeq, userId],
        );
        print("🕐 기존 기록 timestamp 갱신");
      } else {
        // 3. 없으면 새로 insert
        await db.insert(
          'recent_pills',
          {
            'item_seq': itemSeq,
            'item_name': itemName,
            'timestamp': timestamp,
            'user_id': userId,
          },
        );
        print("🆕 새 검색어 삽입");
      }
    } catch (e) {
      print("❌ 최근 검색 삽입 실패: $e");
    }
  }

  // 최근 검색 알약 가져오기
  static Future<List<PillData>> getRecentPills({int limit =10}) async {
    final db = await database;
    final maps = await db.query('recent_pills', orderBy: 'timestamp DESC', limit: limit);
    return maps.map((e) => PillData.fromMap(e)).toList();
  }

  // 최근 검색 알약 삭제
  static Future<void> deleteRecentPill(String itemSeq) async {
    final db = await database;
    final userId = 'guest';
    await db.delete(
      'recent_pills',
      where: 'item_seq = ? AND user_id = ?',
      whereArgs: [itemSeq, userId],
    );
  }

  // 전체 최근 검색 기록 삭제
  static Future<void> deleteRecentPills() async {
    final db = await database;
    await db.delete('recent_pills');
    log("🗑️ 최근 검색 전체 삭제 완료");
  }

  // 즐겨찾기 추가
  static Future<void> addFavoritePill({
    required String itemSeq,
    required String itemName,
    required String userId,
    String? imageUrl,
    String folderName = '기본 폴더'
  }) async {
    try {
      log('📝 addFavoritePill 호출됨 - $itemName (폴더: $folderName)');
      final db = await database;
      log('📥 즐겨찾기 열기 성공');

      await db.insert(
        'favorite_pills',
        {
          'folder_name': folderName,
          'item_seq': itemSeq,
          'item_name': itemName,
          'image_url': imageUrl,
          'timestamp': DateTime.now().toIso8601String(),
          'user_id': userId,
          
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ 즐겨찾기 삽입 성공: $itemName');
    } catch (e) {
      print("❌ 즐겨찾기 삽입 실패: $e");
    }
    
    log('✅ insert 완료!');
  }

  // 즐겨찾기에서 약 삭제
  static Future<void> removeFavoritePill({
    required String itemSeq,
    String? folderName,
  }) async {
    final db = await database;

    if (folderName != null) {
      await db.delete(
        'favorite_pills',
        where: 'item_seq = ? AND folder_name = ?',
        whereArgs: [itemSeq, folderName],
      );
    } else {
      await db.delete(
        'favorite_pills',
        where: 'item_seq = ?',
        whereArgs: [itemSeq],
      );
    }
  }
  // 즐겨찾기 폴더 및 해당 약 전부 삭제
  static Future<void> deleteFolder(String folderName) async {
    if (folderName == '기본 폴더') return;

    final db = await database;
    await db.delete('favorite_pills', where: 'folder_name = ?', whereArgs: [folderName]);
    await db.delete('folders', where: 'folder_name = ?', whereArgs: [folderName]);
  }



  // 즐겨찾기 여부 확인
  static Future<bool> isFavoritePill(String itemSeq) async {
    final db = await database;
    final result = await db.query(
      'favorite_pills',
      where: 'item_seq = ?',
      whereArgs: [itemSeq],
    );
    return result.isNotEmpty;
  }

  static Future<List<Map<String, dynamic>>> getFavoritePills({
    String? userId,
    String? folderName,
  }) async {
    final db = await database;

    String? whereClause;
    List<String> whereArgs = [];

    if (userId != null) {
      whereClause = 'user_id = ?';
      whereArgs.add(userId);
    }

    if (folderName != null) {
      if (whereClause != null) {
        whereClause += ' AND folder_name = ?';
      } else {
        whereClause = 'folder_name = ?';
      }
      whereArgs.add(folderName);
    }

    return await db.query(
      'favorite_pills',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'timestamp DESC',
    );
  }

  // 폴더명만 중복 없이 가져오기
  static Future<List<String>> getDistinctFolders() async {
    final db = await database;
    final result = await db.rawQuery('SELECT DISTINCT folder_name FROM favorite_pills');
    return result.map((row) => row['folder_name'] as String).toList();
  }

  // 특정 폴더 안 즐겨찾기 약만 가져오기
  static Future<List<Map<String, dynamic>>> getFavoritePillsByFolder(String folderName) async {
    final db = await database;
    return await db.query(
      'favorite_pills',
      where: 'folder_name = ?',
      whereArgs: [folderName],
      orderBy: 'timestamp DESC',
    );
  }
  // ✅ 새 폴더 추가
  static Future<void> insertFolder({
    required String folderName,
    String? folderDescription,
  }) async {
    final db = await database;
    await db.insert(
      'folders',
      {
        'folder_name': folderName,
        'folder_description': folderDescription ?? '',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // ✅ 폴더 중복 체크
  static Future<bool> folderExists(String folderName) async {
    final db = await database;
    final result = await db.query(
      'folders',
      where: 'folder_name = ?',
      whereArgs: [folderName],
    );
    return result.isNotEmpty;
  }

  // ✅ 폴더 전체 목록 가져오기
  static Future<List<Map<String, dynamic>>> getAllFolders() async {
    final db = await database;
    return await db.query('folders', orderBy: 'id ASC');
  }


  // ✅ 전체 DB 삭제 함수 (캐시 초기화용)
  static Future<void> deleteDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    final fullPath = join(dbPath, _databaseName);
    final dbFile = File(fullPath);

    if (await dbFile.exists()) {
      await dbFile.delete();
      _db = null;
      log("🧹 전체 DB 파일 삭제 완료 (캐시 초기화)");
    } else {
      log("ℹ️ DB 파일이 존재하지 않아 삭제 생략");
    }
  }

  // 기본 폴더 제외 전체 즐겨찾기 폴더 및 약 삭제
  static Future<void> deleteFavoriteFolders() async {
    final db = await database;

    // 기본 폴더 제외 모든 폴더 이름 가져오기
    final folderResults = await db.query(
      'folders',
      where: 'folder_name != ?',
      whereArgs: ['기본 폴더'],
    );

    for (var folder in folderResults) {
      final folderName = folder['folder_name'] as String;

      // 폴더에 속한 약 삭제
      await db.delete(
        'favorite_pills',
        where: 'folder_name = ?',
        whereArgs: [folderName],
      );

      // 폴더 자체 삭제
      await db.delete(
        'folders',
        where: 'folder_name = ?',
        whereArgs: [folderName],
      );
    }

    // 기본 폴더 내부 약도 삭제
    await db.delete(
      'favorite_pills',
      where: 'folder_name = ?',
      whereArgs: ['기본 폴더'],
    );
    log("🗑️ 기본 폴더 내부 약 삭제 완료");

    log("🗑️ 기본 폴더 제외 즐겨찾기 폴더 전체 삭제 완료");
  }
}