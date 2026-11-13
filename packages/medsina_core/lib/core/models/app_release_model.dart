class AppReleaseModel {
  final String id;
  final String platform; // 'android', 'windows', 'web', 'all'
  final String versionName; // e.g. '1.0.1'
  final int buildNumber; // e.g. 2
  final String releaseNotes;
  final String downloadUrl;
  final bool isMandatory;
  final int minSupportedBuild;
  final String? sha256Hash;
  final bool isActive;
  final DateTime publishedAt;

  const AppReleaseModel({
    required this.id,
    required this.platform,
    required this.versionName,
    required this.buildNumber,
    required this.releaseNotes,
    required this.downloadUrl,
    this.isMandatory = false,
    this.minSupportedBuild = 1,
    this.sha256Hash,
    this.isActive = true,
    required this.publishedAt,
  });

  factory AppReleaseModel.fromJson(Map<String, dynamic> json) {
    return AppReleaseModel(
      id: json['id']?.toString() ?? '',
      platform: json['platform']?.toString() ?? 'all',
      versionName: json['version_name']?.toString() ?? '1.0.0',
      buildNumber: json['build_number'] is int
          ? json['build_number'] as int
          : int.tryParse(json['build_number']?.toString() ?? '1') ?? 1,
      releaseNotes: json['release_notes']?.toString() ?? '',
      downloadUrl: json['download_url']?.toString() ?? '',
      isMandatory: json['is_mandatory'] == true,
      minSupportedBuild: json['min_supported_build'] is int
          ? json['min_supported_build'] as int
          : int.tryParse(json['min_supported_build']?.toString() ?? '1') ?? 1,
      sha256Hash: json['sha256_hash']?.toString(),
      isActive: json['is_active'] != false,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'platform': platform,
      'version_name': versionName,
      'build_number': buildNumber,
      'release_notes': releaseNotes,
      'download_url': downloadUrl,
      'is_mandatory': isMandatory,
      'min_supported_build': minSupportedBuild,
      'sha256_hash': sha256Hash,
      'is_active': isActive,
      'published_at': publishedAt.toIso8601String(),
    };
  }
}
