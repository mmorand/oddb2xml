# Fragen und Antworten zu oddb2xml

####Wann werden Medikamenten-Stammdaten aktualisiert? (An welchem tag im Monat)
* Refdata ändert täglich Pharmacodes.
* SL Preise werden am Anfang des Monats publiziert, jeweils immer am 1. Ganz selten auch am 15.
* Fachinfos werden täglich publiziert.
* Swissmedic-Codes erscheinen einmal pro Monat, normalerweise in der ersten Woche.

Wer will kann oddb2xml einmal pro Tag laufen lassen für die neusten Pharmacodes.

Wir haben einen ganz grossen Vorteil: Bei uns erscheint [QAP?] nicht
in den Daten weil wir Refdata als Quelle verwenden. ;)

####Haben Sie eine Spezifikation der XML Files? Was steht wo drin? Wenn ich ein XSD selbst generiere, stehen dort ja nicht mehr Informationen als jetzt schon. Ich muss aber wissen in welchem Attribut welcher Wert steht, wie der MwSt Code genau aussieht usw.

Nein, das gibt es zur Zeit nicht (kommt ev. noch), die Felder sind
aber grundsätzlich selbsterklärend.

* im article.xml verwenden wird die Bezeichnungen von Refdata.ch
* im product.xml verwenden wir die Bezeichnungen vom BAG-XML. Produkte die nicht in der SL sind haben dann im product.xml auch keine Bezeichnung.

Der Mwst.-Code ist bei allen Produkten bei denen der GTIN mit 7680 (Medi in der SL) beginnt bei 8%.
