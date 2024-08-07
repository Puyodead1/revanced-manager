import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:injectable/injectable.dart';
import 'package:revanced_manager/app/app.locator.dart';
import 'package:revanced_manager/services/download_manager.dart';
import 'package:revanced_manager/services/manager_api.dart';
import 'package:synchronized/synchronized.dart';
import 'package:timeago/timeago.dart';

@lazySingleton
class RevancedAPI {
  late final Dio _dio;
  late final DownloadManager _downloadManager = locator<DownloadManager>();

  final Lock getToolsLock = Lock();
  final Lock getLatestReleasesLock = Lock();

  Future<void> initialize(String repoUrl) async {
    _dio = _downloadManager.initDio(repoUrl);
  }

  Future<void> clearAllCache() async {
    await _downloadManager.clearAllCache();
  }

  Future<Map<String, List<dynamic>>> getContributors() async {
    final Map<String, List<dynamic>> contributors = {};
    try {
      final response = await _dio.get('/contributors');
      final List<dynamic> repositories = response.data['repositories'];
      for (final Map<String, dynamic> repo in repositories) {
        final String name = repo['name'];
        contributors[name] = repo['contributors'];
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return {};
    }
    return contributors;
  }

  Future<Map<String, dynamic>?> _getLatestRelease(
      String extension,
      String repoName,
    ) {
      if (!locator<ManagerAPI>().getDownloadConsent()) {
        return Future(() => null);
      }
      return getToolsLock.synchronized(() async {
        try {
          final response = await _dio.get('/tools');
          final List<dynamic> tools = response.data['tools'];
          return tools.firstWhereOrNull(
            (t) =>
                (t['repository'] as String) == repoName &&
                (t['name'] as String).endsWith(extension),
          );
        } on Exception catch (e) {
          if (kDebugMode) {
            print(e);
          }
          return null;
        }
      });
    }

  Future<String?> getLatestReleaseVersion(
    String extension,
    String repoName,
  ) async {
    try {
      final Map<String, dynamic>? release = await _getLatestRelease(
        extension,
        repoName,
      );
      if (release != null) {
        return release['version'];
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
    return null;
  }

  Future<File?> getLatestReleaseFile(
      String extension,
      String repoName,
    ) async {
      try {
        final Map<String, dynamic>? release = await _getLatestRelease(
          extension,
          repoName,
        );
        if (release != null) {
          final String url = release['browser_download_url'];
          return await _downloadManager.getSingleFile(url);
        }
      } on Exception catch (e) {
        if (kDebugMode) {
          print(e);
        }
        return null;
      }
      return null;
    }

  Future<Map<String, dynamic>?> _getLatestDevRelease(
      String extension,
      String repoName,
    ) {
      if (!locator<ManagerAPI>().getDownloadConsent()) {
        return Future(() => null);
      }
      return getLatestReleasesLock.synchronized(() async {
        try {
          final response = await _dio.get('/v2/' + repoName.split('/')[1] + '/releases');
          final Map<String, dynamic>? responseData = response.data;
          if (responseData != null && responseData.containsKey('releases')) {
            final List<dynamic> releases = responseData['releases'];
            if (releases.isNotEmpty) {
              // Cast the first release to Map<String, dynamic>
              final Map<String, dynamic> firstRelease = releases[0];
              return firstRelease;
            }
          }
          return null;
        } on Exception catch (e) {
          if (kDebugMode) {
            print(e);
          }
          return null;
        }
      });
    }

  Future<String?> getLatestDevReleaseVersion(
      String extension,
      String repoName,
      ) async {
    try {
      final Map<String, dynamic>? release = await _getLatestDevRelease(
        extension,
        repoName,
      );
      if (release != null) {
        return release['metadata']['name'];
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
    return null;
  }

  Future<File?> getLatestDevReleaseFile(
      String extension,
      String repoName,
    ) async {
      try {
        final Map<String, dynamic>? release = await _getLatestDevRelease(
          extension,
          repoName,
        );
        if (release != null) {
          final dynamic asset = release['assets']
          .firstWhereOrNull(
              (a) =>
                  (a['name'] as String).endsWith(extension),
            );
          if(asset != null) {
            final String url = asset['browser_download_url'];
            return await _downloadManager.getSingleFile(url);
          }
        }
      } on Exception catch (e) {
        if (kDebugMode) {
          print(e);
        }
        return null;
      }
      return null;
    }

  StreamController<double> managerUpdateProgress =
      StreamController<double>.broadcast();

  void updateManagerDownloadProgress(int progress) {
    managerUpdateProgress.add(progress.toDouble());
  }

  Stream<double> getManagerUpdateProgress() {
    return managerUpdateProgress.stream;
  }

  void disposeManagerUpdateProgress() {
    managerUpdateProgress.close();
  }

  Future<File?> downloadManager() async {
    final Map<String, dynamic>? release = await _getLatestRelease(
      '.apk',
      'revanced/revanced-manager',
    );
    File? outputFile;
    await for (final result in _downloadManager.getFileStream(
      release!['browser_download_url'] as String,
    )) {
      if (result is DownloadProgress) {
        final totalSize = result.totalSize ?? 10000000;
        final progress = (result.downloaded / totalSize * 100).round();

        updateManagerDownloadProgress(progress);
      } else if (result is FileInfo) {
        disposeManagerUpdateProgress();
        // The download is complete; convert the FileInfo object to a File object
        outputFile = File(result.file.path);
      }
    }
    return outputFile;
  }

  Future<String?> getLatestReleaseTime(
    String extension,
    String repoName,
  ) async {
    try {
      final Map<String, dynamic>? release = await _getLatestRelease(
        extension,
        repoName,
      );
      if (release != null) {
        final DateTime timestamp =
            DateTime.parse(release['timestamp'] as String);
        return format(timestamp, locale: 'en_short');
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
    return null;
  }

  Future<String?> getLatestDevReleaseTime(
      String extension,
      String repoName,
      ) async {
      final Map<String, dynamic>? release = await _getLatestDevRelease(
        extension,
        repoName,
      );
      if (release != null) {
        final DateTime timestamp =
            DateTime.parse(release['metadata']['published_at'] as String);
        print(timestamp);
        return format(timestamp, locale: 'en_short');
      }
    return null;
  }
}
