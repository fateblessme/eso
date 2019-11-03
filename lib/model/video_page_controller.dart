import 'package:chewie/chewie.dart';
import 'package:eso/api/api_manager.dart';
import 'package:eso/database/search_item_manager.dart';
import 'package:eso/page/video_page.dart';

import '../database/search_item.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class VideoPageController with ChangeNotifier {
  // const
  final SearchItem searchItem;
  // private
  bool _isLoading;
  VideoPlayerController _videoController;
  VideoPlayerController _audioController;
  // public get
  List<String> _content;
  List<String> get content => _content;

  ChewieController _controller;
  ChewieController get controller => _controller;

  bool _showChapter;
  bool get showChapter => _showChapter;
  set showChapter(bool value) {
    if (_showChapter != value) {
      _showChapter = value;
      notifyListeners();
    }
  }

  VideoPageController({this.searchItem}) {
    _isLoading = false;
    _showChapter = false;
    if (searchItem.chapters?.length == 0 &&
        SearchItemManager.isFavorite(searchItem.url)) {
      searchItem.chapters = SearchItemManager.getChapter(searchItem.id);
    }
    _initContent();
  }

  void _initContent() async {
    _content = await APIManager.getContent(searchItem.originTag,
        searchItem.chapters[searchItem.durChapterIndex].url);
    await _setControl();
  }

  Future<void> _setControl() async {
    if (_content == null || _content.length == 0) return;
    final cacheVideoController = _videoController;
    _videoController = VideoPlayerController.network(_content[0]);
    await _videoController.initialize();
    _audioController?.dispose();
    if (_content.length == 2 && _content[1].substring(0, 5) == 'audio') {
      _audioController =
          VideoPlayerController.network(_content[1].substring(5));
      await _audioController.initialize();
    }
    _controller?.dispose();
    _controller = ChewieController(
      autoPlay: true,
      startAt: Duration(milliseconds: searchItem.durContentIndex),
      videoPlayerController: _videoController,
      aspectRatio: _videoController.value.aspectRatio,
      allowedScreenSleep: false,
      customControls: CustomChewieController(
        controller: _videoController,
        audioController: _audioController,
        searchItem: searchItem,
        loadChapter: loadChapter,
      ),
    );
    notifyListeners();
    await Future.delayed(Duration(milliseconds: 100));
    cacheVideoController?.dispose();
  }

  Future<void> loadChapter(int chapterIndex) async {
    _showChapter = false;
    if (_isLoading ||
        chapterIndex == searchItem.durChapterIndex ||
        chapterIndex < 0 ||
        chapterIndex >= searchItem.chapters.length) return;
    _isLoading = true;
    notifyListeners();
    _content = await APIManager.getContent(
        searchItem.originTag, searchItem.chapters[chapterIndex].url);
    searchItem.durChapterIndex = chapterIndex;
    searchItem.durChapter = searchItem.chapters[chapterIndex].name;
    searchItem.durContentIndex = 1;
    await SearchItemManager.saveSearchItem();
    _isLoading = false;
    await _setControl();
  }

  @override
  void dispose() async {
    searchItem.durContentIndex = _videoController.value.position.inMilliseconds;
    SearchItemManager.saveSearchItem();
    content.clear();
    _controller?.dispose();
    await _audioController?.dispose();
    await _videoController?.dispose();
    super.dispose();
  }

  void openWith() {
    launch(_content[0]);
  }
}
