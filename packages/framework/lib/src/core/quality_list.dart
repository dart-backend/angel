final RegExp _qZero = RegExp(r'^q=0(\.0*)?$');

/// Splits an `Accept`-style header (comma-separated items with `;`
/// parameters, such as `Accept` or `Accept-Encoding`) into the items it
/// accepts and those it rejects with `q=0`, lowercased and without
/// parameters. Not exported from the package.
///
/// Parameter names are case-insensitive, so `Q=0` rejects too. An item with
/// other parameters (`text/html;level=1;q=0`) rejects only that variant, which
/// cannot be told apart once parameters are dropped, so it rejects nothing.
({List<String> accepted, Set<String> rejected}) parseQualityList(
  String header,
) {
  var accepted = <String>[], rejected = <String>{};
  for (var item in header.split(',')) {
    var parts = item.split(';');
    var name = parts.first.trim().toLowerCase();
    if (name.isEmpty) continue;
    var params = parts
        .skip(1)
        .map((p) => p.replaceAll(' ', '').toLowerCase())
        .where((p) => p.isNotEmpty)
        .toList();
    if (!params.any(_qZero.hasMatch)) {
      accepted.add(name);
    } else if (params.every((p) => p.startsWith('q='))) {
      rejected.add(name);
    }
  }
  return (accepted: accepted, rejected: rejected);
}
