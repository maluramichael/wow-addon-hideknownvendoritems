# wow-addon-hideknownvendoritems

Ein WoW-Addon, das mir beim Händler alle Gegenstände ausblendet, die mein Charakter schon kennt: Grimoires, Rezepte, Muster. Ich wollte nicht mehr jedes Mal die halbe Seite durchgehen, um die zwei neuen Bücher zu finden.

## Wie es funktioniert

Das Addon hängt sich per `hooksecurefunc` an `MerchantFrame_Update`. Für jeden Slot der aktuellen Seite lädt es den Tooltip in einen unsichtbaren Scan-Tooltip und sucht darin nach `ITEM_SPELL_KNOWN`, also der Zeile "Bereits erlernt". Passt sie, wird der Button versteckt.

Der Umweg über den Tooltip ist nötig, weil es keine API gibt, die für einen Händler-Slot direkt sagt, ob der Charakter den Gegenstand schon kennt.

## Befehle

```
/hkvi toggle        Filter an- und ausschalten
/hkvi on | off      gezielt ein- oder ausschalten
/hkvi config        Optionen öffnen
```

Für ein Makro: `/run HideKnownVendorItems:Toggle()`

## Technisches

Gebaut auf Ace3 (AceAddon, AceEvent, AceConsole, AceDB, AceConfig). Die Bibliotheken liegen nicht im Repo, sondern werden über die `externals` in der `.pkgmeta` gezogen. Die Einstellung liegt in `HideKnownVendorItemsDB` und hängt am Ace-Profil.

`## Interface: 20505` in der TOC, das Addon ist also für Burning Crusade Classic gebaut.
