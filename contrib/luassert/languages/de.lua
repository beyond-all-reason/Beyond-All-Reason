local s = require('say')

s:set_namespace('de')

s:set("assertion.same.positive", "Erwarte gleiche Objekte.\nGegeben:\n%s\nErwartet:\n%s")
s:set("assertion.same.negative", "Erwarte ungleiche Objekte.\nGegeben:\n%s\nNicht erwartet:\n%s")

s:set("assertion.equals.positive", "Erwarte dieselben Objekte.\nGegeben:\n%s\nErwartet:\n%s")
s:set("assertion.equals.negative", "Erwarte nicht dieselben Objekte.\nGegeben:\n%s\nNicht erwartet:\n%s")

s:set("assertion.near.positive", "Erwarte annähernd gleiche Werte.\nGegeben:\n%s\nErwartet:\n%s +/- %s")
s:set("assertion.near.negative", "Erwarte keine annähernd gleichen Werte.\nGegeben:\n%s\nNicht erwartet:\n%s +/- %s")

s:set("assertion.matches.positive", "Erwarte identische Zeichenketten.\nGegeben:\n%s\nErwartet:\n%s")
s:set("assertion.matches.negative", "Erwarte unterschiedliche Zeichenketten.\nGegeben:\n%s\nNicht erwartet:\n%s")

s:set("assertion.unique.positive", "Erwarte einzigartiges Objekt:\n%s")
s:set("assertion.unique.negative", "Erwarte nicht einzigartiges Objekt:\n%s")

s:set("assertion.error.positive", "Es wird ein Fehler erwartet.")
s:set("assertion.error.negative", "Es wird kein Fehler erwartet, aber folgender Fehler trat auf:\n%s")

s:set("assertion.truthy.positive", "Erwarte, dass der Wert 'wahr' (truthy) ist.\nGegeben:\n%s")
s:set("assertion.truthy.negative", "Erwarte, dass der Wert 'unwahr' ist (falsy).\nGegeben:\n%s")

s:set("assertion.falsy.positive", "Erwarte, dass der Wert 'unwahr' ist (falsy).\nGegeben:\n%s")
s:set("assertion.falsy.negative", "Erwarte, dass der Wert 'wahr' (truthy) ist.\nGegeben:\n%s")

s:set("assertion.called.positive", "Erwarte, dass die Funktion %s-mal aufgerufen wird, anstatt %s mal.")
s:set("assertion.called.negative", "Erwarte, dass die Funktion nicht genau %s-mal aufgerufen wird.")

s:set("assertion.called_at_least.positive", "Erwarte, dass die Funktion mindestens %s-mal aufgerufen wird, anstatt %s-mal")
s:set("assertion.called_at_most.positive", "Erwarte, dass die Funktion höchstens %s-mal aufgerufen wird, anstatt %s-mal")
s:set("assertion.called_more_than.positive", "Erwarte, dass die Funktion mehr als %s-mal aufgerufen wird, anstatt %s-mal")
s:set("assertion.called_less_than.positive", "Erwarte, dass die Funktion weniger als %s-mal aufgerufen wird, anstatt %s-mal")

s:set("assertion.called_with.positive", "Erwarte, dass die Funktion mit den gegebenen Parametern aufgerufen wird.")
s:set("assertion.called_with.negative", "Erwarte, dass die Funktion nicht mit den gegebenen Parametern aufgerufen wird.")

s:set("assertion.returned_with.positive", "Die Funktion wurde nicht mit den Argumenten zurückgegeben.")
s:set("assertion.returned_with.negative", "Die Funktion wurde mit den Argumenten zurückgegeben.")

s:set("assertion.returned_arguments.positive", "Erwarte den Aufruf mit %s Argument(en), aber der Aufruf erfolgte mit %s")
s:set("assertion.returned_arguments.negative", "Erwarte nicht den Aufruf mit %s Argument(en), der Aufruf erfolgte dennoch mit %s")

-- errors
s:set("assertion.internal.argtolittle", "Die Funktion '%s' erwartet mindestens %s Parameter, gegeben: %s")
s:set("assertion.internal.badargtype", "bad argument #%s: Die Funktion '%s' erwartet einen Parameter vom Typ %s, gegeben: %s")
