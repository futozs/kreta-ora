# Kréta Óra

Órarend-alkalmazás a KRÉTA e-naplóhoz, ami egyetlen dologra koncentrál: **mindig lásd, mi a következő órád, és azonnal tudd meg, ha változik.**

- widget a kezdőképernyőn és a zárolási képernyőn (iOS, Android)
- Apple Watch app és számlapkomplikációk
- értesítés, ha egy óra elmarad, helyettesítés van, termet vagy időpontot cserél
- a jelszavadat csak a KRÉTA saját oldalán adod meg, az adataid a telefonodon maradnak

> Nem hivatalos alkalmazás, nem áll kapcsolatban a KRÉTA üzemeltetőjével. Korai állapotú projekt, lásd az [Állapot](#állapot) részt.

## Állapot

| Rész | Hol | Állapot |
| --- | --- | --- |
| Közös Swift mag (`KretaKit`) | `apple/KretaKit` | Kész, 102 teszt, kb. 90% sorlefedettség |
| iOS app, widgetek, Watch app, komplikációk | `apple/` | Megírva; a kód nagy része típusellenőrizve, de **eszközön még nem futott** |
| Közös Kotlin mag | `android/core` | Kész, 152 teszt |
| Android app és widgetek | `android/app` | Lefordul, debug APK készül belőle; valódi fiókkal még nincs végigpróbálva |

Az iOS és az Android app még nem lett valódi KRÉTA fiókkal kipróbálva. Az első futtatásnál számíts apróbb javítanivalókra.

## Miért natív, és miért nem Flutter

A projekt lényege a widget, a számlap és a háttérben futó figyelés. Ezeket Flutterrel is csak natívan lehet megírni (WidgetKit Swiftben, Glance Kotlinban, watchOS app Swiftben), a Flutter csak a telefonos főképernyőt adná, cserébe hidakat kellene építeni az app és a widgetek közé. Ezért:

- **Apple:** SwiftUI, WidgetKit, WatchConnectivity, BackgroundTasks. Az iOS app, a widgetek, a Watch app és a komplikációk ugyanazt a `KretaKit` Swift csomagot használják.
- **Android:** Kotlin, Jetpack Compose, Glance widgetek, WorkManager. A logika a `core` modulban van, ami a Swift mag tükörképe.

A két mag szándékosan ugyanazt csinálja, ugyanazokkal a tesztesetekkel és ugyanazokkal a magyar szövegekkel.

## Hogyan működik

```
            KRÉTA (idp.e-kreta.hu, {intézmény}.e-kreta.hu)
                              ▲
                              │ OAuth + órarend lekérés
                     ┌────────┴────────┐
                     │   SyncEngine    │  token frissítés, lekérés, összevetés
                     └────────┬────────┘
              pillanatkép     │      változások
        ┌──────────────┬──────┴───────┬──────────────────┐
        ▼              ▼              ▼                  ▼
   app képernyő     widgetek     Apple Watch        értesítések
                 (megosztott     (a telefon
                  tárolóból)      küldi át)
```

### Bejelentkezés

A KRÉTA hivatalos mobilos OAuth folyamatát használja (authorization code + PKCE):

1. Az app megnyitja a KRÉTA saját bejelentkező oldalát egy beágyazott webnézetben. A jelszót az app nem látja.
2. Sikeres belépés után a KRÉTA a `https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect` címre irányít. Ez KRÉTA-s `https` cím, nem saját URL-séma, ezért az app a webnézetben **elkapja és megszakítja** ezt a navigációt, és kiolvassa belőle a kódot.
3. A kódot a PKCE ellenőrzővel együtt beváltja a `connect/token` végponton hozzáférési és frissítő tokenre.
4. A visszairányítást szigorúan ellenőrzi (pontos gazdagép és útvonal, egyező `state`, egyetlen `code`, 15 perces érvényesség), az azonosító tokenben pedig a `nonce` és a kliens egyezését.

A tokenek iOS-en a Kulcskarikában, Androidon az Android Keystore-ral titkosítva tárolódnak. Az Apple Watch nem kap tokent, csak a kész órarendet.

### Változásfigyelés

Minden szinkron a múlt héttől a következő két hét végéig kéri le az órarendet, és összeveti az előzővel:

- az első letöltés csendes kiindulópont, nem küld értesítést
- csak a még be nem fejeződött órák számítanak
- egy új hét „begördülése" nem számít új órának
- ha a KRÉTA új azonosítót ad egy órának, de ugyanabban az idősávban ugyanaz a tárgy van, azt egy óraként hasonlítja össze

Felismert változások: elmarad, mégis megtartják, helyettesítés vagy tanárváltozás, időpontváltozás, teremcsere, új óra, törölt óra. Háromnál több változás egy összefoglaló értesítésben érkezik.

### Mennyire „azonnali" az értesítés

Őszintén: ez a platformon múlik.

- **Android:** a háttérmunka kb. 15 percenként fut. Valódi telefonon kipróbálva: a háttérszinkron az app megnyitása nélkül észlelte az elmaradó órát és a teremcserét, és kiküldte az értesítést.
- **iOS:** a háttérfrissítés időzítését a rendszer dönti el a telefonhasználat alapján. Ez jellemzően napi több alkalom, de nem fix időköz, és késhet. Az app megnyitásakor mindig azonnal frissít.

A gyorsabb iOS-es értesítéshez egy kis „ébresztő" szerver kell, ami néma push üzenettel indítja el ugyanezt a szinkront a telefonon, úgy, hogy a KRÉTA belépés továbbra is csak a telefonon marad. Ehhez fizetős Apple Developer fiók szükséges, ezért ez még nincs benne; a kód úgy épül fel, hogy a push ugyanazt az egy belépési pontot hívja majd.

### Élő óra (Android)

Bekapcsolható értesítés, ami tanítási időben a futó órát és a hátralévő időt mutatja, szünetben a következő órát és a kezdésig hátralévő időt. A sávjában a nap órái a tantárgyak színeiben látszanak, és kitöltődik, ahogy halad a nap. Android 16-on élő értesítésként (Live Update) a zárolási képernyőn és az állapotsorban is látszik. Az első óra előtt egy órával jelenik meg, az utolsó után eltűnik; elhúzva vagy az „Elrejtés mára” gombbal aznapra eltűnik.

### Widgetek

| Widget | iOS | Apple Watch | Android |
| --- | --- | --- | --- |
| Következő óra | kis, közepes, zárolási képernyő | számlap, Smart Stack | kis, széles |
| Holnapi kezdés („Mikor kezdünk?") | kis, zárolási képernyő | számlap, Smart Stack | kis, széles |
| Napi órarend | közepes, nagy | – | – |

A widgetek nem használnak hálózatot: a legutóbb letöltött órarendből rajzolnak. A futó óra visszaszámlálását maga a rendszer ketyegteti másodpercenként, az appnak ehhez nem kell futnia.

Androidon a „Következő óra” widget a méretéhez igazodik: 4×2-n a futó óra mellett jobbra a következő három óra áll, magasabb méretben alatta, kis színes blokkokban. Hogy a számláló pontosan csengetéskor váltson, az app egyszer engedélyt kér a pontos időzítéshez; enélkül a váltás néhány percet késhet. Az Android-widgetek nem tudják betölteni az app saját betűtípusát, ezért ott a telefon betűje látszik, vastagítva.

## Fejlesztés

### Apple

Kell hozzá Xcode 16 vagy újabb.

```bash
open apple/KretaOra.xcodeproj
```

Első indítás előtt:

1. A `apple/project.yml` fájlban írd át a `KRETA_BUNDLE_PREFIX` értékét valami sajátra (például `hu.sajatnev.kretaora`), mert a csomagazonosítónak Apple-fiókonként egyedinek kell lennie. Ebből az egy értékből származik az összes target azonosítója, az App Group és a háttérfeladat neve.
2. Generáld újra a projektet: `brew install xcodegen && cd apple && xcodegen`
3. Xcode-ban mind a négy targetnél állítsd be a saját csapatodat (Signing & Capabilities).

Ingyenes Apple-fiókkal is fut saját eszközön, de 7 naponta újra kell telepíteni, és push értesítés nem érhető el.

A mag tesztjei Xcode nélkül is futnak:

```bash
apple/KretaKit/test.sh
```

### Android

Android Studio nem kell hozzá, elég a parancssori Android SDK és egy JDK 17.

```bash
brew install --cask android-commandlinetools android-platform-tools
```

A parancsokat az `android` mappából futtasd, beállított `ANDROID_HOME` és `JAVA_HOME` mellett. A mag tesztjei (ehhez SDK sem kell):

```bash
./gradlew -p core test
```

Debug APK fordítása:

```bash
./gradlew :app:assembleDebug
```

Telepítés USB-n csatlakoztatott telefonra (bekapcsolt USB-hibakereséssel):

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Az app `minSdk` 26 (Android 8.0). Csak az internet- és az értesítési engedélyt kéri; nincs benne Firebase vagy bármilyen külső szolgáltatás.

## Mappák

```
apple/
  KretaKit/            közös Swift mag: OAuth, API, órarend, változásfigyelés, tesztek
  Shared/              minden Apple target közös kódja (téma, tábla-nézetek)
  SharedWidgets/       a widgetek és komplikációk közös kódja
  KretaOra/            iOS app
  KretaOraWidgets/     iOS widget kiegészítő
  KretaOraWatch/       watchOS app
  KretaOraWatchWidgets/ watchOS komplikációk
  project.yml          XcodeGen projektleíró
android/
  core/                közös Kotlin mag és tesztek
  app/                 Android app, Glance widgetek, háttérmunka
```

## Adatvédelem

- Az app kizárólag a KRÉTA hivatalos szervereivel kommunikál. Nincs saját szerver, analitika vagy hirdetés.
- A jelszó csak a KRÉTA oldalán kerül megadásra. A bejelentkező webnézet nem őriz meg sütiket.
- A letöltött órarend és a tokenek a készüléken maradnak, kijelentkezéskor törlődnek.

## Köszönet

A KRÉTA mobil protokoll ismerete a [bitiskola/kreten-desktop](https://github.com/bitiskola/kreten-desktop) projekt dokumentációjából és a [Firka](https://github.com/QwIT-Development/firka) kliensből származik. Ez a projekt nem tartalmaz kódot egyikből sem.
