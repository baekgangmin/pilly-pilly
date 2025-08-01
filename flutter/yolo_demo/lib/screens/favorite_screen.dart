import 'package:flutter/material.dart';
import 'package:yolo_demo/db_helper.dart';
import 'package:yolo_demo/screens/favorite_pill_list_screen.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({Key? key}) : super(key: key);

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  List<Map<String, dynamic>> _folderList = [];

  @override
  void initState() {
    super.initState();
    _ensureDefaultFolder();
    _loadFolders();
  }

  Future<void> _ensureDefaultFolder() async {
    final exists = await DBHelper.folderExists('기본 폴더');
    if (!exists) {
      await DBHelper.insertFolder(
        folderName: '기본 폴더',
        folderDescription: '',
      );
    }
  }

  Future<void> _loadFolders() async {
    final folders = await DBHelper.getAllFolders();
    setState(() {
      _folderList = folders;
    });
  }

  void _showAddFolderDialog() {
    String folderName = '';
    String folderDescription = '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('폴더 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: '폴더 이름'),
              onChanged: (value) => folderName = value,
            ),
            TextField(
              decoration: InputDecoration(labelText: '폴더 설명 (선택)'),
              onChanged: (value) => folderDescription = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('취소'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('추가'),
            onPressed: () async {
              final exists = await DBHelper.folderExists(folderName);
              if (exists || folderName.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('중복되었거나 이름이 비어 있습니다.')),
                );
                return;
              }
              await DBHelper.insertFolder(
                folderName: folderName,
                folderDescription: folderDescription,
              );
              Navigator.pop(context);
              _loadFolders();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("즐겨찾기 폴더"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddFolderDialog,
          ),
        ],
      ),
      body: _folderList.isEmpty
          ? const Center(child: Text("📁 폴더가 없어요"))
          : ListView.builder(
              itemCount: _folderList.length,
              itemBuilder: (context, index) {
                final folder = _folderList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Icon(Icons.folder),
                    title: Text(folder['folder_name']),
                    subtitle: (folder['folder_description'] ?? '').isEmpty
                    ? null
                    : Text(folder['folder_description'], style: TextStyle(color: Colors.grey)),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FavoritePillListScreen(folderName: folder['folder_name']),
                        ),
                      );

                      if (result == true) {
                        _loadFolders(); // 삭제 후 폴더 목록 다시 불러오기
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}