import 'package:flutter/foundation.dart';

import '../features/catalog/catalog_models.dart';

/// 单个上传文件的上限（docs/API.md §7.5）。
const maxUploadBytes = 128 * 1024 * 1024;

/// 一个账号最多的上传条目数（服务端限额，用于提示文案）。
const maxUploadsPerAccount = 50;

/// 上传时可选的许可证（与目录白名单一致，docs/API.md §7.2），按限制从少到多排。
const ugcLicenses = <String>[
  'CC0-1.0',
  'CC-BY-4.0',
  'CC-BY-3.0',
  'CC-BY-SA-4.0',
  'CC-BY-SA-3.0',
  'CC-BY-NC-4.0',
  'CC-BY-NC-3.0',
  'CC-BY-NC-SA-4.0',
  'CC-BY-NC-SA-3.0',
  'PD',
];

/// `source_declaration`：own = 自己的作品 / 录音，licensed = 按所列许可证获得授权的素材。
enum SourceDeclaration { own, licensed }

enum UploadVisibility { private, public }

/// `moderation`：active 正常，hidden = 被举报自动隐藏待审，takenDown = 运营下架。
enum UploadModeration { active, hidden, takenDown }

enum ReportReason { copyright, inappropriate, other }

/// 上传条目（docs/API.md §7.5 `UploadItem`，只有上传者本人能看到）。
@immutable
class UploadItem {
  const UploadItem({
    required this.item,
    this.credit = '',
    this.declaration = SourceDeclaration.own,
    this.visibility = UploadVisibility.private,
    this.moderation = UploadModeration.active,
    this.status = 'draft',
  });

  /// 与公开目录同形的元数据（标题、许可证、大小、校验和……）。
  final CatalogItem item;
  final String credit;
  final SourceDeclaration declaration;
  final UploadVisibility visibility;
  final UploadModeration moderation;

  /// `draft` = 还没有文件；`published` = 文件就绪。
  final String status;

  String get id => item.id;
  bool get hasFile => status == 'published' && item.size > 0;

  /// 已出现在公开目录里。
  bool get isPublic =>
      hasFile &&
      visibility == UploadVisibility.public &&
      moderation == UploadModeration.active;

  /// 运营下架：不能再公开、下载或替换文件，只能删除。
  bool get takenDown => moderation == UploadModeration.takenDown;

  factory UploadItem.fromJson(Map<String, Object?> j) => UploadItem(
    item: CatalogItem.fromJson(j),
    credit: (j['credit'] as String?) ?? (j['attribution'] as String?) ?? '',
    declaration: j['source_declaration'] == 'licensed'
        ? SourceDeclaration.licensed
        : SourceDeclaration.own,
    visibility: j['visibility'] == 'public'
        ? UploadVisibility.public
        : UploadVisibility.private,
    moderation: switch (j['moderation']) {
      'hidden' => UploadModeration.hidden,
      'taken_down' => UploadModeration.takenDown,
      _ => UploadModeration.active,
    },
    status: (j['status'] as String?) ?? 'draft',
  );
}

/// 上传表单（`POST /api/me/uploads` 的请求体）。
@immutable
class UploadDraft {
  const UploadDraft({
    required this.title,
    required this.credit,
    required this.license,
    required this.declaration,
    this.sourceUrl = '',
    this.description = '',
    this.bpm = 0,
    this.groupCount = 0,
    this.padCount = 0,
  });

  final String title;
  final String credit;
  final String license;
  final SourceDeclaration declaration;
  final String sourceUrl;
  final String description;
  final double bpm;
  final int groupCount;
  final int padCount;

  Map<String, Object?> toJson() => {
    'title': title.trim(),
    'credit': credit.trim(),
    'license': license,
    'source_declaration': declaration.name,
    if (sourceUrl.trim().isNotEmpty) 'source_url': sourceUrl.trim(),
    if (description.trim().isNotEmpty) 'description': description.trim(),
    if (bpm > 0) 'bpm': bpm.round(),
    if (groupCount > 0) 'group_count': groupCount,
    if (padCount > 0) 'pad_count': padCount,
  };
}

/// 表单校验结果：哪些字段不合格（界面据此标红 / 禁用提交）。
@immutable
class UploadFormErrors {
  const UploadFormErrors({
    this.title = false,
    this.credit = false,
    this.license = false,
    this.sourceUrl = false,
    this.confirmed = false,
  });

  final bool title;
  final bool credit;
  final bool license;
  final bool sourceUrl;
  final bool confirmed;

  bool get any => title || credit || license || sourceUrl || confirmed;
}

/// 校验：标题 ≤120、署名 ≤500 且必填、许可证在白名单内、来源链接（可空）必须是 http(s)、
/// 必须勾选“我有权分享”。
UploadFormErrors validateUpload(UploadDraft d, {required bool confirmed}) {
  final url = d.sourceUrl.trim();
  final uri = Uri.tryParse(url);
  return UploadFormErrors(
    title: d.title.trim().isEmpty || d.title.trim().length > 120,
    credit: d.credit.trim().isEmpty || d.credit.trim().length > 500,
    license: !ugcLicenses.contains(d.license),
    sourceUrl:
        url.isNotEmpty &&
        !(uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty),
    confirmed: !confirmed,
  );
}
