import 'package:up_i18n/up_i18n.dart';

import '../../ugc/ugc_models.dart';
import '../catalog/catalog_models.dart';

/// 上传 / 管理 / 举报失败时给用户看的话（按 docs/API.md §7.5 的状态码映射）。
String ugcErrorMessage(UpL10n l10n, Object error) {
  if (error is! CatalogException) return l10n.libraryUgcErrGeneric;
  if (error.isNetwork) return l10n.libraryCatalogLoadFailedOffline;
  if (error.code == 'too_large') return l10n.libraryUgcErrTooLarge;
  if (error.code == 'taken_down' || error.code == 'gone') {
    return l10n.libraryUgcErrTakenDown;
  }
  return switch (error.status) {
    401 => l10n.libraryUgcErrSignIn,
    403 => l10n.libraryUgcErrTakenDown,
    410 => l10n.libraryUgcErrTakenDown,
    400 => l10n.libraryUgcErrBadForm,
    411 || 413 => l10n.libraryUgcErrTooLarge,
    409 => l10n.libraryUgcErrNoFile,
    422 => l10n.libraryUgcErrInvalidKit,
    429 => l10n.libraryUgcErrQuota,
    _ => l10n.libraryUgcErrGeneric,
  };
}

/// 条目当前对上传者显示的状态。
String uploadStatusLabel(UpL10n l10n, UploadItem u) {
  if (u.takenDown) return l10n.libraryUgcVisibilityTakenDown;
  if (u.moderation == UploadModeration.hidden) {
    return l10n.libraryUgcVisibilityHidden;
  }
  if (!u.hasFile) return l10n.libraryUgcNoFile;
  return u.visibility == UploadVisibility.public
      ? l10n.libraryUgcVisibilityPublic
      : l10n.libraryUgcVisibilityPrivate;
}

String reportReasonLabel(UpL10n l10n, ReportReason r) => switch (r) {
  ReportReason.copyright => l10n.libraryUgcReportReasonCopyright,
  ReportReason.inappropriate => l10n.libraryUgcReportReasonInappropriate,
  ReportReason.other => l10n.libraryUgcReportReasonOther,
};
