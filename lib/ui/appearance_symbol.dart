import 'package:flutter/material.dart';

import '../models/chat_settings.dart';
import 'emoji_symbol.dart';

/// Render legacy choices with bundled art while preserving their stored emoji IDs.
class AppearanceSymbol extends StatelessWidget {
  const AppearanceSymbol(this.symbol, {super.key, required this.size});
  final String symbol;
  final double size;
  static const labels = <String>[
    'Personne',
    'Groupe',
    'Discussion',
    'Maison',
    'Famille',
    'Cœur',
    'Favoris',
    'Études',
    'Lecture',
    'Travail',
    'Fichiers',
    'Jeux',
    'Musique',
    'Sport',
    'Monde',
    'Nature',
    'Chat',
    'Chien',
    'Projet',
    'Cadenas',
  ];
  static String? assetFor(String symbol) {
    final index = ChatSettings.icons.indexOf(symbol);
    return index < 0
        ? null
        : 'assets/symbols/${(index + 1).toString().padLeft(2, '0')}.png';
  }

  @override
  Widget build(BuildContext context) {
    final asset = assetFor(symbol);
    return asset == null
        ? EmojiSymbol(symbol, fontSize: size * .5)
        : Image.asset(
            asset,
            width: size,
            height: size,
            excludeFromSemantics: true,
            cacheWidth: 256,
            cacheHeight: 256,
          );
  }
}
