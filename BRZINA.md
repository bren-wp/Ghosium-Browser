# Ghosium Browser 0.0.3 — brzina i potrošnja resursa

Ovaj dokument definira provjerljivu Windows usporedbu Ghosium Browsera s drugim preglednicima. Cilj nije marketinška tvrdnja bez dokaza, nego ista mjerenja na istom računalu, u istom kontroliranom runu i s evidentiranim verzijama izvršnih datoteka.

## Što mjerimo

Kontrolirani Windows benchmark koristi svježe profile i 1, 5 i 10 tabova. Bilježe se vrijeme do prvog upotrebljivog prozora, broj procesa, working-set RAM, private memory, Windows handleovi i normalizirana CPU aktivnost nakon stabilizacije.

## Pravila

1. Rezultat vrijedi samo za exact-build SHA naveden u evidence datoteci.
2. Nedostupan konkurentski preglednik označava se kao nedostupan; rezultat se ne procjenjuje niti izmišlja.
3. Ghosium se ne opisuje kao brojčano brži/štedljiviji dok exact-build dokaz to ne pokaže za konkretnu metriku.
4. Sandbox, process/site isolation, Safe Browsing i TLS/certificate validation ne smiju se gasiti radi rezultata.
5. Benchmark ne smije zatvarati pre-existing korisničke browser sesije; cleanup je ograničen na procese koje je benchmark sam pokrenuo.

## 0.0.3 optimizacije koje se provjeravaju

- Chromiumov održavani Memory Saver ostaje nativni mehanizam za upravljanje memorijom.
- Legacy background-app keep-alive ostaje isključen.
- New Tab izbjegava nepotrebne remote promo/Doodle/prefetch putanje obuhvaćene Ghosium source contractom.
- Windows Portable 0.0.3 koristi verzionirani runtime cache i ne raspakirava cijeli runtime pri svakom pokretanju.
- Portable cache ima staging + ready-marker zaštitu od nepotpune pripreme.

Android 0.0.3 ne koristi ovaj Windows usporedni benchmark. Android stabilnost/performance se štiti lifecycle/state restore i renderer-recovery logikom; za Android se u ovom izdanju ne objavljuju neprovjerene usporedne brojke.

## Evidence

Canonical Windows release generira `GHOSIUM-PERFORMANCE.json`. Usporedne tvrdnje protiv drugih preglednika zahtijevaju odgovarajući exact-build comparison evidence. Ako dokaz ne postoji za release commit, ovaj dokument ne daje brojčanu tvrdnju o prednosti nad Chromeom, Edgeom, Firefoxom, Braveom, Vivaldijem ili Operom.
