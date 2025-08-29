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

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '기록 없음';
    try {
      final dt = DateTime.tryParse(iso);
      if (dt == null) return '기록 없음';
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return '기록 없음';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final folders = await DBHelper.getAllFoldersWithStats();
    if (!mounted) return;
    setState(() {
      _folderList = folders;
    });
  }

  void _showAddFolderDialog() {
    String folderName = '';
    String folderDescription = '';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateSB) {
          final bool canSubmit = folderName.trim().isNotEmpty;
          return AlertDialog(
            title: const Text('폴더 추가'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '폴더 이름(필수)'),
                    onChanged: (value) => setStateSB(() => folderName = value),
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: '폴더 설명 (선택)'),
                    onChanged: (value) => setStateSB(() => folderDescription = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('취소'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text('추가'),
                onPressed: canSubmit
                    ? () async {
                        final exists = await DBHelper.folderExists(folderName);
                        if (exists) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('이미 존재하는 폴더 이름입니다.')),
                          );
                          return;
                        }
                        await DBHelper.insertFolder(
                          folderName: folderName.trim(),
                          folderDescription: folderDescription.trim(),
                        );
                        if (!mounted) return;
                        Navigator.pop(context);
                        await _loadFolders();
                      }
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  void _showWhatIsDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.medical_information_rounded,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              
              // 제목
              Text(
                '복약이력저장이란?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // 설명 항목들
              _buildInfoItem(
                icon: Icons.folder_open_rounded,
                text: '복용한 약을 폴더별로 모아두고 나중에 쉽게 찾아볼 수 있어요.',
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              
              _buildInfoItem(
                icon: Icons.category_rounded,
                text: '예: "감기 때 먹은 약", "부모님 약" 처럼 상황/가족별로 정리해두세요.',
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 16),
              
              _buildInfoItem(
                icon: Icons.touch_app_rounded,
                text: '폴더를 눌러 약을 추가/삭제할 수 있습니다.',
                color: Theme.of(context).colorScheme.tertiary,
              ),
              
              const SizedBox(height: 24),
              
              // 닫기 버튼
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '확인했어요',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.08),
            theme.colorScheme.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 메인 콘텐츠
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.medical_information_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '복약이력저장',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '복용한 약을 폴더별로 모아두고\n필요할 때 빠르게 확인하세요',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 자세히 버튼
                Container(
                  width: double.infinity,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _showWhatIsDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.help_outline_rounded,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '자세히 알아보기',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text('복약이력저장'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: '폴더 추가',
            onPressed: _showAddFolderDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildInfoBanner(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFolders,
              child: _folderList.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.folder_open, size: 72, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text('아직 만들어진 폴더가 없어요.'),
                              const SizedBox(height: 6),
                              const Text('복용한 약을 폴더별로 모아 기록해보세요.', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 16),
                              FilledButton.tonal(
                                onPressed: _showAddFolderDialog,
                                child: const Text('폴더 만들기'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _folderList.length,
                      itemBuilder: (context, index) {
                        final folder = _folderList[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                                ),
                              ),
                              child: Icon(
                                Icons.folder,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (folder['folder_name'] ?? '') as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 개수 배지
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.medication_outlined, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${folder['pill_count'] ?? 0}개',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    if (((folder['folder_description'] ?? '') as String).trim().isNotEmpty)
      Container(
        margin: const EdgeInsets.only(top: 4, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.18),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.sticky_note_2_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.9),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (folder['folder_description'] as String),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.95),
                ),
              ),
            ),
          ],
        ),
      ),
    Row(
      children: [
        Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '최근 저장: ${_fmtDate(folder['last_updated'] as String?)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  ],
),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FavoritePillListScreen(folderName: (folder['folder_name'] as String)),
                                ),
                              );
                              if (result == true) {
                                await _loadFolders(); // 돌아오면 갱신
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure data is fresh whenever dependencies change (including first build)
    _loadFolders();
  }
}