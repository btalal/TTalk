import 'package:flutter/material.dart';

/// Approved bundled artwork. Existing `avatar:0..19` IDs stay unchanged.
class AvatarArt extends StatelessWidget {
  const AvatarArt({
    super.key,
    required this.index,
    this.group = false,
    this.size = 40,
  });
  final int index;
  final bool group;
  final double size;
  static const count = 20;
  static const groupLabels = <String>[
    'Amis',
    'Famille',
    'Travail',
    'Études',
    'Loisirs',
    'Voyages',
    'Sport',
    'Musique',
    'Jeux',
    'Lecture',
    'Voisins',
    'Nature',
    'Photo',
    'Création',
    'Entraide',
    'Communauté',
    'Fêtes',
    'Café',
    'Projets',
    'Équipe',
  ];
  static String assetFor(int index, {bool group = false}) =>
      'assets/avatars/${group ? 'group' : 'profile'}-${(index % count + 1).toString().padLeft(2, '0')}.png';
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ClipOval(
      child: Image.asset(
        assetFor(index, group: group),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: 256,
        cacheHeight: 256,
        excludeFromSemantics: true,
      ),
    ),
  );
}
