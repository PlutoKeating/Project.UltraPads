import 'package:flutter/material.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';

/// 曲风键 → 图标、调色板角色、显示名（截图 4 底部曲风栏）。
@immutable
class GenreSpec {
  const GenreSpec(this.key, this.icon, this.role);
  final String key;
  final IconData icon;
  final ColorRole role;

  String label(UpL10n l10n) => switch (key) {
    'hiphop' => l10n.libraryGenreHipHop,
    'funkbr' => l10n.libraryGenreFunkBr,
    'kpop' => l10n.libraryGenreKpop,
    'rock' => l10n.libraryGenreRock,
    'disco' => l10n.libraryGenreDisco,
    'edm' => l10n.libraryGenreEdm,
    'pop' => l10n.libraryGenrePop,
    'trap' => l10n.libraryGenreTrap,
    'house' => l10n.libraryGenreHouse,
    'latin' => l10n.libraryGenreLatin,
    _ => key,
  };
}

const genreSpecs = <GenreSpec>[
  GenreSpec('hiphop', Icons.headphones_rounded, ColorRole.pink),
  GenreSpec('funkbr', Icons.flag_rounded, ColorRole.green),
  GenreSpec('kpop', Icons.favorite_rounded, ColorRole.yellow),
  GenreSpec('rock', Icons.bolt_rounded, ColorRole.blue),
  GenreSpec('disco', Icons.album_rounded, ColorRole.purple),
  GenreSpec('edm', Icons.graphic_eq_rounded, ColorRole.cyan),
  GenreSpec('pop', Icons.star_rounded, ColorRole.red),
  GenreSpec('trap', Icons.speaker_rounded, ColorRole.orange),
];

GenreSpec? genreSpec(String key) {
  for (final g in genreSpecs) {
    if (g.key == key) return g;
  }
  return null;
}
