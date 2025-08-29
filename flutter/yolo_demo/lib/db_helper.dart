import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:developer';
import 'models/pill_data.dart';

// ===== Reserved (legacy) folder names we do not allow any more =====
const Set<String> kReservedFolderNames = {
  '기본 폴더',
  '기본폴더',
  '기본',
  'default',
  'default folder',
};

bool _isReservedFolderName(String? name) {
  if (name == null) return false;
  final s = name.trim();
  if (s.isEmpty) return false;
  // compare both original and lowercase for safety
  if (kReservedFolderNames.contains(s)) return true;
  if (kReservedFolderNames.contains(s.toLowerCase())) return true;
  return false;
}

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
      version: 16,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        try {
          await db.execute('ALTER TABLE recent_pills ADD COLUMN image_url TEXT;');
        } catch (e) {
          // Column may already exist; ignore
        }
        
        // entpName 컬럼 추가 (버전 16)
        if (oldVersion < 16) {
          try {
            await db.execute('ALTER TABLE favorite_pills ADD COLUMN entp_name TEXT;');
          } catch (e) {
            // Column may already exist; ignore
          }
        }
        
        await db.execute('DROP TABLE IF EXISTS favorite_pills');
        await db.execute('DROP TABLE IF EXISTS recent_pills');
        await db.execute('DROP TABLE IF EXISTS folders');
        await _onCreate(db, newVersion);
      },
      onOpen: (db) async {
        // Ensure default seed rows exist even if the DB already existed
        await _ensureSeedData(db);
      },
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
        image_url TEXT,
        timestamp TEXT NOT NULL,
        user_id TEXT,
        UNIQUE(item_seq, user_id)
      )
    ''');

      // 즐겨찾기 테이블 (sqlite & mongodb)
      // ⚠️ folder_name 기본값(기본 폴더) 제거 + NOT NULL
      await db.execute('''
        CREATE TABLE favorite_pills (
          folder_name TEXT NOT NULL,
          item_seq TEXT,
          item_name TEXT NOT NULL,
          entp_name TEXT,
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
  }

  static Future<void> _ensureSeedData(Database db) async {
    // Ensure folders table exists (older DBs may not have it)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folder_name TEXT UNIQUE NOT NULL,
        folder_description TEXT
      )
    ''');
  }

  // 최근 검색 알약 추가
  static Future<void> addRecentPill({
    required String itemSeq,
    required String itemName,
    required String userId,
    required String timestamp,
    String? imageUrl, // ✅ 추가
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
            'item_name': itemName,
            'image_url': imageUrl,
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
            'image_url': imageUrl,
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
  static Future<List<PillData>> getRecentPills() async {
    final db = await database;
    final maps = await db.query(
      'recent_pills',
      orderBy: 'datetime(timestamp) DESC, id DESC',
    );
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
    String? entpName,
    required String userId,
    required String folderName,
    String? imageUrl,
  }) async {
    try {
      log('📝 addFavoritePill 호출됨 - $itemName (폴더: $folderName)');

      if (_isReservedFolderName(folderName)) {
        log('🚫 예약 폴더명으로는 저장할 수 없습니다: $folderName');
        return;
      }
      final db = await database;

      // Ensure folder row exists (so getAllFoldersWithStats LEFT JOIN is stable)
      await db.insert(
        'folders',
        {
          'folder_name': folderName,
          'folder_description': '',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // Insert/replace favorite with a guaranteed timestamp
      await db.insert(
        'favorite_pills',
        {
          'folder_name': folderName,
          'item_seq': itemSeq,
          'item_name': itemName,
          'entp_name': entpName,
          'image_url': imageUrl,
          'timestamp': DateTime.now().toIso8601String(),
          'user_id': userId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      log('✅ 즐겨찾기 삽입 성공: $itemName');
    } catch (e) {
      log('❌ 즐겨찾기 삽입 실패: $e');
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
    if (_isReservedFolderName(folderName)) {
      log('🚫 예약 폴더명 삭제 차단: $folderName');
      return;
    }
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
    return result
        .map((row) => row['folder_name'] as String)
        .where((name) => !_isReservedFolderName(name))
        .toList();
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
    if (_isReservedFolderName(folderName)) {
      log('🚫 예약 폴더명 생성 차단: $folderName');
      return;
    }
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

  // 🔁 Backward-compat: some screens still call addFolder(...)
  static Future<void> addFolder(String folderName, {String? folderDescription}) async {
    // Delegate to the new API
    await insertFolder(folderName: folderName, folderDescription: folderDescription);
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
    final rows = await db.query('folders', orderBy: 'id ASC');
    return rows.where((r) => !_isReservedFolderName(r['folder_name']?.toString())).toList();
  }

  // =========================
  // 📊 복약이력(즐겨찾기) 통계 헬퍼
  // - 폴더별 약 개수 / 최근 업데이트 시간
  // - 화면 배지/보조정보 표시에 사용
  // =========================

  /// 🔹 호환용: 전체 폴더 + 개수/최근업데이트를 한 번에
  /// 기존의 getFolderStats() (전체)와 동일한 기능을 새 이름으로 노출
  static Future<List<Map<String, dynamic>>> getAllFoldersWithStats() async {
    final db = await database;
    // Aggregate pill count and last updated per folder from favorite_pills
    final rows = await db.rawQuery('''
      SELECT
        f.folder_name                                   AS folder_name,
        IFNULL(f.folder_description, '')                AS folder_description,
        IFNULL(s.cnt, 0)                                AS pill_count,
        s.last_ts                                       AS last_updated
      FROM folders f
      LEFT JOIN (
        SELECT
          folder_name,
          COUNT(*) AS cnt,
          MAX(timestamp) AS last_ts
        FROM favorite_pills
        GROUP BY folder_name
      ) s
      ON s.folder_name = f.folder_name
      ORDER BY f.id ASC
    ''');

    // Filter out reserved/legacy folder names for safety
    final filtered = rows.where((r) => !_isReservedFolderName(r['folder_name']?.toString())).toList();

    // Normalize types (sqflite returns dynamic)
    return filtered.map((row) {
      final rawCnt = row['pill_count'];
      final cnt = (rawCnt is int) ? rawCnt : (rawCnt is num ? rawCnt.toInt() : 0);
      final lastTs = row['last_updated'];
      return {
        'folder_name': row['folder_name'] as String,
        'folder_description': (row['folder_description'] ?? '') as String,
        'pill_count': cnt,
        'last_updated': (lastTs is String && lastTs.isNotEmpty) ? lastTs : null,
      };
    }).toList();
  }

  /// 🔹 호환용: 특정 폴더의 개수/최근업데이트 단건
  /// Dart는 메서드 오버로딩을 허용하지 않으므로, 기존 getFolderStat()에 대한 별칭을 제공합니다.
  static Future<Map<String, dynamic>> getFolderStatsByName(String folderName) async {
    return await getFolderStat(folderName);
  }

  /// 특정 폴더의 약 개수
  static Future<int> getFavoriteCount({required String folderName}) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM favorite_pills WHERE folder_name = ?',
      [folderName],
    );
    final cnt = (res.isNotEmpty ? res.first['cnt'] : 0);
    if (cnt is int) return cnt;
    if (cnt is num) return cnt.toInt();
    return 0;
  }

  /// 전체(모든 폴더 합계)의 약 개수
  static Future<int> getTotalFavoriteCount() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) AS cnt FROM favorite_pills');
    final cnt = (res.isNotEmpty ? res.first['cnt'] : 0);
    if (cnt is int) return cnt;
    if (cnt is num) return cnt.toInt();
    return 0;
  }

  /// 특정 폴더의 최근 업데이트 시간 (ISO8601 문자열; 없으면 null)
  static Future<String?> getFolderLastUpdated({required String folderName}) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT MAX(timestamp) AS last_ts FROM favorite_pills WHERE folder_name = ?',
      [folderName],
    );
    if (res.isEmpty) return null;
    final v = res.first['last_ts'];
    return (v is String && v.isNotEmpty) ? v : null;
  }

  /// 전체(모든 폴더) 중 가장 최근 업데이트 시간 (ISO8601 문자열; 없으면 null)
  static Future<String?> getFavoritesLastUpdated() async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT MAX(timestamp) AS last_ts FROM favorite_pills',
    );
    if (res.isEmpty) return null;
    final v = res.first['last_ts'];
    return (v is String && v.isNotEmpty) ? v : null;
  }

  /// 폴더별 개수/최근업데이트를 한 번에 가져오기
  /// 반환 예:
  /// [
  ///   { "folder_name": "기본 폴더", "count": 12, "last_ts": "2025-08-18T12:34:56.000Z" },
  ///   { "folder_name": "감기약",   "count":  3, "last_ts": "2025-08-17T10:00:00.000Z" },
  /// ]
  static Future<List<Map<String, dynamic>>> getFolderStats() async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT 
        folder_name,
        COUNT(*) AS count,
        MAX(timestamp) AS last_ts
      FROM favorite_pills
      GROUP BY folder_name
      ORDER BY folder_name ASC
    ''');

    // 타입 안전 변환
    return res.map((row) {
      final rawCount = row['count'];
      final count = (rawCount is int) ? rawCount : (rawCount is num ? rawCount.toInt() : 0);
      final lastTs = row['last_ts'];
      return {
        'folder_name': row['folder_name'] as String,
        'count': count,
        'last_ts': (lastTs is String && lastTs.isNotEmpty) ? lastTs : null,
      };
    }).toList();
  }

  /// 특정 폴더의 간단 통계(개수 + 최근업데이트) 단건
  static Future<Map<String, dynamic>> getFolderStat(String folderName) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT 
        COUNT(*) AS count,
        MAX(timestamp) AS last_ts
      FROM favorite_pills
      WHERE folder_name = ?
    ''', [folderName]);

    int count = 0;
    String? lastTs;
    if (res.isNotEmpty) {
      final rawCount = res.first['count'];
      count = (rawCount is int) ? rawCount : (rawCount is num ? rawCount.toInt() : 0);
      final v = res.first['last_ts'];
      lastTs = (v is String && v.isNotEmpty) ? v : null;
    }
    return {
      'folder_name': folderName,
      'count': count,
      'last_ts': lastTs,
    };
  }

  /// 최근 검색에서 특정 약물의 이미지 URL을 업데이트합니다.
  static Future<int> updateRecentImage({
    required String itemSeq,
    required String imageUrl,
    String? userId,
  }) async {
    final db = await database;
    final where = (userId != null && userId.isNotEmpty)
        ? 'user_id = ? AND item_seq = ?'
        : 'item_seq = ?';
    final whereArgs = (userId != null && userId.isNotEmpty)
        ? [userId, itemSeq]
        : [itemSeq];
    
    return db.update(
      'recent_pills',
      {
        'image_url': imageUrl,
        'timestamp': DateTime.now().toIso8601String(),
      },
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// 즐겨찾기에서 특정 약물의 이미지 URL을 업데이트합니다.
  static Future<int> updateFavoriteImage({
    required String itemSeq,
    required String imageUrl,
    String? userId,
  }) async {
    final db = await database;
    final where = (userId != null && userId.isNotEmpty)
        ? 'user_id = ? AND item_seq = ?'
        : 'item_seq = ?';
    final whereArgs = (userId != null && userId.isNotEmpty)
        ? [userId, itemSeq]
        : [itemSeq];
    
    return db.update(
      'favorite_pills',
      {
        'image_url': imageUrl,
        'timestamp': DateTime.now().toIso8601String(),
      },
      where: where,
      whereArgs: whereArgs,
    );
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

    // 모든 폴더 중 '예약 폴더명'을 제외한 목록
    final folderResults = await db.query('folders');

    for (var folder in folderResults) {
      final name = folder['folder_name'] as String;
      if (_isReservedFolderName(name)) {
        continue; // 예약 폴더는 건드리지 않음(이미 purgeReservedFolders가 정리함)
      }
      await db.delete('favorite_pills', where: 'folder_name = ?', whereArgs: [name]);
      await db.delete('folders', where: 'folder_name = ?', whereArgs: [name]);
    }

    log("🗑️ 즐겨찾기 폴더 전체 삭제 완료(예약 폴더 제외)");
  }

  /// 🔧 레거시 '기본 폴더' 흔적 정리(앱 시작 1회 호출 권장)
  static Future<void> purgeReservedFolders() async {
    final db = await database;
    if (kReservedFolderNames.isEmpty) return;

    final placeholders = List.filled(kReservedFolderNames.length, '?').join(',');
    final args = kReservedFolderNames.toList();

    // 1) 해당 폴더 소속 즐겨찾기 삭제
    await db.delete(
      'favorite_pills',
      where: 'LOWER(folder_name) IN ($placeholders)',
      whereArgs: args.map((e) => e.toString().toLowerCase()).toList(),
    );

    // 2) 폴더 자체 삭제
    await db.delete(
      'folders',
      where: 'LOWER(folder_name) IN ($placeholders)',
      whereArgs: args.map((e) => e.toString().toLowerCase()).toList(),
    );

    log('🧹 purgeReservedFolders: 레거시 기본 폴더 및 포함 항목 제거 완료');
  }
}