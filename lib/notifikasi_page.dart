import 'package:flutter/material.dart';

import 'daftar_ijin_page.dart';
import 'main.dart';
import 'notifikasi_store.dart';
import 'push_notification_service.dart';

/// Riwayat notifikasi (status izin & pengumuman) yang tersimpan di perangkat.
class NotifikasiPage extends StatefulWidget {
  const NotifikasiPage({super.key});

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage> {
  List<NotifikasiItem> _items = [];
  bool _loading = true;

  int get _unread => _items.where((e) => !e.read).length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await PushNotificationService.importDelivered();
    final items = await NotifikasiStore.list();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _markAllRead() async {
    await NotifikasiStore.markAllRead();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua notifikasi ditandai sudah dibaca')),
    );
  }

  Future<void> _open(NotifikasiItem item) async {
    if (!item.read) {
      await NotifikasiStore.markRead(item.id);
      if (!mounted) return;
      setState(() => item.read = true);
    }
    if (!mounted) return;

    if (item.type == 'ijin') {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DaftarIjinPage()));
    } else {
      await showPengumumanDialog(context, judul: item.judul, isi: item.isi);
    }
  }

  String _formatWaktu(DateTime t) {
    final local = t.toLocal();
    final jam =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return '${formatDateIndonesian(local)} • $jam';
  }

  (IconData, Color) _iconFor(NotifikasiItem item) {
    if (item.type == 'ijin') {
      final judul = item.judul.toLowerCase();
      if (judul.contains('ditolak')) {
        return (Icons.cancel, Colors.red.shade600);
      }
      if (judul.contains('disetujui')) {
        return (Icons.assignment_turned_in, Colors.green.shade600);
      }
      return (Icons.assignment, Colors.deepPurple.shade600);
    }
    return (Icons.campaign, Colors.orange.shade700);
  }

  Widget _buildItem(NotifikasiItem item) {
    final unread = !item.read;
    final (icon, color) = _iconFor(item);

    return Material(
      color: unread ? Colors.deepPurple.shade50 : Colors.white,
      child: InkWell(
        onTap: () => _open(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: unread ? 0.15 : 0.08),
                child: Icon(
                  icon,
                  color: unread ? color : color.withValues(alpha: 0.6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.judul.isEmpty ? 'Notifikasi' : item.judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: unread ? FontWeight.bold : FontWeight.w500,
                        color: unread ? Colors.black87 : Colors.grey.shade700,
                      ),
                    ),
                    if (item.isi.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.isi,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: unread
                              ? Colors.grey.shade800
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _formatWaktu(item.receivedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (unread)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade600,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    // ListView agar tetap bisa ditarik untuk refresh.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(
          Icons.notifications_none,
          size: 72,
          color: Colors.deepPurple.shade200,
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Belum ada notifikasi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Status izin dan pengumuman sekolah yang diterima di HP ini '
            'akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Notifikasi', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Tandai semua dibaca',
            icon: const Icon(Icons.done_all),
            color: Colors.white,
            disabledColor: Colors.white38,
            onPressed: _unread == 0 ? null : _markAllRead,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (_, i) => _buildItem(_items[i]),
                    ),
            ),
    );
  }
}
