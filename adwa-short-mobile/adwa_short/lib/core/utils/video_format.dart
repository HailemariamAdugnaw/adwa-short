class AdwaVideoFormat {
  AdwaVideoFormat._();

  static String detect(String url) {
    final lower = url.toLowerCase().split('?').first.split('#').first;
    if (lower.endsWith('.mp4') || lower.endsWith('.m4v')) return 'mp4';
    if (lower.endsWith('.mov')) return 'mov';
    if (lower.endsWith('.webm')) return 'webm';
    if (lower.endsWith('.mkv')) return 'mkv';
    if (lower.endsWith('.avi')) return 'avi';
    if (lower.endsWith('.flv')) return 'flv';
    if (lower.endsWith('.wmv')) return 'wmv';
    if (lower.endsWith('.3gp')) return '3gp';
    if (lower.endsWith('.ts')) return 'ts';
    if (lower.endsWith('.m3u8')) return 'hls';
    if (lower.contains('.m3u8')) return 'hls';
    if (lower.endsWith('.mpd')) return 'dash';
    if (lower.endsWith('.ogv') || lower.endsWith('.ogg')) return 'ogv';
    return 'unknown';
  }

  static bool isNativelySupported(String format) {
    switch (format) {
      case 'mp4':
      case 'mov':
      case 'm4v':
      case 'webm':
      case 'hls':
      case 'ts':
        return true;
      case 'mkv':
      case 'avi':
      case 'flv':
      case 'wmv':
      case '3gp':
      case 'dash':
      case 'ogv':
      case 'unknown':
        return false;
      default:
        return false;
    }
  }

  static String label(String format) {
    switch (format) {
      case 'mp4':
        return 'MP4';
      case 'mov':
        return 'MOV';
      case 'm4v':
        return 'M4V';
      case 'webm':
        return 'WebM';
      case 'mkv':
        return 'MKV';
      case 'avi':
        return 'AVI';
      case 'flv':
        return 'FLV';
      case 'wmv':
        return 'WMV';
      case '3gp':
        return '3GP';
      case 'ts':
        return 'TS';
      case 'hls':
        return 'HLS';
      case 'dash':
        return 'DASH';
      case 'ogv':
        return 'OGV';
      default:
        return 'UNKNOWN';
    }
  }

  static String supportHint(String format) {
    if (format == 'unknown') {
      return 'The video format could not be identified. '
          'It may not play on this device.';
    }
    if (isNativelySupported(format)) {
      return 'Format: ${label(format)}. If this still fails, '
          'the file may be missing or corrupted.';
    }
    return 'Format: ${label(format)}. This format may not be supported '
        'on this device. Try Retry — some devices have the codec. '
        'Otherwise, copy the URL below to open in another app.';
  }
}
