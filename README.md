# Game of Life 

Ovaj projekt predstavlja implementaciju Conwayjeve Igre života (Game of Life), diskretnog celularnog automata, korištenjem programskog jezika **Emacs Lisp**. Aplikacija se izvodi unutar Emacs okruženja i omogućuje interaktivno praćenje evolucije mreže ćelija kroz grafičko korisničko sučelje.

Projekt je izrađen u okviru kolegija iz deklarativnog programiranja.

---

## Opis igre

Conwayjeva Igra života sastoji se od mreže ćelija koje mogu biti u jednom od dva stanja: **živo** ili **mrtvo**. U svakoj generaciji stanje svake ćelije mijenja se prema sljedećim pravilima:

- živa ćelija preživljava ako ima 2 ili 3 živa susjeda  
- mrtva ćelija postaje živa ako ima točno 3 živa susjeda  
- u svim ostalim slučajevima ćelija ostaje ili postaje mrtva  

Poanta igre nije u postizanju konačnog cilja, već u istraživanju kako se sustav razvija kroz generacije na temelju jednostavnih lokalnih pravila.

---


## Pokretanje aplikacije

### Preduvjeti:
  Instaliran **Emacs**

### Koraci
1. Preuzimanje repozitorija
2. Pokretanje Emacsa
3. Učitavanje datoteke u Emacsu
   - `M-x load-file`
   - pisanje putanje do mjesta gdje se nalazi datoteka
   - odabir `game_of_life.el`
4. Pokretanje aplikacije sljedećom naredbom
   - `M-x life`

Nakon toga otvara se novi buffer s prikazom Igre života.

---

## Upravljanje aplikacijom (kontrole)

| Tipka | Opis |
|------|------|
| `SPC` | Pokretanje / pauziranje simulacije |
| `n` | Prijelaz u sljedeću generaciju |
| `t` | Promjena stanja ćelije ispod kursora |
| `c` | Čišćenje mreže |
| `r` | Generiranje slučajne početne konfiguracije |
| `q` | Izlaz iz aplikacije |

