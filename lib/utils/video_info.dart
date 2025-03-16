

// ignore_for_file: unused_field

class VideoInfo {
  String? _title;

  String get title {
    switch (event) {
      case 1:
        return "事件1";
      case 2:
        return "事件2";
    }
    return '未知事件';
  }

  int? event;
  DateTime? time;
  String? starttime;
  int? durationSeconds;
  String? image;
  String? fileName;
  String? filePath;
  String? serveraddr;
  String? serno;

  VideoInfo({
    required this.event,
    required this.time,
    required this.starttime,
    required this.durationSeconds,
    required this.image,
    required this.fileName,
    required this.filePath,
    required this.serveraddr,
    required this.serno,
  });

  VideoInfo.fromJson(Map<String, dynamic> json) {
    json.forEach((key, value) {
      if (key == "event") {
        event = value;
      } else if (key == "starttime") {
        starttime = value;
        try {
          time = DateTime.parse(value.substring(0, 19)).toLocal();
        } catch (e) {
          time = DateTime(0, 0, 0);
        }
      } else if (key == "filetime") {
        durationSeconds = value;
      } else if (key == "snapshot") {
        image = value;
      } else if (key == "filename") {
        fileName = value;
      } else if (key == "serveraddr") {
        serveraddr = value;
      } else if (key == "serno") {
        serno = value;
      } else if (key == "filepath") {
        filePath = value;
      } else {}
    });
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['event'] = event;
    data['starttime'] = time;
    data['filetime'] = durationSeconds;
    data['snapshot'] = image;
    data['filename'] = fileName;
    return data;
  }

  Map<String, dynamic> toCouldJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['event'] = event;
    data['starttime'] = time;
    data['filetime'] = durationSeconds;
    data['snapshot'] = image;
    data['filename'] = fileName;
    data['filename'] = fileName;
    data['serveraddr'] = serveraddr;
    data['filepath'] = filePath;
    return data;
  }
}
