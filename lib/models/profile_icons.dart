/// Stable, local icon IDs shared by every platform; never renumber existing avatars.
class ProfileIcon {
  const ProfileIcon(this.id, this.label, this.category);
  final String id, label, category;
  String get symbol => 'icon:$id';
  String get asset => 'assets/profile_icons/$id.png';
}

class ProfileIcons {
  static const categories = [
    'Appareils et lieux',
    'Systèmes',
    'Fabricants',
    'Distributions Linux',
  ];
  static const all = <ProfileIcon>[
    ProfileIcon('smartphone', 'Smartphone', 'Appareils et lieux'),
    ProfileIcon('mini-pc', 'Mini PC', 'Appareils et lieux'),
    ProfileIcon('tablet', 'Tablette', 'Appareils et lieux'),
    ProfileIcon('laptop', 'Portable', 'Appareils et lieux'),
    ProfileIcon('home', 'Maison', 'Appareils et lieux'),
    ProfileIcon('work', 'Travail', 'Appareils et lieux'),
    ProfileIcon('linux', 'Linux', 'Systèmes'),
    ProfileIcon('windows', 'Windows', 'Systèmes'),
    ProfileIcon('macos', 'macOS', 'Systèmes'),
    ProfileIcon('ios', 'iOS', 'Systèmes'),
    ProfileIcon('dell', 'Dell', 'Fabricants'),
    ProfileIcon('hp', 'HP', 'Fabricants'),
    ProfileIcon('lenovo', 'Lenovo', 'Fabricants'),
    ProfileIcon('asus', 'Asus', 'Fabricants'),
    ProfileIcon('acer', 'Acer', 'Fabricants'),
    ProfileIcon('ubuntu', 'Ubuntu', 'Distributions Linux'),
    ProfileIcon('fedora', 'Fedora', 'Distributions Linux'),
    ProfileIcon('zorin', 'Zorin', 'Distributions Linux'),
    ProfileIcon('debian', 'Debian', 'Distributions Linux'),
    ProfileIcon('linuxmint', 'Mint', 'Distributions Linux'),
    ProfileIcon('nixos', 'NixOS', 'Distributions Linux'),
    ProfileIcon('cachyos', 'CachyOS', 'Distributions Linux'),
    ProfileIcon('elementary', 'elementary', 'Distributions Linux'),
    ProfileIcon('opensuse', 'openSUSE', 'Distributions Linux'),
  ];
  static ProfileIcon? find(String? symbol) {
    for (final icon in all) {
      if (icon.symbol == symbol) return icon;
    }
    return null;
  }
}
