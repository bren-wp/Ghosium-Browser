# Ghosium Browser — brzina i potrošnja resursa

Ovaj dokument definira provjerljivu usporedbu Ghosium Browsera s drugim Windows preglednicima. Cilj nije marketinška tvrdnja bez dokaza, nego ista mjerenja na istom računalu, u istom CI runu i s evidentiranim verzijama izvršnih datoteka.

## Što mjerimo

Za svaki preglednik `scripts/benchmark-browser-comparison-windows.ps1` radi tri scenarija s potpuno novim profilom:

- 1 tab
- 5 tabova
- 10 tabova

Za svaki scenarij bilježe se:

- vrijeme do prvog upotrebljivog prozora (`firstUsableWindowMs`)
- broj procesa
- working set RAM
- private memory
- broj Windows handleova
- normalizirana CPU aktivnost nakon stabilizacije

Benchmark koristi lokalni `data:` dokument bez mrežnog sadržaja. Time se uspoređuju startup i osnovni trošak preglednika, a ne brzina interneta ili udaljenog web-poslužitelja.

## Pravila usporedbe

1. Svi dostupni preglednici moraju se mjeriti u istom GitHub Actions Windows jobu.
2. Svaki scenarij koristi svježi profil.
3. U izvještaju se čuvaju `ProductVersion` i SHA-256 svake mjerene izvršne datoteke.
4. Nedostupan preglednik mora biti označen kao `available=false`; ne smije mu se izmišljati rezultat.
5. Ghosium se ne opisuje kao "brži od" konkurenta dok exact-build JSON dokaz ne pokaže tu prednost za konkretnu metriku i scenarij.
6. Sigurnosne značajke kao sandbox, process/site isolation i validacija certifikata ne smiju se gasiti radi boljeg benchmark rezultata.

## Usporedbe

### Ghosium Browser vs Google Chrome

Uspoređuju se isti 1/5/10-tab scenariji, startup, RAM i CPU. Rezultat za 0.1.9 bit će upisan nakon završnog Windows Preview benchmarka.

**Status 0.1.9:** čeka exact-build mjerenje.

### Ghosium Browser vs Microsoft Edge

Isti kriteriji i isti Windows runner kao za Ghosium i Chrome.

**Status 0.1.9:** čeka exact-build mjerenje.

### Ghosium Browser vs Mozilla Firefox

Firefox koristi vlastiti profilni argument, ali isti lokalni testni dokument, isti broj tabova i ista Windows mjerenja procesa/RAM-a/CPU-a.

**Status 0.1.9:** čeka exact-build mjerenje.

### Ghosium Browser vs Brave

Brave se mjeri samo ako je njegova izvršna datoteka dostupna na benchmark hostu. Verzija i SHA-256 moraju biti spremljeni u evidence JSON-u.

**Status 0.1.9:** čeka exact-build mjerenje.

### Ghosium Browser vs Vivaldi

Vivaldi se mjeri istim svježim profilima i 1/5/10-tab scenarijima.

**Status 0.1.9:** čeka exact-build mjerenje.

### Ghosium Browser vs Opera

Opera se mjeri samo kada je pronađena službena instalirana izvršna datoteka na Windows benchmark hostu.

**Status 0.1.9:** čeka exact-build mjerenje.

## Ghosium 0.1.9 optimizacije koje se moraju dokazati mjerenjem

0.1.9 povezuje postojeći native performance rewrite u glavni source-transform pipeline. Distribucijski default uključuje Chromiumov održavani Memory Saver, zadržava srednju agresivnost i tab freezing te ne uvodi umjetni renderer-process cap.

New Tab dodatno ima lokalnu opciju **Reduce visual effects** koja uklanja velike blur/aurora efekte i `backdrop-filter`; korisnik može uključiti i **Compact layout**. Te opcije ciljaju manji GPU/UI trošak bez diranja sigurnosnog modela browser enginea.

## Evidence datoteke

Za izdanje koje sadrži stvarne usporedne brojke očekuju se:

- `GHOSIUM-PERFORMANCE.json` — detaljni Ghosium source/preview performance dokaz
- `GHOSIUM-BROWSER-COMPARISON.json` — ista Windows usporedba protiv dostupnih drugih preglednika

Ako te datoteke nisu nastale za exact release commit, ovaj dokument ne smije tvrditi da je Ghosium brojčano brži ili štedljiviji od određenog konkurenta.
