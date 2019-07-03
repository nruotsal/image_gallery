import 'dart:async';

import 'package:flutter/services.dart';

class Metadata {
  final double latitude;
  final double longitude;
  final String dateTime;

  const Metadata({
    this.latitude,
    this.longitude,
    this.dateTime,
  });
}

class GalleryImage {
  final String path;
  final Metadata metadata;

  const GalleryImage({
    this.path,
    this.metadata,
  });
}

class FlutterGalleryPlugin {
  static const PATHS_CHANNEL = 'flutter_gallery_plugin/paths';
  static const ARGUMENT_PERIOD_START = 'startPeriod';
  static const ARGUMENT_PERIOD_END = 'endPeriod';

  static const _eventChannel = const EventChannel(PATHS_CHANNEL);

  static Stream<GalleryImage> getPhotoPathsForPeriod(
    DateTime startPeriod,
    DateTime endPeriod,
  ) {
    Map<String, int> arguments = <String, int>{
      ARGUMENT_PERIOD_START: startPeriod.millisecondsSinceEpoch,
      ARGUMENT_PERIOD_END: endPeriod.millisecondsSinceEpoch,
    };

    return _eventChannel
        .receiveBroadcastStream(arguments)
        .cast<Map<dynamic, dynamic>>()
        .map(_parseJsonResponse)
        .cast<GalleryImage>();
  }

  static GalleryImage _parseJsonResponse(json) {
    if (json == null) return null;

    final data = Map<String, dynamic>.from(json);
    return GalleryImage(
      path: data['path'] == null ? null : data['path'] as String,
      metadata:
          data['metadata'] == null ? null : _parseMetadata(data['metadata']),
    );
  }

  static Metadata _parseMetadata(json) {
    if (json == null) return null;

    final metadata = Map<String, dynamic>.from(json);
    final gps = Map<String, dynamic>.from(
      metadata['{GPS}'] as Map<dynamic, dynamic>,
    );
    final exif = Map<String, dynamic>.from(
      metadata['{Exif}'] as Map<dynamic, dynamic>,
    );

    return Metadata(
      latitude: gps['Latitude'] as double,
      longitude: gps['Longitude'] as double,
      dateTime: exif['DateTimeOriginal'] as String,
    );
  }
}
