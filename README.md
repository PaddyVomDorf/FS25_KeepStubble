Nach der Bodenbearbeitung mit dem Flachgrubber oder der Scheibenegge bleibt ein Teil der Stoppeln sichtbar statt 
komplett entfernt zu werden. 
Drei Profile mit pro Fruchtart einstellbaren Werten (im Modordner zu finden), in den Spiel-Einstellungen auswählbar. 
Eigene Fruchtarten können dort ebenfalls ergänzt werden.

Beispiel aus der der custom1.xml
<settings name="DEIN NAME"> 
Hier könnt ihr einen eigenen Profilnamen eintragen, der so auch im Ingame-Menü angezeigt wird
NICHT die Datei an sich umbenennen! Das Profil kann sonst nicht mehr geladen werden!

<fruit name="WHEAT" densityReductionPercent="2" targetFoliageState="10"/>
- fruit name: Der Name der Frucht, so wie er z.b. in der fillTypes.xml eingetragen ist
- densityReductionPercent: Der Faktor in % um den die Stoppeln bei jeder Überfahrt reduziert werden sollen
  Bewusst niedrig (1-3) ansetzen, höhere Werte dünnen die Stoppeln sehr schnell aus
- targetFoliageState: Der Status der Frucht, welcher bei der Bearbeitung gesetzt werden soll.
  Hängt stark von der vewendeten Karte und der jeweiligen Frucht ab!
  Das "Vanilla" Profil funktioniert auf den Standard-Karten, "StubbleDestr." sollte auf Karten mit
  Stoppelzerstörung und zusätzlichen Früchten (z.B. Triticale oder Roggen) funktionieren.
  Wenn etwas nicht wie gewünscht aussieht, am besten mit den Easy Development Controls den Zustand
  zuerst auf "gesät" setzen (gesät entpricht FoliageState "1") und von dort aus mitzählen, bis ihr beim
  gewünschten Ergebnis seid und diese Zahl dann hier eintragen.
  Das könnt ihr auch ohne Neustart des Spiels testen. Einfach Werte ändern, speichern, Ingame kurz ein anderes Profil wählen,
  wieder zurück zum Wunschprofil wechseln und eure Änderungen sind aktiv!
- Neue / eigene Fruchtarten könnt ihr nach dem selben Schema einfach selbst ergänzen

_________________________________________________________________________

After tillage with a cultivator or disc harrow, some of the stubble remains visible instead of being completely removed.
Three profiles with crop-specific configurable values (found in the mod folder) can be selected in the game settings. 
Custom crops can also be added there.

Example from custom1.xml:
<settings name="YOUR NAME">
Here, you can enter your own profile name, which will also be displayed in the in-game menu.
DO NOT rename the file itself! Otherwise, the profile can no longer be loaded!

<fruit name="WHEAT" densityReductionPercent="2" targetFoliageState="10"/>
- fruit name: The name of the crop, exactly as it is listed, for example, in fillTypes.xml.
- densityReductionPercent: The percentage by which the stubble should be reduced with each pass.
  It is intentionally set low (1–3). Higher values will thin out the stubble very quickly.
- targetFoliageState: The crop state that should be set during cultivation.
  This depends heavily on the map being used and the respective crop!
  The "Vanilla" profile works on the standard maps, while "StubbleDestr." should work on maps with stubble destruction and additional crops (e.g. triticale or rye).
  If something does not look as expected, it is best to use Easy Development Controls to first set the state to "sown" (FoliageState "1").
  Then count up from there until you reach the desired result, and enter that number here.
  You can also test this without restarting the game. Simply change the values, save the file, briefly select a different profile in-game,
  then switch back to your desired profile — your changes will be active immediately!
- New/custom crops: You can easily add your own crops following the same pattern.
