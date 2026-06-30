# Syslog

- Bevezetés
- Kategóriák és üzenet típusok
- Firmware paraméterek
- WM-ETerm

## Bevezetés

Már régóta érett egy olyan megoldás a firmware-ekbe, mellyel az ügyfélnél lévő eszközről lehetne visszamenőleg megtudni információt hibakeresés vagy anomáliák keresése során.

Az információk jellegéből kifolyólag két fő részre osztottam a firmwarben ezeket:

- Fejlesztői syslog
- Felhasználói syslog
A syslog bejegyzéseket kategóriákra lettek osztva, melyek a firmware funkciói alapján lettek kialakítva.

| **Kategória neve** | **Kategória azonosító** | **Kategória leírása** |
| --- | --- | --- |
| CATEGORY_DEVICE | 0 | Modemre vonatkozó kategória |
| CATEGORY_FW_UPDATE | 1 | Firmware update-tel kapcsolatos események kategóriája |
| CATEGORY_AT | 2 | Modul és modem közötti AT parancsokra vonatkozó kategória |
| CATEGORY_GSM | 3 | Hálózatkereséssel kapcsolatos kategória |
| CATEGORY_PDP | 4 | PDPcontext-tel kapcsolatos üzenetekhez tartozó kategória |
| CATEGORY_CSD | 5 | CSD hívással kapcsolatos kategória |
| CATEGORY_SMS | 6 | SMS küldés / fogadás / feldolgozásra létrehozott kategória |
| CATEGORY_SOCKET | 7 | Socket nyitás / zárás / infó kategória |
| CATEGORY_RTC | 8 | RTC modullal kapcsolatos kategória |
| CATEGORY_LASTGASP | 9 | Lastgasp eseményekkel kapcsolat kategória |
| CATEGORY_EVENT_QUEUE | 10 | Eseménykezelő sorok kezelésével kapcsolatos kategória |
| CATEGORY_TRANSPARENT_AT | 11 | Transzparens AT parancsok és feldolgozó kategória |
| CATEGORY_PUSH_SCHEDULER | 12 | Periódikus ütemező üzenetek kategóriája |
| CATEGORY_PING | 13 | Ping funkcióval kapcsolatos kategória |
| CATEGORY_NTP | 14 | NTP szinkronizáció kategóriája |
| CATEGORY_TCP | 15 | TCP funkcióval kapcsolatos kategória |
| CATEGORY_UDP | 16 | UDP funkcióval kapcsolatos kategória |
| CATEGORY_FTP | 17 | FTP funkcióval kapcsolatos kategória |
| CATEGORY_EI | 18 | EI kliens kategória |
| CATEGORY_IEC | 19 | IEC üzenetek, állapotok, kiolvasások kategóriája |
| CATEGORY_C86X | 20 | C.86.0 és C.86.6 regiszter kiolvasással kapcsolatos kategória |
| CATEGORY_WAKEUP | 21 | Wakeup esemény kategóriája |
| CATEGORY_DM | 22 | Device manager periódikus bejelzés kategóriája |
| CATEGORY_INPUT | 23 | Bemenet változás kategóriája |
| CATEGORY_CI | 24 | Customer interfész üzenetek kategóriája |
| CATEGORY_SNMP | 25 | SNMP funkció kategóriája |
| CATEGORY_TLS | 26 | TLS socket kezelés kategóriája |
| CATEGORY_INTERFACE | 27 | Interfészek közötti kommunikáció kategóriája |

Mindegyik kategórián belül több üzenettípus lett implementálva, mellyel a bejegyzések részletességét, sűrűségét, típusát lehet beállítani.

## Kategóriák és üzenet típusok

### CATEGORY_DEVICE

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_DEVICE_SYSLOG_CLEAR | 0 | WM-ETerm-ből lehetőség van a syslog bejegyzéseket tartozó területeket törölni. A törlést követően ez az üzenet kerül bejegyzésre. |
| MESSAGE_DEVICE_POWER_UP | 1 | A firmware indulása után létrehozott bejegyzés. A bejegyzésben a firmware verzió és a hardver verzió kerül tárolásra. Pl.: 5.3.45.0, 1 |
| MESSAGE_DEVICE_FW_RESTART_UPDATE | 2 | Firmware frissítés / modul indulási hiba utáni bejegyzés. A bejegyzésben tárolásra kerül az eredmény. |
| MESSAGE_DEVICE_FW_RESTART_CONFIG | 3 | Sikeres / Sikertelen konfiguráció utáni újraindulásról mentett bejegyzés. |
| MESSAGE_DEVICE_FW_RESTART_SCHEDULE | 4 | Periódikus / idő alapú újraindulás után. |
| MESSAGE_DEVICE_FW_RESTART_WAKEUP | 5 | SMS-ből kiadott újraindítási parancs után. |
| MESSAGE_DEVICE_FW_RESTART_MODEM | 6 | Nem implementált üzenet. |
| MESSAGE_DEVICE_ERROR_WDG | 7 | Amennyiben valamelyik RTOS task megáll, akkor watchdog újraindulás lesz. |
| MESSAGE_DEVICE_ERROR_OVERFLOW | 8 | Interfész buffer túlcsordulás esetén tárolt bejegyzés. |
| MESSAGE_DEVICE_ERROR_CONFIG | 9 | Hibás konfiguráció / works betöltés esetén. |
| MESSAGE_DEVICE_ERROR_MODEM | 10 | Egy percig folyamatos modem hálózati státusz hiba esetén. |
| MESSAGE_DEVICE_ERROR_INIT | 11 | Modul bekapcsolási szekvencia hiba esetén. |
| MESSAGE_DEVICE_CONFIG_START | 12 | Konfigurációs művelet indulását követően. |
| MESSAGE_DEVICE_CONFIG_END_OK | 13 | Konfigurációs művelet sikeres befejezését követően tárolt bejegyzés. |
| MESSAGE_DEVICE_CONFIG_END_ERROR | 14 | Konfigurációs művelet sikertelen befejezését követően tárolt bejegyzés. |
| MESSAGE_DEVICE_CONFIG_OPERATION | 15 | Konfigurációs művelet típusának tárolása. |

#### MESSAGE_DEVICE_SYSLOG_CLEAR

A naplófájlok törlését követően kerül a bejegyzés tárolásra. Az alábbi táblázat tartalmazza a WM-ETerm parancsot:

| **Parancs (napló bejegyzések törlése):** |  |
| --- | --- |
| 1B 16 52 FF <syslog_id> <packet_index> <checksum> |  |
| **Paraméterek:** |  |
| <syslog_id> | A <syslog_id> paraméterbe kell megadni, hogy melyik rendszernaplót szeretnénk kiolvasni. 00 – rendszernapló 01 – felhasználói rendszernapló (1 bájt) |
| <checksum> | Parancs checksum-ja. (1 bájt) |
| **Válasz:** |  |
| 1B 16 53 FF <syslog_id> <checksum> |  |
| **Paraméterek:** |  |
| <syslog_id> | A <syslog_id> a parancsból visszaadott érték. (1 bájt) |
| <checksum> | Válasz checksum-ja. (1 bájt) |

#### MESSAGE_DEVICE_POWER_UP

A firmware indulása után létrehozott bejegyzés. A bejegyzésben a firmware verzió és a hardver verzió kerül tárolásra.

Pl.: 5.3.45.0, 1

A hardver verzió a hardver ID-val van kapcsolatban. Az alábbi táblázat tartalmazza az azonosítókat:

| **Hardver verziószám** | **Hardver ID** |
| --- | --- |
| 1 | 1S00 |
| 2 | 1S01 |
| 3 | 1S10 |
| 4 | 1S11 |
| 5 | 1S12 |
| 6 | 1S13 |
| 7 | 2S00 |
| 8 | 2S01 |
| 9 | 2S10 |
| 10 | 2S11 |
| 11 | 2S12 |
| 12 | 2S13 |
| 13 | 2S20 |
| 14 | 2S21 |
| 15 | 2S22 |
| 16 | 2S23 |
| 17 | 3S20 |
| 18 | 3S21 |
| 19 | 3S70 |
| 20 | 3S71 |
| 21 | 3S72 |
| 22 | 3S73 |
| 23 | 8S10 |
| 24 | 8S11 |
| 25 | 8S12 |
| 26 | 8S13 |
| 27 | 9S14 |

#### MESSAGE_DEVICE_FW_RESTART_UPDATE

Firmware frissítés / modul indulási hiba utáni bejegyzés. A bejegyzésben tárolásra kerül az újraindulás oka:

| **Újraindulás azonosító** | **Újraindulás azonosító értéke** | **Újraindulás******leírása**** |
| --- | --- | --- |
| RESET_REQ_SW_UPD_FAIL | 4 | Firmware frissítő fájl fogadása sikertelen. |
| RESET_REQ_SW_UPD_OK | 8 | Firmware frissítő fájl fogadása sikeres. |
| RESET_REQ_MODEM_FAIL | 256 | Modul bekapcsolás sikertelen 5 egymást követő alkalommal. |
| RESET_REQ_MODEM_CHG_OK | 512 | Nincs implementálva. |

#### MESSAGE_DEVICE_FW_RESTART_CONFIG

Sikeres / Sikertelen konfiguráció utáni újraindulásról mentett bejegyzés. A bejegyzésben tárolásra kerül a konfiguráció eredménye:

| **Újraindulás azonosító** | **Újraindulás azonosító értéke** | **Újraindulás******leírása**** |
| --- | --- | --- |
| RESET_REQ_CFG_CHG_FAIL | 1 | Konfiguráció sikertelen. |
| RESET_REQ_CFG_CHG_OK | 2 | Konfiguráció sikeres. |

#### MESSAGE_DEVICE_FW_RESTART_SCHEDULE

Periódikus / idő alapú újraindulás után. A bejegyzésben tárolásra kerül az újraindulás oka.

Paraméterek:

- “smp.restart_time” paraméterben meghatározott időpontban a firmware újraindul.
- “smp.bos_timeout“ indulást követően, hány óra után induljon újra a modem.
| **Újraindulás azonosító** | **Újraindulás azonosító értéke** | **Újraindulás******leírása**** |
| --- | --- | --- |
| RESET_REQ_AUT_ONTIME | 128 | Automatikus újraindulás sikeres. |

#### MESSAGE_DEVICE_FW_RESTART_WAKEUP

SMS-ből kiadott újraindítási parancs után kerül bejegyzésre.

| **Újraindulás azonosító** | **Újraindulás azonosító értéke** | **Újraindulás******leírása**** |
| --- | --- | --- |
| RESET_REQ_WKP_CMD | 32 | SMS feldolgozást követő újraindítás parancs sikeres. |

#### MESSAGE_DEVICE_FW_RESTART_MODEM

Nincs implementálva.

#### MESSAGE_DEVICE_ERROR_WDG

Amennyiben valamelyik RTOS task megáll 10 másodpercre, akkor arról syslog eseményt ment a firmware. A mentett bejegyzésben a taskok állapota van eltárolva:

| **Task azonosító** | **Task indexe** | **Állapot******leírása**** |
| --- | --- | --- |
| wdg_config_task | 1 | Set - 1 Reset - 0 |
| wdg_emeter_task | 2 | Set - 1 Reset - 0 |
| wdg_local_config_task | 3 | Set - 1 Reset - 0 |
| wdg_modem_task | 4 | Set - 1 Reset - 0 |
| wdg_service_task | 5 | Set - 1 Reset - 0 |
| wdg_clo_task | 6 | Set - 1 Reset - 0 |
| wdg_extension_task | 7 | Set - 1 Reset - 0 |
| wdg_ci_task | 8 | Set - 1 Reset - 0 |

#### MESSAGE_DEVICE_ERROR_OVERFLOW

Interfész RX buffer túlcsordulás esetén tárolt bejegyzés. Az alábbi bejegyzés szövegek tárja a firmware:

| |
|---|
| **Tárolt üzenet szövege** |
| EMETER RX |
| MODEM RX |
| LOCAL RX |
| CLO RX |
| EXTENSION RX |
| CI RX |
| CONFIG RX |

#### MESSAGE_DEVICE_ERROR_CONFIG

Hibás konfiguráció / works betöltés esetén. Az esemény a betöltött struktúra nevét és eredményét tartalmazza:

- “CONFIG %d“
- "WORKS %d"
Betöltési eredmény:

| **Betöltési hiba értéke** | **Betöltési hiba leírása** |
| --- | --- |
| 2 | Betöltés során ismeretlen paramétert detektált a firmware, de a paraméterek elmentése nem volt sikeres, így a firmware az alapértelmezett konfigurációra áll át. |
| 3 | Betöltés során a paraméter struktúra feldolgozása hibás, így a firmware az alapértelmezett konfigurációra áll át. |

#### MESSAGE_DEVICE_ERROR_MODEM

Egy percig folyamatos modem hálózati státusz hiba esetén menti a bejegyzést a firmware. A firmware 5 másodpercenként ellenőrzi a hálózati értékeket, tehát 12 folyamatos hiba esetén tárolódik az esemény. A bejegyzésnek nincs speciális értéke.

#### MESSAGE_DEVICE_ERROR_INIT

Modul bekapcsolási szekvencia hiba esetén kerül bejegyzésre. A bejegyzésnek nincs speciális értéke.

#### MESSAGE_DEVICE_CONFIG_START

Ha a firmware detektálni tudja a konfiguráció kezdés szekvenciát (/?99999999!<CR><LF>), akkor tárolásra kerül a bejegyzés. A tárolás során a detektáció helyét / interfész azonosítóját tárolja a firmware:

| **Interfész azonosító** | **Interfész azonosító értéke** |
| --- | --- |
| DATAFLOW_EMETER | 0x00000002 |
| DATAFLOW_MODEM_TCP_SRV_A | 0x00000004 |
| DATAFLOW_MODEM_TCP_SRV_B | 0x00000008 |
| DATAFLOW_LOCAL_CONFIG | 0x00000010 |
| DATAFLOW_MODEM_CSD | 0x00000200 |
| DATAFLOW_EXTENSION | 0x00000400 |
| DATAFLOW_MODEM_TCP_SRV_TLS_DECRYPTED_A | 0x00010000 |
| DATAFLOW_MODEM_TCP_SRV_TLS_DECRYPTED_B | 0x00040000 |

#### MESSAGE_DEVICE_CONFIG_END_OK

Konfigurációs művelet sikeres befejezését követően tárolt bejegyzés. A bejegyzésnek nincs speciális értéke.

#### MESSAGE_DEVICE_CONFIG_END_ERROR

Konfigurációs művelet sikertelen befejezését követően tárolt bejegyzés. A hiba oka kerül eltárolása:

| **Hiba azonosító értéke** | **Hiba leírása** |
| --- | --- |
| -1 | Konfigurációs parancs ismeretlen. |
| -2 | Konfigurációs parancs feldolgozása / végrehajtása hibás. |
| -3 | A választ nem lehet elküldeni a cél interfészre. |
| -4 | Konfigurációs parancs nem olvasható az interfészről. |
| -5 | Konfiguráció időtúllépés. (2 perc inaktivitás) |

#### MESSAGE_DEVICE_CONFIG_OPERATION

Konfigurációs művelet típusának tárolása. A tárolásra kerül a művelet azonosítója, és művelet típusa:

- “0x%02X 0x%02X”
| **Művelet azonosító** | **Művelet azonosító értéke** | **Művelet leírása** |
| --- | --- | --- |
| cmdREADSTART | 0x67 | Konfigurációs olvasás. |
| cmdWRITESTART | 0x14 | Konfigurációs írás. |
| cmdPASSWORD | 0x24 | Jelszó megadása parancs. |
| cmdPASSWORDCHANGE | 0x26 | Jelszó módosítás parancs. |
| cmdPASSWORDDISABLE | 0x28 | Jelszó ki- / bekapcsolása. |
| cmdSYSLOGREADSTART | 0x50 | Syslog bejegyzés olvasása parancs. |
| cmdSYSLOGCLEAR | 0x52 | Syslog terület törlése. |

| **Művelet típus azonosító** | **Művelet típus azonosító értéke** | **Művelet típus leírása** |
| --- | --- | --- |
| WM_E_CA_CERT_READ | 0x04 | CA tanúsítvány olvasása. |
| WM_E_CERT_READ | 0x06 | Tanúsítvány olvasása. |
| WM_E_CRL_READ | 0x07 | CRL lista olvasása. |
| WM_E_CSR_NO_NEW_READ | 0x08 | CSR olvasás új privát kulcs generálása nélkül. |
| WM_E_CSR_NEW_READ | 0x09 | CSR olvasás új privát kulcs generálással. |
| WM_E_STATUS_READ | 0x0A | Státusz információk olvasása. |
| WM_E_SYSLOG_READ | 0x10 | Fejlesztői rendszernapló olvasása. |
| WM_E_USER_SYSLOG_READ | 0x11 | Felhasználói rendszernapló olvasása. |
| WM_E_CONFIGURATION_READ | 0xFF | Konfiguráció olvasása. |
| WM_E_UNKNOWN | 0x00 | Ismeretlen írási típus. |
| WM_E_BOOTLOADER | 0x01 | Bootloader frissítés. |
| WM_E_FIRMWARE | 0x02 | Firmware frissítés. |
| TELIT_FIRMWARE | 0x04 | Telit modul firmware frissítés. |
| WM_E_CONFIGURATION | 0xFF | Konfiguráció írás. |
| WM_E_CONFIG_PASSWORD_RESET | 0x00 | Konfigurációs jelszó kikapcsolása. |
| WM_E_CONFIG_PASSWORD_SET | 0x01 | Konfigurációs jelszó bekapcsolása. |
| WM_E_SYSLOG_CLEAR | 0x00 | Fejlesztői rendszernapló törlése. |
| WM_E_USER_SYSLOG_CLEAR | 0x01 | Felhasználói rendszernapló törlése. |

### CATEGORY_FW_UPDATE

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_FW_UPDATE_START | 0 | Firmware / bootloader / modul firmware frissítés indítását követően tárolja a firmware a bejegyzést. |
| MESSAGE_FW_UPDATE_END_OK | 1 | Firmware / bootloader / modul firmware frissítés sikeresen befejeződött. |
| MESSAGE_FW_UPDATE_END_ERROR | 2 | Firmware / bootloader / modul firmware frissítés sikertelen. |
| MESSAGE_FW_UPDATE_DWL_HEADER_OK | 3 | Firmware / bootloader frissítő fájl fejléc validálása / verifikációja sikeres. |
| MESSAGE_FW_UPDATE_DWL_HEADER_ERROR | 4 | Firmware / bootloader frissítő fájl fejléc validálása / verifikációja sikertelen. |

#### MESSAGE_FW_UPDATE_START

Firmware / bootloader / modul firmware frissítés indítását követően tárolja a firmware a bejegyzést, melyben a művelet típusát tárolja a firmware:

- "0x%02X"
| **Művelet típus azonosító** | **Művelet típus azonosító értéke** | **Művelet típus leírása** |
| --- | --- | --- |
| WM_E_BOOTLOADER | 0x01 | Bootloader frissítés. |
| WM_E_FIRMWARE | 0x02 | Firmware frissítés. |
| TELIT_FIRMWARE | 0x04 | Telit modul firmware frissítés. |

#### MESSAGE_FW_UPDATE_END_OK

Firmware / bootloader / modul firmware frissítés sikeresen befejeződött. A bejegyzésnek nincs speciális értéke.

#### MESSAGE_FW_UPDATE_END_ERROR

Firmware / bootloader / modul firmware frissítés sikertelen. A bejegyzésben tárolja a firmware a művelet típusát és a hibaértéket:

- “0x%02X %d“
| **Hiba értéke** | **Hiba érték leírása** |
| --- | --- |
| -1 | Tárolandó adat a tároló terület határán kívülre mutat. |
| -2 | Írási cím hibás / fejléc checksum hiba. |
| -3 | Checksum értéke nem 0xFF. |
| -4 | Hibás HW_ID. |
| -5 | Frissítő fájl mérete 0. |
| -6 | Fájl nagyobb, mint a tárterület. |
| -8 | Fájl padding hiba. |
| -9 | Fájl típusa hibás. |

#### MESSAGE_FW_UPDATE_DWL_HEADER_OK

Firmware / bootloader frissítő fájl fejléc validálása / verifikációja sikeres. [TODO_ dwl fejléc formátumról leírás]

A bejegyzésnek nincs speciális értéke.

#### MESSAGE_FW_UPDATE_DWL_HEADER_ERROR

Firmware / bootloader frissítő fájl fejléc validálása / verifikációja sikertelen. A bejegyzésnek nincs speciális értéke, a MESSAGE_FW_UPDATE_END_ERROR bejegyzésben a hiba oka el van tárolva.

### CATEGORY_AT

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_AT_ERROR | 0 | AT parancsra ERROR / NO CARRIER válaszol a modul vagy nincs válasz a modultól. |
| MESSAGE_AT_CME_ERROR | 1 | AT parancsra CME ERROR-ral válaszol a modul. |
| MESSAGE_AT_CMS_ERROR | 2 | AT parancsra CMS ERROR-ral válaszol a modul. |

#### MESSAGE_AT_ERROR

AT parancsra ERROR / NO CARRIER válaszol a modul vagy nincs válasz a modultól az utolsó újrapróbálkozást követően sem, akkor a firmware ezt a bejegyzést tárolja. Az alábbi üzenet formátumok vannak:

- "%s %s" → AT parancs, AT parancs válasz
- “%s COMMAND TIMEOUT (%d msec)” → AT parancs, időtúllépés értéke
#### MESSAGE_AT_CME_ERROR

Ha AT parancsra CME ERROR-ral válaszol a modul az utolsó újrapróbálkozás után is, akkor tárolja a firmware a bejegyzést. Üzenet formátum:

- "%s %s" → AT parancs, AT parancs válasz
#### MESSAGE_AT_CMS_ERROR

Ha AT parancsra CMS ERROR-ral válaszol a modul az utolsó újrapróbálkozás után is, akkor tárolja a firmware a bejegyzést. Üzenet formátum:

- "%s %s" → AT parancs, AT parancs válasz
### CATEGORY_GSM

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_GSM_INFO | 0 | Hálózati státusz értékekről tárolt bejegyzés. |
| MESSAGE_GSM_ERROR | 1 | Hálózatregisztrációs hiba esetén, illetve 5 másodpercenként van hálózat státusz figyelés, amennyiben hibát detektál a firmware, akkor a fejlesztői naplóba kerül bejegyzés. |
| MESSAGE_GSM_PROVIDER_CHANGE | 2 | Operátor változás esetén mentett bejegyzés. |
| MESSAGE_GSM_LOCATION_CHANGE | 3 | Lokációs ID változás esetén mentett bejegyzés. |
| MESSAGE_GSM_CELL_CHANGE | 4 | Cella ID változás esetén mentett bejegyzés. |
| MESSAGE_GSM_RESET_SIM_ERROR | 5 | SIM ellenőrzés hibával tért vissza, akkor a firmware eltárolja az okot. |
| MESSAGE_GSM_RESET_SIM_INIT_ERROR | 6 | SIM ellenőrzés hiba detektáláshoz implementált bejegyzés. |
| MESSAGE_GSM_RESET_NET_REG_ERROR | 7 | Hálózatregisztráció utolsó próbálkozását követően tárolt esemény. |
| MESSAGE_GSM_RESET_TURN_ON | 8 | Nincs implementálva. |
| MESSAGE_GSM_RESET_TURN_OFF | 9 | Nincs implementálva. |
| MESSAGE_GSM_RESET_GENERAL_INIT | 10 | Nincs implementálva. |
| MESSAGE_GSM_RESET_AUTH_CHANGE | 11 | Autentikációs paraméter megváltozott, vagy autentikáció kikapcsolása esetén kerül bejegyzésre. |
| MESSAGE_GSM_RESET_APN_CHANGE | 12 | APN változás esetén tárolt napló. |

#### MESSAGE_GSM_INFO

Hálózati státusz értékekről tárolt bejegyzés. A hálózatregisztrációt követően tárol a firmware ilyen típusú üzenetet. Ezen felül óránként a felhasználói naplóba kerül jegyezés az információkról.

Az üzenet formátuma:

- “%u, -%u, %u, %u, %u, %u” → Operátor ID, RSSI, Technológia, CREG / CEREG státusz, Lokáció ID, Cella ID
#### MESSAGE_GSM_ERROR

Hálózatregisztrációs hiba esetén a visszatérési értékét tárolja:

- "%d"
| **Hiba értéke** | **Hiba érték leírása** |
| --- | --- |
| 0 | AT parancs válasz időtúllépés. |
| 1 | AT parancs válasz ERROR / CME ERROR / CMS ERROR. |
| 255 | Egyéb AT parancs hiba esetén. |
| -6 | Hálózatválasztás típusa ismeretlen. |
| -7 | Hálózatregisztráció 5 egymást követő alkalommal hibára futott. |

5 másodpercenként van hálózat státusz figyelés, amennyiben hibát detektál a firmware, akkor a fejlesztői naplóba kerül bejegyzés:

- “%u, -%u, %u“ → CREG / CEREG státusz, RSSI, Operátor ID
#### MESSAGE_GSM_PROVIDER_CHANGE

Operátor ID változás esetén kerül bejegyzésre. A bejegyzésnek nincs speciális értéke.

#### MESSAGE_GSM_LOCATION_CHANGE

Lokációs ID változás esetén kerül bejegyzésre. A bejegyzésnek nincs speciális értéke.

#### MESSAGE_GSM_CELL_CHANGE

Cella ID változás esetén kerül bejegyzésre. A bejegyzésnek nincs speciális értéke.

#### MESSAGE_GSM_RESET_SIM_ERROR

SIM ellenőrzés 5 alkalommal hibával tért vissza, akkor a firmware eltárolja az okot. A bejegyzésnek nincs speciális értéke.

#### MESSAGE_GSM_RESET_SIM_INIT_ERROR

SIM ellenőrzés hiba detektáláshoz implementált bejegyzés. Az üzenet eltárolja a SIM státuszt és a hátralévő PIN próbálkozások száma:

- "%u, %u" → SIM státusz, SIM PIN hátralevő próbálkozások száma.
#### MESSAGE_GSM_RESET_NET_REG_ERROR

Hálózatregisztráció utolsó próbálkozását követően tárolt esemény. A tárolt adatokból meg lehet állapítani, hogy a hálózatregisztráció miért nem sikerült. Üzenet formátum:

- "%d, -%u, %u, %u, %u" → Újra próbálkozások száma, RSSI, Hálózatválasztás módja, Operátor elérhetősége, Operátor ID
#### MESSAGE_GSM_RESET_AUTH_CHANGE

Autentikációs paraméter megváltozott, vagy autentikáció kikapcsolása esetén kerül bejegyzésre. A bejegyzésnek nincs speciális értéke.

#### MESSAGE_GSM_RESET_APN_CHANGE

APN változás esetén tárolt napló. A bejegyzésnek nincs speciális értéke.

### CATEGORY_PDP

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_PDP_ERROR | 0 | MODEM_PDP_STATUS_READY állapot esetén, ha a státuszok közül valamelyik hibát jelez, akkor fejlesztői bejegyzésre kerül a sor. |
| MESSAGE_PDP_CTX_ACTIVATION_OK | 1 | Sikeres PDP context aktiválás utáni esemény. |
| MESSAGE_PDP_CTX_ACTIVATION_ERROR | 2 | Sikertelen PDP context aktiválási kísérlet után mentett bejegyzés. |
| MESSAGE_PDP_CTX_DEACTIVATION_OK | 3 | Sikeres PDP context deaktiválás utáni esemény. |
| MESSAGE_PDP_CTX_DEACTIVATION_ERROR | 4 | Sikertelen PDP context deaktiválási kísérlet után mentett bejegyzés. |
| MESSAGE_PDP_RESET_IP_FLOOD | 5 | Azonos IP portra bejövő második kapcsolat felett a bejövő kapcsolatot a modem bontja és az eseményről bejegyzést ment. |
| MESSAGE_PDP_RESET_CTX_ACTIVATION | 6 | Sikertelen PDP context aktiválási kísérlet után modul újraindítási esemény bejegyzése. |
| MESSAGE_PDP_RESET_CTX_DEACTIVATION | 7 | Sikertelen PDP context deaktiválási kísérlet után modul újraindítási esemény bejegyzése. |

#### MESSAGE_PDP_ERROR

MODEM_PDP_STATUS_READY állapot esetén, ha a státuszok közül valamelyik hibát jelez, akkor fejlesztői bejegyzésre kerül a sor. Az üzenet formátuma az alábbi:

- “%u, %u, %u.%u.%u.%u” → PDP státusz, IP státusz, IP cím
| **PDP státusz értéke** | **PDP státusz leírása** |
| --- | --- |
| 0 | PDP context aktiválása nem sikerült. |
| 1 | PDP context aktív és van érvényes IP cím. |

| **IP státusz értéke** | **IP státusz leírása** |
| --- | --- |
| 0 | Nincs IP cím tárolva. |
| 1 | Van IP cím tárolva, de már nem érvényes. |
| 2 | Van IP cím és érvényes. |

#### MESSAGE_PDP_CTX_ACTIVATION_OK

Sikeres PDP context aktiválás utáni esemény. Az üzenet formátuma az alábbi:

- “%u, %u, %u.%u.%u.%u” → PDP státusz, IP státusz, IP cím
| **PDP státusz értéke** | **PDP státusz leírása** |
| --- | --- |
| 0 | PDP context aktiválása nem sikerült. |
| 1 | PDP context aktív és van érvényes IP cím. |

| **IP státusz értéke** | **IP státusz leírása** |
| --- | --- |
| 0 | Nincs IP cím tárolva. |
| 1 | Van IP cím tárolva, de már nem érvényes. |
| 2 | Van IP cím és érvényes. |

#### MESSAGE_PDP_CTX_ACTIVATION_ERROR

Sikertelen PDP context aktiválási kísérlet után mentett bejegyzés. Az üzenet formátuma az alábbi:

- "%u, %u" → PDP aktiválás ismétlés száma, PDP státusz
| **PDP státusz értéke** | **PDP státusz leírása** |
| --- | --- |
| 0 | PDP context aktiválása nem sikerült. |
| 1 | PDP context aktív és van érvényes IP cím. |

#### MESSAGE_PDP_CTX_DEACTIVATION_OK

Sikeres PDP context deaktiválás utáni esemény. A bejegyzésnek nincs speciális értéke.

#### MESSAGE_PDP_CTX_DEACTIVATION_ERROR

Sikertelen PDP context deaktiválási kísérlet után mentett bejegyzés. A bejegyzésnek nincs speciális értéke.

#### MESSAGE_PDP_RESET_IP_FLOOD

Azonos IP portra bejövő második kapcsolat felett a bejövő kapcsolatot a modem bontja és az eseményről bejegyzést ment. Az üzenet formátuma az alábbi:

- "%u, %u, %u" → Socketen beérkező adat száma, Socketre írási hiba száma, Kéretlen bejövő kapcsolatok száma
#### MESSAGE_PDP_RESET_CTX_ACTIVATION

Sikertelen PDP context aktiválási kísérlet után modul újraindítási esemény bejegyzése. Az üzenet formátuma az alábbi:

- "-%u, %u, %u.%u.%u.%u" → RSSI, IP státusz, IP cím
| **IP státusz értéke** | **IP státusz leírása** |
| --- | --- |
| 0 | Nincs IP cím tárolva. |
| 1 | Van IP cím tárolva, de már nem érvényes. |
| 2 | Van IP cím és érvényes. |

#### MESSAGE_PDP_RESET_CTX_DEACTIVATION

Sikertelen PDP context deaktiválási kísérlet után modul újraindítási esemény bejegyzése. Az üzenet formátuma az alábbi:

- "-%u, %u, %d" → RSSI, PDP státusz, PDP deaktiválás eredménye
| **PDP státusz értéke** | **PDP státusz leírása** |
| --- | --- |
| 0 | PDP context aktiválása nem sikerült. |
| 1 | PDP context aktív és van érvényes IP cím. |

### CATEGORY_CSD

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_CSD_ACCEPT | 0 | Bejövő adathívás fogadása esetén tárolt esemény. |
| MESSAGE_CSD_HANG | 1 | CSD hívás végén a hívás lezárását követően menti a firmware a bejegyzést. |
| MESSAGE_CSD_TYPE_AND_NUMBER | 2 | RING URC-t követően tárolja a hívás típusát és a hívó telefonszámát. |
| MESSAGE_CSD_STATUS | 3 | A CSD hívás alatt az állapotgép státuszváltozásai után tárolt esemény. |

#### MESSAGE_CSD_ACCEPT

Bejövő adathívás fogadása esetén tárolt esemény. A bejegyzésnek nincs speciális értéke.

#### MESSAGE_CSD_HANG

CSD hívás végén a hívás lezárását követően menti a firmware a bejegyzést. Az üzenet formátuma az alábbi:

- "%u" → Bontás oka
| **Bontás oka** | **Bontás okának értéke** | **Bontás okának leírása** |
| --- | --- | --- |
| CSD_HANG_TIMEOUT | 0 | Ha a hívás közben nincs adat küldés / fogadás 2 percig. |
| CSD_HANG_ESCAPE | 1 | +++ karaktersorozat detektálva után. |
| CSD_HANG_NOCARRIER | 2 | NO CARRIER karaktersorozat detektálása után. |
| CSD_HANG_OK | 3 | OK karaktersorozat detektálása után. |
| CSD_HANG_RESET | 4 | Amennyiben a modemnek újra kell valami miatt indulnia. |

#### MESSAGE_CSD_TYPE_AND_NUMBER

RING URC-t követően tárolja a hívás típusát és a hívó telefonszámát. Az üzenet formátuma az alábbi:

- "%u %s" → Hívás módja, hívószám
| **Hívás módjának értéke** | **Hívás módjának leírása** |
| --- | --- |
| 0 | Hang hívás. |
| 1 | Adat hívás. |
| 2 | Fax. |

#### MESSAGE_CSD_STATUS

A CSD hívás alatt az állapotgép státuszváltozásai után tárolt esemény. Az üzenet formátuma az alábbi:

- "%u %u, %u %u" → Előző CSD főstátusz, Aktuális CSD főstátusz, Előző CSD alstátusz, Aktuális CSD alstátusz
| **Fő CSD státusz** | **Fő CSD státusz értéke** | **Fő CSD státusz leírása** |
| --- | --- | --- |
| CSD_CALL_STATUS_IDLE | 0 | Várakozó állapot, amíg nincs bejövő hívás, addig ebben az állapotban várakozik az állapotgép. |
| CSD_CALL_WAIT_PDP_DEACTIVATE | 1 | A hívás fogadását követően, ha szükség van a PDP deaktiválásra, akkor addig ebben az állapotban várakozik a firmware. |
| CSD_CALL_WAIT_2G_FALLBACK | 2 | Bizonyos moduloknál 2G fallbackre kell várakozni a CSD hívás fogadása előtt, addig ebben az állapotban várakozik a firmware. |
| CSD_CALL_ACCEPT | 3 | CSD hívás elfogadása állapot. |
| CSD_CALL_AUTHENTICATION | 4 | Ha szükség van autentikációra, akkor azt ebben az állapotban csinálja a firmware. |
| CSD_CALL_DIAL | 5 | Ha kimenő hívásra van szükség, akkor ebben az állapotban indítja a firmware a CSD hívást. |
| CSD_CALL_IN_PROGRESS | 6 | Fogadott hívás alatti állapot. |
| CSD_CALL_FINISHED | 7 | Hívás befejezését követő állapot. |

| **Al CSD státusz** | **Al CSD státusz értéke** | **Al CSD státusz leírása** |
| --- | --- | --- |
| CSD_CALL_IN_PROGRESS_INIT | 0 | Alap állapot. Beállítás függően lép át a következő állapotra. |
| CSD_CALL_IN_PROGRESS_WAIT_HANDSHAKE | 1 | CSD protokoll handshake üzenetre várakozó állapot. |
| CSD_CALL_IN_PROGRESS_HANDSHAKE | 2 | CSD protokoll és kimenő hívás esetén itt várakozik a firmware a handshake válaszra. |
| CSD_CALL_IN_PROGRESS_SEND_AND_RECEIVE | 3 | CSD protokoll esetén adat fogadás / küldés állapota. |
| CSD_CALL_IN_PROGRESS_FIN | 4 | CSD protokoll esetén FIN üzenet küldés állapota. |
| CSD_CALL_IN_PROGRESS_TRANSPARENT | 5 | CSD adat fogadás / küldés transzparens módon. |

### CATEGORY_SMS

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_SMS_READ_OK | 0 | Sikeres SMS olvasást követően tárolt esemény. |
| MESSAGE_SMS_READ_ERROR | 1 | SMS olvasás amennyiben nem sikerül, tároljuk annak okát. |
| MESSAGE_SMS_DELETE_OK | 2 | SMS törlés sikeres befejezése után tárolt bejegyzés. |
| MESSAGE_SMS_DELETE_ERROR | 3 | Sikertelen SMS törlés esetén. |
| MESSAGE_SMS_PROCESS_OK | 4 | SMS-ben kapott parancs feldolgozás sikeres volt. |
| MESSAGE_SMS_PROCESS_ERROR | 5 | SMS parancs hiba esetén tárolt bejegyzés. |
| MESSAGE_SMS_SEND_OK | 6 | Sikeres SMS küldést követően tárolt esemény. |
| MESSAGE_SMS_SEND_ERROR | 7 | Sikertelen SMS küldést követően tárolja a firmware. |

#### MESSAGE_SMS_READ_OK

Sikeres SMS olvasást követően tárolt esemény. Az üzenet formátuma az alábbi:

- "%d, %d, %s" → SMS index, SMS hossza, SMS feladójának telefonszáma.
#### MESSAGE_SMS_READ_ERROR

SMS olvasás amennyiben nem sikerül, tároljuk annak okát. Az üzenet formátuma az alábbi:

- "%u" → SMS olvasási hiba oka
| **SMS olvasási hiba okának neve** | **SMS olvasási hiba okának értéke** | **SMS olvasási hiba okának leírása** |
| --- | --- | --- |
| SMS_READ_ERROR_TEXT | 0 | SMS szöveg olvasás hibára fut. |
| SMS_READ_ERROR_COMMAND | 1 | AT+CMGR parancs hibával tér vissza. |

#### MESSAGE_SMS_DELETE_OK

SMS törlés sikeres befejezése után tárolt bejegyzés. Az üzenet formátuma az alábbi:

- "%d" → SMS index
#### MESSAGE_SMS_DELETE_ERROR

Sikertelen SMS törlés esetén. Az üzenet formátuma az alábbi:

- "%u" → SMS törlési hiba oka
| **SMS törlési hiba okának neve** | **SMS törlési hiba okának értéke** | **SMS törlési hiba okának leírása** |
| --- | --- | --- |
| SMS_DELETE_ERROR_COMMAND | 0 | AT+CMGD parancs hibával tér vissza. |

#### MESSAGE_SMS_PROCESS_OK

SMS-ben kapott parancs feldolgozás sikeres volt. Az üzenet formátuma az alábbi:

- "%u" → SMS parancs azonosítója
| **SMS parancs azonosító neve** | **SMS parancs azonosító értéke** | **SMS parancs azonosító leírása** |
| --- | --- | --- |
| SMS_PROCESS_PDP_ATTACH | 0 | PDP context aktiváló parancs. |
| SMS_PROCESS_CONFIG_RESET | 1 | Konfigurációt alapértelmezettre állító parancs. |
| SMS_PROCESS_DEVICE_RESET | 2 | Modem újraindítás parancs. |
| SMS_PROCESS_REGISTER_READ | 3 | IEC regiszter olvasó parancs. |
| SMS_PROCESS_CERT_RESET | 4 | Tanúsítvány törlése és alapértelmezettre állító parancs. |
| SMS_PROCESS_CONFIG_READ_OR_WRITE | 5 | Konfigurációs paraméter írás / olvasása parancs. |

#### MESSAGE_SMS_PROCESS_ERROR

SMS parancs hiba esetén tárolt bejegyzés. Az üzenet formátuma az alábbi:

- "%u" → SMS parancs hiba azonosítója
| **SMS parancs azonosító neve** | **SMS parancs azonosító értéke** | **SMS parancs azonosító leírása** |
| --- | --- | --- |
| SMS_PROCESS_ERROR_PASSWORD_UNKNOWN | 6 | Jelszó nincs beállítva, de a felhasználó mégis pw=-vel kezdte az SMS-t. |
| SMS_PROCESS_ERROR_PASSWORD_MISMATCH | 7 | Az SMS-ben kapott és a beállított jelszó eltérő. |
| SMS_PROCESS_ERROR_COMMAND_FORMAT_ERROR | 8 | Jelszó után nincs “.“ karakter. |

#### MESSAGE_SMS_SEND_OK

Sikeres SMS küldést követően tárolt esemény. Az üzenet formátuma az alábbi:

- "%u %u %s" → Típus azonosító, Kód azonosító, Címzett telefonszáma
| **Típus azonosító neve** | **Típus azonosító értéke** | **Típus azonosító leírása** |
| --- | --- | --- |
| EVENT_TYPE_ALARM | 4 | Minden kiküldendő SMS alarm típusú. Pl. Lastgasp, |

| **Kód azonosító neve** | **Kód azonosító értéke** | **Kód azonosító leírása** |
| --- | --- | --- |
| EVENT_CODE_ALARM_LASTGASP_DRAIN | 7 | Scap feszültség a lemerült határérték alá esett. |
| EVENT_CODE_ALARM_LASTGASP_CHARGED | 8 | Scap feszültség a feltöltött határérték felé töltődött. |
| EVENT_CODE_ALARM_INPUT | 9 | Analóg bemenet állapot változásról küldött esemény. |
| EVENT_CODE_ALARM_DINPUT | 10 | Digitális bement állapot változásról küldött esemény. |
| EVENT_CODE_ALARM_EMETER_C860 | 13 | C.86.0 regiszter értékének változása esetén küldött esemény. |
| EVENT_CODE_ALARM_EMETER_C866 | 14 | C.86.6 regiszter értékének változása esetén küldött esemény. |
| EVENT_CODE_ALARM_DEBUG | 16 | PDP context aktiválást követően küldhető esemény, amennyiben a konfigurációban engedélyezett a funkció. |
| EVENT_CODE_ALARM_SMS_COMMAND_PROCESS | 17 | SMS parancs feldolgozásra küldendő válasz esemény kódja. |

#### MESSAGE_SMS_SEND_ERROR

Sikertelen SMS küldést követően tárolja a firmware. Az üzenet formátuma az alábbi:

- "%u" → SMS küldési hiba oka
| **SMS küldési hiba azonosító neve** | **SMS küldési hiba azonosító értéke** | **SMS küldési hiba leírása** |
| --- | --- | --- |
| SMS_SEND_ERROR_TELEPHONE_NUMBER_UNKNOWN | 0 | Küldendő eszköz telefonszáma ismeretlen. |
| SMS_SEND_ERROR_COMMAND | 1 | Küldés során kiadott AT parancs valamelyike ERROR-ral válaszolt. |
| SMS_SEND_ERROR_TEXT | 2 | SMS szöveg küldése hibája esetén. |

### CATEGORY_SOCKET

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_SOCKET_CONNECT | 0 | Socket kapcsolat sikeres kiépítését követően tárolja a firmware az eseményt. |
| MESSAGE_SOCKET_DISCONNECT | 1 | Socket kapcsolat bontását követően tárolt esemény. |
| MESSAGE_SOCKET_ERROR | 2 | Socket bontásakor ellenőrizzük, hogy volt-e hiba socket művelet közben és ennek értékét tárolja a modem. |
| MESSAGE_SOCKET_TIMEOUT | 3 | Inaktív kapcsolat, nincs adatforgalom a socket-en. |

#### MESSAGE_SOCKET_CONNECT

Socket kapcsolat sikeres kiépítését követően tárolja a firmware az eseményt. Az üzenet formátuma az alábbi:

- "%u, %u, %d, %u.%u.%u.%u" → Socket ID, Socket státusz, Socket error, IP cím
| **Socket státusz értéke** | **Socket státusz leírása** |
| --- | --- |
| 0 | Socket inicializált alapértelmezett állapota. |
| 1 | Socket nyitási URC vagy nyitási kérés státusz detektálva. |
| 2 | Socket nyitva és kész a kommunikációra. |

#### MESSAGE_SOCKET_DISCONNECT

Socket kapcsolat bontását követően tárolt esemény. Az üzenet formátuma az alábbi:

- "%u, %u, %u, %d, %u, %u" → Bontás típusa, Socket ID, Socket státusz, Socket error, Összes olvasott bájtok száma, Összes továbbított bájtok száma
- "%u, %d, %u" → Bontás típusa, Socket ID, Szerver socket szolgáltatás állapota
| **Bontás típus azonosító** | **Bontás típus azonosító értéke** | **Bontás típus azonosító leírása** |
| --- | --- | --- |
| SOCKET_TIMEOUT | 0 | Inaktív kapcsolat, nincs adatforgalom a socket-en. |
| CLOSED_BY_MODEM | 1 | Modem által kezdeményezett socket bontás. |
| CLOSED_BY_PEER | 2 | Távoli kapcsolat által kezdeményezett socket bontás esetén. |
| CLOSED_NORMAL | 3 | Socket bontás normál függvény szerint. |
| CLOSED_FORCED | 4 | Socket bontás kényszerített függvény szerint. |

| **Szerver socket szolgáltatás azonosító** | **Szerver socket szolgáltatás azonosító értéke** | **Szerver socket szolgáltatás leírása** |
| --- | --- | --- |
| SERVER_SRV_STATE_INACTIVE | 0 | Alapértelmezett állapot, várakozás bejövő socket kapcsolatra. |
| SERVER_SRV_STATE_CONNECT | 1 | Socket kapcsolat kiépítés. |
| SERVER_SRV_STATE_TRANSP_MODE | 2 | Utility socket-en transzparens kommunikáció / konfigurációs művelet. |
| SERVER_SRV_STATE_TRANSP_SECONDARY_MODE | 3 | Customer socket-en transzparens kommunikáció / konfigurációs művelet |
| SERVER_SRV_STATE_BREAK_MODE | 4 | Socket bontás előtt break parancs küldés a mérőnek. |
| SERVER_SRV_STATE_DISCONNECT | 5 | Kapcsolatbontás állapota. |

#### MESSAGE_SOCKET_ERROR

Socket bontásakor ellenőrizzük, hogy volt-e hiba socket művelet közben és ennek értékét tárolja a modem. Az üzenet formátuma az alábbi:

- "%u, %u, %d" → Socket ID, Socket státusz, Socket error
#### MESSAGE_SOCKET_TIMEOUT

Inaktív kapcsolat, nincs adatforgalom a socket-en. Az üzenet formátuma az alábbi:

- "%u, %d, %u" → Bontás típusa, Socket ID, Szerver socket szolgáltatás állapota
### CATEGORY_RTC

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_RTC_INIT | 0 | RTC periféria inicializálását követően menti az eseményt a firmware. |
| MESSAGE_RTC_SET | 1 | RTC dátum / idő beállítás után tárolt bejegyzés. |
| MESSAGE_RTC_ERROR | 2 | RTC dátum / idő beállítási hiba után mentett esemény. |

#### MESSAGE_RTC_INIT

RTC periféria inicializálását követően menti az eseményt a firmware. Az üzenet formátuma az alábbi:

- “%u 0x%04x 0x%04x %u” → Hard init, Visszatérési érték, RTC clock source, RTC init eredmény
| **Hard init értéke** | **Hard init leírása** |
| --- | --- |
| 0 | Nem volt szükség hard init-re. |
| 1 | Hard init-re volt szükség, tehát az RTC periféria teljesen újra lett inicializálva, így az RTC idő helytelen. |

| **Visszatérési érték maszk értékek** | **Visszatérési érték maszk leírása** |
| --- | --- |
| 0x0001 | Backup domain resetelése sikertelen. |
| 0x0010 | LSE nem indítható el. |
| 0x0020 | RTC clock nem LSE-ről megy. |
| 0x0040 | LSI nem indítható el. |
| 0x0080 | RTC clock nem LSI-ről megy. |
| 0x0100 | Hard init alatt LSE nem indítható el. |
| 0x0200 | Hard init alatt LSI nem indítható el. |
| 0x0400 | RTC periféria deinit függvény hibával tér vissza. |
| 0x0800 | RTC periféria init függvény hibával tér vissza. |
| 0x1000 | RTC idő beállítás függvény hibával tér vissza. |
| 0x2000 | RTC dátum beállítás függvény hibával tér vissza. |

#### MESSAGE_RTC_SET

RTC dátum / idő beállítás után tárolt bejegyzés. Az üzenet formátuma az alábbi:

- “%u %02X-%02X-%02X,%02X:%02X:%02X” → RTC beállítás forrása, RTC dátum és idő
| **RTC beállítás forrás azonosító** | **RTC beállítás forrás azonosító értéke** | **RTC beállítás forrás azonosító leírása** |
| --- | --- | --- |
| RTC_SOURCE_NETWORK | 0 | AT+CCLK parancs által visszaadott eredmény után mentett RTC dátum / idő. |
| RTC_SOURCE_NETWORK_ALT | 1 | AT+CTZV parancs által visszaadott eredmény után mentett RTC dátum / idő. |
| RTC_SOURCE_NTP | 2 | NTP szinkronizációt követően visszaadott eredmény után mentett RTC dátum / idő. |

#### MESSAGE_RTC_ERROR

RTC dátum / idő beállítási hiba után mentett esemény. Az üzenet formátuma az alábbi:

- “%u %d” → RTC beállítás forrása, Hiba értéke
| **RTC beállítás forrás azonosító** | **RTC beállítás forrás azonosító értéke** | **RTC beállítás forrás azonosító leírása** |
| --- | --- | --- |
| RTC_SOURCE_NETWORK | 0 | AT+CCLK parancs által visszaadott eredmény után mentett RTC dátum / idő. |
| RTC_SOURCE_NETWORK_ALT | 1 | AT+CTZV parancs által visszaadott eredmény után mentett RTC dátum / idő. |
| RTC_SOURCE_NTP | 2 | NTP szinkronizációt követően visszaadott eredmény után mentett RTC dátum / idő. |

| **Hiba értéke** | **Hiba érték leírása** |
| --- | --- |
| 1 | Idő beállító függvény hibával tér vissza. |
| 2 | Dátum beállító függvény hibával tér vissza. |

### CATEGORY_LASTGASP

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_LASTGASP_STATUS | 0 | Lastgasp állapotgép változás esetén tárolt bejegyzés. |

#### MESSAGE_LASTGASP_STATUS

Lastgasp állapotgép változás esetén tárolt bejegyzés. Az üzenet formátuma az alábbi:

- “%d %d” → Korábbi állapot, Aktuális állapot
| **Korábbi / aktuális állapot** | **Korábbi / aktuális állapot értéke** | **Leírás** |
| --- | --- | --- |
| SCAP_INIT | 0 | Alapértelmezett állapot firmware indulás után. |
| SCAP_CHARGING | 1 | Scap feszültség nagyobb mint 0, de kisebb mint a SCAP_CHARGED_TRESHOLD. Ha eléri a SCAP_CHARGED_TRESHOLD szintet, akkor lastgasp eseményt tud generálni a firmware. |
| SCAP_CHARGED | 2 | Scap feszültség nagyobb vagy egyenlő mint a SCAP_CHARGED_TRESHOLD. Amennyiben a feszültségszint lecsökken SCAP_CHARGED_TRESHOLD alá, akkor a lastgasp SCAP_DRAINS állapotba lép. |
| SCAP_DRAINS | 3 | Ha az scap feszültség SCAP_LASTGASP_TRESHOLD szint alá csökken, akkor lasgasp eseményt tud generálni a firmware. Ha az scap feszültség SCAP_DRAIN_TRESHOLD alá csökken, akkor SCAP_DISCHARGED állapotba lép a firmware. Ha az scap fesztülség nagyobb vagy egyenlő mint SCAP_CHARGED_TRESHOLD, akkor függően attól, hogy volt-e **_lasgasp_lost_**eseményküldés a firmware generál **_lastgasp_return_**eseményt. Amennyiben nem volt, akkor eseménygenerálás nélkül a lastgasp SCAP_CHARGED állapotba lép. |
| SCAP_DISCHARGED | 4 | Ha a feszültség SCAP_DRAIN_TRESHOLD-nél nagyobb vagy egyenlő, akkor az scap SCAP_CHARGING állapotba kerül. |

### CATEGORY_EVENT_QUEUE

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_EVENT_QUEUE_PUSH_OK | 0 | Sikeres esemény sorba tárolás után mentett bejegyzés. |
| MESSAGE_EVENT_QUEUE_PUSH_ERROR | 1 | Sikertelen esemény sorba tárolás után mentett bejegyzés. |
| MESSAGE_EVENT_QUEUE_PULL_OK | 2 | Sikeres esemény sorból törlés után mentett bejegyzés. |
| MESSAGE_EVENT_QUEUE_PULL_ERROR | 3 | Sikertelen esemény sorból törlés után mentett bejegyzés. |

#### MESSAGE_EVENT_QUEUE_PUSH_OK

Sikeres esemény sorba tárolás után mentett bejegyzés. Az üzenet formátuma az alábbi:

- "%d %u %u %d %d" → Tárolási index, Típus azonosító, Kód azonosító, Sor index, Sorban tárolt elemek száma
| **Típus azonosító neve** | **Típus azonosító értéke** | **Típus azonosító leírása** |
| --- | --- | --- |
| EVENT_TYPE_QUEUE_ERROR | 0 | Sor hiba esetén. |
| EVENT_TYPE_NONE | 1 | Ha nincs szükség típusra, akkor ezt az azonosítót lehet használni. |
| EVENT_TYPE_IEC | 2 | IEC műveletek esetén használatos típus. |
| EVENT_TYPE_PUSH | 3 | Push üzenetek típusnál lehet használni. |
| EVENT_TYPE_ALARM | 4 | Alarm üzenetek típusa esetén. |
| EVENT_TYPE_WAKEUP | 5 | Wakeup esemény típusa. |
| EVENT_TYPE_KEEP_ALIVE | 6 | Keep-alive esemény esetén használható. |

| **Kód azonosító neve** | **Kód azonosító értéke** | **Kód azonosító leírása** |
| --- | --- | --- |
| EVENT_CODE_QUEUE_ERROR | 0 | Sor hiba esetén. |
| EVENT_CODE_NONE | 1 | Amennyiben nincs szükség kódra az eseményhez. |
| EVENT_CODE_IEC_EMETER_DATETIME_SET | 2 | IEC mérő dátum / idő módosításának eseményekor tárolt kód. |
| EVENT_CODE_IEC_REGISTER_READOUT | 3 | IEC mérő regiszter olvasásakor használt kód. |
| EVENT_CODE_IEC_TABLE_READOUT | 4 | IEC mérő tábla olvasásakor használandó kód. |
| EVENT_CODE_IEC_DISPLAY_LIST_READOUT | 5 | IEC mérő display list lekérdezésekor használandó kód. |
| EVENT_CODE_IEC_SERVICE_LIST_READOUT | 6 | IEC mérő service list lekérdezésekor használandó kód. |
| EVENT_CODE_ALARM_LASTGASP_DRAIN | 7 | Scap feszültség a lemerült határérték alá esett. |
| EVENT_CODE_ALARM_LASTGASP_CHARGED | 8 | Scap feszültség a feltöltött határérték felé töltődött. |
| EVENT_CODE_ALARM_INPUT | 9 | Analóg bemenet állapot változásról küldött esemény. |
| EVENT_CODE_ALARM_DINPUT | 10 | Digitális bement állapot változásról küldött esemény. |
| EVENT_CODE_ALARM_GPRS_ENABLE | 11 | PDP context aktiválásakor használandó esemény kód. |
| EVENT_CODE_ALARM_GPRS_DISABLE | 12 | PDP context deaktiválásakor használandó esemény kód. |
| EVENT_CODE_ALARM_EMETER_C860 | 13 | C.86.0 regiszter értékének változása esetén küldött esemény. |
| EVENT_CODE_ALARM_EMETER_C866 | 14 | C.86.6 regiszter értékének változása esetén küldött esemény. |
| EVENT_CODE_ALARM_EMETER_CHANGED | 15 | Riasztás esemény kódja, ha a modemre kötött mérő azonosítója megváltozott. |
| EVENT_CODE_ALARM_DEBUG | 16 | PDP context aktiválást követően küldhető esemény, amennyiben a konfigurációban engedélyezett a funkció. |
| EVENT_CODE_ALARM_SMS_COMMAND_PROCESS | 17 | SMS parancs feldolgozásra küldendő válasz esemény kódja. |
| EVENT_CODE_ALARM_SNMP_TRAP | 18 | SNMP trap küldésekor használt esemény kód. |
| EVENT_CODE_ALARM_2G_FALLBACK | 19 | 2G-re fallback-kelés esetén használt esemény kód. |
| EVENT_CODE_ALARM_MODEM_TEST_MODE | 20 | Transzparens mérő ↔︎ modem kapcsolathoz használt esemény kód. |

#### MESSAGE_EVENT_QUEUE_PUSH_ERROR

Sikertelen esemény sorba tárolás után mentett bejegyzés. Az üzenet formátuma az alábbi:

- "%d %u %u %d" → Hiba kód, Típus azonosító, Kód azonosító, Sorban tárolt elemek száma
| **Hiba kód értéke** | **Hiba kód érték leírása** |
| --- | --- |
| -1 | Hibás sor index. |
| -2 | Az eseménysorba nem lehet több eseményt tárolni, mert tele van. |

| **Típus azonosító neve** | **Típus azonosító értéke** | **Típus azonosító leírása** |
| --- | --- | --- |
| EVENT_TYPE_QUEUE_ERROR | 0 | Sor hiba esetén. |
| EVENT_TYPE_NONE | 1 | Ha nincs szükség típusra, akkor ezt az azonosítót lehet használni. |
| EVENT_TYPE_IEC | 2 | IEC műveletek esetén használatos típus. |
| EVENT_TYPE_PUSH | 3 | Push üzenetek típusnál lehet használni. |
| EVENT_TYPE_ALARM | 4 | Alarm üzenetek típusa esetén. |
| EVENT_TYPE_WAKEUP | 5 | Wakeup esemény típusa. |
| EVENT_TYPE_KEEP_ALIVE | 6 | Keep-alive esemény esetén használható. |

| **Kód azonosító neve** | **Kód azonosító értéke** | **Kód azonosító leírása** |
| --- | --- | --- |
| EVENT_CODE_QUEUE_ERROR | 0 | Sor hiba esetén. |
| EVENT_CODE_NONE | 1 | Amennyiben nincs szükség kódra az eseményhez. |
| EVENT_CODE_IEC_EMETER_DATETIME_SET | 2 | IEC mérő dátum / idő módosításának eseményekor tárolt kód. |
| EVENT_CODE_IEC_REGISTER_READOUT | 3 | IEC mérő regiszter olvasásakor használt kód. |
| EVENT_CODE_IEC_TABLE_READOUT | 4 | IEC mérő tábla olvasásakor használandó kód. |
| EVENT_CODE_IEC_DISPLAY_LIST_READOUT | 5 | IEC mérő display list lekérdezésekor használandó kód. |
| EVENT_CODE_IEC_SERVICE_LIST_READOUT | 6 | IEC mérő service list lekérdezésekor használandó kód. |
| EVENT_CODE_ALARM_LASTGASP_DRAIN | 7 | Scap feszültség a lemerült határérték alá esett. |
| EVENT_CODE_ALARM_LASTGASP_CHARGED | 8 | Scap feszültség a feltöltött határérték felé töltődött. |
| EVENT_CODE_ALARM_INPUT | 9 | Analóg bemenet állapot változásról küldött esemény. |
| EVENT_CODE_ALARM_DINPUT | 10 | Digitális bement állapot változásról küldött esemény. |
| EVENT_CODE_ALARM_GPRS_ENABLE | 11 | PDP context aktiválásakor használandó esemény kód. |
| EVENT_CODE_ALARM_GPRS_DISABLE | 12 | PDP context deaktiválásakor használandó esemény kód. |
| EVENT_CODE_ALARM_EMETER_C860 | 13 | C.86.0 regiszter értékének változása esetén küldött esemény. |
| EVENT_CODE_ALARM_EMETER_C866 | 14 | C.86.6 regiszter értékének változása esetén küldött esemény. |
| EVENT_CODE_ALARM_EMETER_CHANGED | 15 | Riasztás esemény kódja, ha a modemre kötött mérő azonosítója megváltozott. |
| EVENT_CODE_ALARM_DEBUG | 16 | PDP context aktiválást követően küldhető esemény, amennyiben a konfigurációban engedélyezett a funkció. |
| EVENT_CODE_ALARM_SMS_COMMAND_PROCESS | 17 | SMS parancs feldolgozásra küldendő válasz esemény kódja. |
| EVENT_CODE_ALARM_SNMP_TRAP | 18 | SNMP trap küldésekor használt esemény kód. |
| EVENT_CODE_ALARM_2G_FALLBACK | 19 | 2G-re fallback-kelés esetén használt esemény kód. |
| EVENT_CODE_ALARM_MODEM_TEST_MODE | 20 | Transzparens mérő ↔︎ modem kapcsolathoz használt esemény kód. |

#### MESSAGE_EVENT_QUEUE_PULL_OK

Sikeres esemény sorból törlés után mentett bejegyzés. Az üzenet formátuma az alábbi:

- "%d %u %u %d %d" → Törlési index, Típus azonosító, Kód azonosító, Sor index, Sorban tárolt elemek száma
| **Típus azonosító neve** | **Típus azonosító értéke** | **Típus azonosító leírása** |
| --- | --- | --- |
| EVENT_TYPE_QUEUE_ERROR | 0 | Sor hiba esetén. |
| EVENT_TYPE_NONE | 1 | Ha nincs szükség típusra, akkor ezt az azonosítót lehet használni. |
| EVENT_TYPE_IEC | 2 | IEC műveletek esetén használatos típus. |
| EVENT_TYPE_PUSH | 3 | Push üzenetek típusnál lehet használni. |
| EVENT_TYPE_ALARM | 4 | Alarm üzenetek típusa esetén. |
| EVENT_TYPE_WAKEUP | 5 | Wakeup esemény típusa. |
| EVENT_TYPE_KEEP_ALIVE | 6 | Keep-alive esemény esetén használható. |

| **Kód azonosító neve** | **Kód azonosító értéke** | **Kód azonosító leírása** |
| --- | --- | --- |
| EVENT_CODE_QUEUE_ERROR | 0 | Sor hiba esetén. |
| EVENT_CODE_NONE | 1 | Amennyiben nincs szükség kódra az eseményhez. |
| EVENT_CODE_IEC_EMETER_DATETIME_SET | 2 | IEC mérő dátum / idő módosításának eseményekor tárolt kód. |
| EVENT_CODE_IEC_REGISTER_READOUT | 3 | IEC mérő regiszter olvasásakor használt kód. |
| EVENT_CODE_IEC_TABLE_READOUT | 4 | IEC mérő tábla olvasásakor használandó kód. |
| EVENT_CODE_IEC_DISPLAY_LIST_READOUT | 5 | IEC mérő display list lekérdezésekor használandó kód. |
| EVENT_CODE_IEC_SERVICE_LIST_READOUT | 6 | IEC mérő service list lekérdezésekor használandó kód. |
| EVENT_CODE_ALARM_LASTGASP_DRAIN | 7 | Scap feszültség a lemerült határérték alá esett. |
| EVENT_CODE_ALARM_LASTGASP_CHARGED | 8 | Scap feszültség a feltöltött határérték felé töltődött. |
| EVENT_CODE_ALARM_INPUT | 9 | Analóg bemenet állapot változásról küldött esemény. |
| EVENT_CODE_ALARM_DINPUT | 10 | Digitális bement állapot változásról küldött esemény. |
| EVENT_CODE_ALARM_GPRS_ENABLE | 11 | PDP context aktiválásakor használandó esemény kód. |
| EVENT_CODE_ALARM_GPRS_DISABLE | 12 | PDP context deaktiválásakor használandó esemény kód. |
| EVENT_CODE_ALARM_EMETER_C860 | 13 | C.86.0 regiszter értékének változása esetén küldött esemény. |
| EVENT_CODE_ALARM_EMETER_C866 | 14 | C.86.6 regiszter értékének változása esetén küldött esemény. |
| EVENT_CODE_ALARM_EMETER_CHANGED | 15 | Riasztás esemény kódja, ha a modemre kötött mérő azonosítója megváltozott. |
| EVENT_CODE_ALARM_DEBUG | 16 | PDP context aktiválást követően küldhető esemény, amennyiben a konfigurációban engedélyezett a funkció. |
| EVENT_CODE_ALARM_SMS_COMMAND_PROCESS | 17 | SMS parancs feldolgozásra küldendő válasz esemény kódja. |
| EVENT_CODE_ALARM_SNMP_TRAP | 18 | SNMP trap küldésekor használt esemény kód. |
| EVENT_CODE_ALARM_2G_FALLBACK | 19 | 2G-re fallback-kelés esetén használt esemény kód. |
| EVENT_CODE_ALARM_MODEM_TEST_MODE | 20 | Transzparens mérő ↔︎ modem kapcsolathoz használt esemény kód. |

#### MESSAGE_EVENT_QUEUE_PULL_ERROR

Sikertelen esemény sorból törlés után mentett bejegyzés. Az üzenet formátuma az alábbi:

- "%d %d" → Hiba kód, Sor index
| **Hiba kód értéke** | **Hiba kód érték leírása** |
| --- | --- |
| -1 | Hibás sor index. |
| -2 | Az eseménysorba nem lehet eseményt törölni, mert üres. |

### CATEGORY_TRANSPARENT_AT

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_TRANSPARENT_AT_STATUS | 0 | Transzparens AT parancs feldolgozó funkció státusza. |
| MESSAGE_TRANSPARENT_AT_READ | 1 | Fogadott AT parancs válaszról készült bejegyzés. |
| MESSAGE_TRANSPARENT_AT_SEND | 2 | Fogadott AT parancsról készült bejegyzés. |

#### MESSAGE_TRANSPARENT_AT_STATUS

Transzparens AT parancs feldolgozó funkció státusza. Az üzenet formátuma az alábbi:

- "%u" → Transzparens AT státusz
| **Transzparens AT státusz azonosító neve** | **Transzparens AT státusz azonosító értéke** | **Transzparens AT státusz azonosító leírása** |
| --- | --- | --- |
| TRANSPARENT_AT_IDLE | 0 | Várakozó / alapértelmezett állapot. |
| TRANSPARENT_AT_REQ | 1 | Nem használt állapot. |
| TRANSPARENT_AT_IN_PROGR | 2 | AT parancs detektálását követően indított állapot. Ebben az állapotban várakozik a funkció az AT parancs válaszra. |
| TRANSPARENT_AT_FINISH | 3 | Válasz küldést állapota. |

#### MESSAGE_TRANSPARENT_AT_READ

Fogadott AT parancs válaszról készült bejegyzés. Az üzenet formátuma az alábbi:

- "%s" → Transzparens AT parancs válasz
#### MESSAGE_TRANSPARENT_AT_SEND

Fogadott AT parancsról készült bejegyzés. Az üzenet formátuma az alábbi:

- "%s" → Transzparens AT parancs
### CATEGORY_PUSH_SCHEDULER

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_PUSH_SCHEDULER_STATUS | 0 | Push scheduler funkció státusza. |
| MESSAGE_PUSH_SCHEDULER_TYPE | 1 | Push típusról mentett bejegyzés. |
| MESSAGE_PUSH_SCHEDULER_ERROR | 2 | Sor index hiba miatt létrejött esemény. |

#### MESSAGE_PUSH_SCHEDULER_STATUS

Push scheduler funkció státusza. Az üzenet formátuma az alábbi:

- "%u" → Push scheduler státusz
| **Push scheduler státusz azonosító neve** | **Push scheduler státusz azonosító értéke** | **Push scheduler státusz azonosító leírása** |
| --- | --- | --- |
| PUSH_SCHEDULER_STATUS_IDLE | 0 | Várakozó / alapértelmezett állapot. |
| PUSH_SCHEDULER_STATUS_WAIT_PDP_ACTIVE | 1 | PDP context aktiválásra várakozás állapota. |
| PUSH_SCHEDULER_STATUS_WAIT_OTHER_PUSH | 2 | Amennyiben egyéb push folyamatban van, azt meg kell várni. |
| PUSH_SCHEDULER_STATUS_WAIT_PUSH_RESULT | 3 | Várakozás a push végére. |
| PUSH_SCHEDULER_STATUS_WAIT_PDP_DEACTIVE_DELAY | 4 | Ha szükség van a PDP context deaktiválásra, akkor elindítja a firmware a deaktiválási folyamatot. |
| PUSH_SCHEDULER_STATUS_WAIT_PDP_DEACTIVE | 5 | PDP deaktiválási folyamat végére várakozás. |
| PUSH_SCHEDULER_STATUS_FINISH | 6 | Nem használt állapot. |

#### MESSAGE_PUSH_SCHEDULER_TYPE

Push típusról mentett bejegyzés. Az üzenet formátuma az alábbi:

- "%u" → Push típusa
| **Push típus azonosító neve** | **Push típus azonosító értéke** | **Push típus azonosító leírása** |
| --- | --- | --- |
| PUSH_SCHEDULER_NONE | 0 | Alapértelmezett típus azonosító. |
| PUSH_SCHEDULER_ALARM | 1 | Alarm típusú push esemény esetén. |
| PUSH_SCHEDULER_DATA | 2 | Adat típusú push esemény esetén. |

#### MESSAGE_PUSH_SCHEDULER_ERROR

Sor index hiba miatt létrejött esemény. Az üzenet formátuma az alábbi:

- "%u" → Sor index hiba
| **Sor index hiba azonosító neve** | **Sor index hiba azonosító értéke** | **Sor index hiba azonosító leírása** |
| --- | --- | --- |
| PUSH_SCHEDULER_ERROR_QUEUE_IDX | 0 | Sor index hiba. |

### CATEGORY_PING

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_PING_STATUS | 0 | Kimenő ping funkció állapotáról mentett bejegyzés. |
| MESSAGE_PING_RESULT | 1 | Kimenő ping eredményről tárolt esemény. |

#### MESSAGE_PING_STATUS

Kimenő ping funkció állapotáról mentett bejegyzés. Az üzenet formátuma az alábbi:

- "%u" → Ping funkció státusz
| **Ping funkció státusz azonosító neve** | **Ping funkció státusz azonosító értéke** | **Ping funkció státusz azonosító leírása** |
| --- | --- | --- |
| PING_STATUS_IDLE | 0 | Várakozó / alapértelmezett állapot. |
| PING_STATUS_SEND | 1 | Ping küldés állapota. |
| PING_STATUS_RECEIVE | 2 | Pingetés eredmény feldolgozás állapota. |
| PING_STATUS_FINISH | 3 | Ping funkció eredményének kiértékelése történik ebben az állapotban. |

#### MESSAGE_PING_RESULT

Kimenő ping eredményről tárolt esemény. Az üzenet formátuma az alábbi:

- "%u" → Ping funkció végeredménye
| **Ping funkció végeredmény értéke** | **Ping funkció végeredmény leírása** |
| --- | --- |
| -1 | Sikertelen pingetés. A sikertelen pingetések száma meghaladja a paraméterben megadott maximum próbálkozási számot. |
| 1 | Sikeres pingetés. |

### CATEGORY_NTP

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_NTP_STATUS | 0 | NTP szinkronizáció funkciójának állapotáról mentett bejegyzés. |
| MESSAGE_NTP_ERROR | 1 | NTP szinkronizációs hiba esetén tárolt esemény. |
| MESSAGE_NTP_RESULT | 2 | Sikeres dátum / idő szinkronizálás után mentett esemény. |

#### MESSAGE_NTP_STATUS

NTP szinkronizáció funkciójának állapotáról mentett bejegyzés. Az üzenet formátuma az alábbi:

- "%u %u" → Aktuális NTP főstátusz, Aktuális NTP alstátusz
| **Aktuális NTP főstátusz azonosító neve** | **Aktuális NTP főstátusz azonosító értéke** | **Aktuális NTP főstátusz azonosító leírása** |
| --- | --- | --- |
| NTP_STATUS_IDLE | 0 | Várakozó / alapértelmezett állapot. |
| NTP_STATUS_SERVER_SYNC_REQ | 1 | Nem használt állapot. |
| NTP_STATUS_SERVER_SYNC_IN_PROGR | 2 | NTP szinkronizáció folyamatban állapot. |
| NTP_STATUS_SERVER_SYNC_FINISH | 3 | NTP szinkronizáció vége állapot. |
| NTP_STATUS_SET_EMETER_TIME_REQ | 4 | Nem használt állapot. |
| NTP_STATUS_SET_EMETER_TIME_IN_PROGR | 5 | Nem használt állapot. |

| **Aktuális NTP alstátusz azonosító neve** | **Aktuális NTP alstátusz azonosító értéke** | **Aktuális NTP alstátusz azonosító leírása** |
| --- | --- | --- |
| NTP_SYNCH_CONNECT | 0 | NTP szinkronizációhoz szükséges kimenő UDP socket konfiguráció és megnyitása. |
| NTP_SYNCH_CONNECT_RESULT | 1 | NTP szinkronizációhoz szükséges kimenő UDP socket nyitás állapota. |
| NTP_SYNCH_SEND_DATA | 2 | NTP szinkronizációs kérés csomag küldése. |
| NTP_SYNCH_RECEIVE_DATA | 3 | NTP szinkronizáció kérésre kapott válasz olvasása. |
| NTP_SYNCH_DATA_PROCESS | 4 | NTP szinkronizációs csomagok feldolgozása. |
| NTP_SYNCH_DISCONNECT | 5 | UDP socket zárása. |
| NTP_SYNCH_ERROR | 6 | NTP szinkronizációs hiba esetén lép ebbe az állapotba a firmware. Amennyiben még van próbálkozási lehetőség, akkor új szinkronizáció indítása. |

#### MESSAGE_NTP_ERROR

NTP szinkronizációs hiba esetén tárolt esemény. Az üzenet formátuma az alábbi:

- "%u" → NTP hiba állapot
| **NTP hiba állapot azonosító neve** | **NTP hiba állapot azonosító értéke** | **NTP hiba állapot azonosító leírása** |
| --- | --- | --- |
| NTP_SYNCH_ERROR_CONFIG | 0 | NTP szinkronizációs konfiguráció hibás. (IP / host cím nincs bekonfigurálva) |
| NTP_SYNCH_ERROR_SOCKET_CONNECT | 1 | UDP socket kapcsolat kiépítési hiba esetén tárolt bejegyzés. |
| NTP_SYNCH_ERROR_SOCKET_CONNECT_TIMEOUT | 2 | UDP socket kapcsolat kiépítés időtúllépés miatt nem lehetséges. |
| NTP_SYNCH_ERROR_SOCKET_STATUS | 3 | UDP socket státusz állapota nem megfelelő. |
| NTP_SYNCH_ERROR_SOCKET_DISCONNECT | 4 | Nem használt hiba állapot. |
| NTP_SYNCH_ERROR_SOCKET_WRITE | 5 | UDP socketre írás hibával tér vissza. |
| NTP_SYNCH_ERROR_SOCKET_READ | 6 | UDP socketről olvasás hibával tér vissza. |
| NTP_SYNCH_ERROR_TIMESTAMP_MISMATCH | 7 | Az NTP szinkronizációs csomagban szereplő dátum / idő nem egyezik meg a válaszban kapott dátum / idővel. |
| NTP_SYNCH_ERROR_OFFSET_OR_RT_DELAY | 8 | Offset vagy round-trip hiba esetén. |
| NTP_SYNCH_ERROR_SOCKET_ERROR | 9 | Socket státusz olvasáskor hibát jelez vissza a modul. |
| NTP_SYNCH_ERROR_SOCKET_RECEIVE_TIMEOUT | 10 | Az NTP szinkronizációs csomagra nem érkezett időben válasz. |

#### MESSAGE_NTP_RESULT

Sikeres dátum / idő szinkronizálás után mentett esemény. Az üzenet formátuma az alábbi:

- "%02u.%02u.%02u. %02u:%02u:%02u" → Dátum és idő.
### CATEGORY_TCP

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_TCP_STATUS | 0 | TCP push fő- és alstátusz állapotáról tárolt bejegyzések. |
| MESSAGE_TCP_TYPE | 1 | TCP push típusáról tárolt bejegyzés. |
| MESSAGE_TCP_ERROR | 2 | TCP push alatt előforduló hibákról tárolt bejegyzések. |
| MESSAGE_TCP_RESULT | 3 | Sikeres TCP push után tárolt esemény. |

#### MESSAGE_TCP_STATUS

TCP push fő- és alstátusz állapotáról tárolt bejegyzések. Az üzenet formátuma az alábbi:

- "%u %u" → Aktuális TCP főstátusz, Aktuális TCP alstátusz
| **Aktuális TCP push főstátusz azonosító neve** | **Aktuális TCP push főstátusz azonosító értéke** | **Aktuális TCP push főstátusz azonosító leírása** |
| --- | --- | --- |
| TCP_PUSH_IDLE | 0 | Várakozó / alapértelmezett állapot. |
| TCP_PUSH_REQUEST | 1 | Amennyiben TCP push igény detektálható, akkor a beállítások validációját ebben az állapotban történik. |
| TCP_PUSH_IN_PROGRESS | 2 | TCP push folyamatban állapot. |
| TCP_PUSH_FINISH | 3 | TCP push befejeződött állapot. |

| **Aktuális TCP push alstátusz azonosító neve** | **Aktuális TCP push alstátusz azonosító értéke** | **Aktuális TCP push alstátusz azonosító leírása** |
| --- | --- | --- |
| TCP_PUSH_CONNECT | 0 | TCP push-hoz szükséges kimenő TCP socket konfiguráció és megnyitása. |
| TCP_PUSH_CONNECT_RESULT | 1 | TCP push-hoz szükséges kimenő TCP socket nyitás állapota. |
| TCP_PUSH_SEND_DATA | 2 | TCP push adatküldés állapota. |
| TCP_PUSH_DISCONNECT | 3 | TCP push kimenő TCP socket zárása. |
| TCP_PUSH_ERROR | 4 | A push alatt fellépő, valamilyen hiba esetén ebbe az állapotba lép az eszköz. |

#### MESSAGE_TCP_TYPE

TCP push típusáról tárolt bejegyzés. Az üzenet formátuma az alábbi:

- "%u" → Push esemény típusa.
| **Típus azonosító neve** | **Típus azonosító értéke** | **Típus azonosító leírása** |
| --- | --- | --- |
| EVENT_TYPE_PUSH | 3 | Adatküldés esetén használt típusa. |
| EVENT_TYPE_ALARM | 4 | Minden kiküldendő alarm típusú. Pl. Lastgasp, |

#### MESSAGE_TCP_ERROR

TCP push alatt előforduló hibákról tárolt bejegyzések. Az üzenet formátuma az alábbi:

- "%u" → Push alatt előforduló hiba azonosító
| **TCP push hiba állapot azonosító neve** | **TCP push hiba állapot azonosító értéke** | **TCP push hiba állapot azonosító leírása** |
| --- | --- | --- |
| TCP_PUSH_ERROR_CONFIG | 0 | TCP push konfiguráció hibás. (IP / host cím nincs bekonfigurálva) |
| TCP_PUSH_ERROR_SOCKET_CONNECT | 1 | TCP socket kapcsolat kiépítési hiba esetén tárolt bejegyzés. |
| TCP_PUSH_ERROR_SOCKET_CONNECT_TIMEOUT | 2 | TCP socket kapcsolat kiépítés időtúllépés miatt nem lehetséges. |
| TCP_PUSH_ERROR_SOCKET_STATUS | 3 | TCP socket státusz állapota nem megfelelő. |
| TCP_PUSH_ERROR_SOCKET_DISCONNECT | 4 | TCP socket zárása alatt fellépő hiba. |
| TCP_PUSH_ERROR_SOCKET_WRITE | 5 | TCP socketre írás hibával tér vissza. |
| TCP_PUSH_ERROR_SOCKET_ERROR | 6 | TCP socket nyitás alatt fellépő egyéb hiba. |

#### MESSAGE_TCP_RESULT

Sikeres TCP push után tárolt esemény. A bejegyzésnek nincs speciális értéke.

### CATEGORY_UDP

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_UDP_STATUS | 0 | UDP push fő- és alstátusz állapotáról tárolt bejegyzések. |
| MESSAGE_UDP_TYPE | 1 | UDP push típusáról tárolt bejegyzés. |
| MESSAGE_UDP_ERROR | 2 | UDP push alatt előforduló hibákról tárolt bejegyzések. |
| MESSAGE_UDP_RESULT | 3 | Sikeres UDP push után tárolt esemény. |

#### MESSAGE_UDP_STATUS

UDP push fő- és alstátusz állapotáról tárolt bejegyzések. Az üzenet formátuma az alábbi:

- "%u %u" → Aktuális NTP főstátusz, Aktuális NTP alstátusz
| **Aktuális UDP push főstátusz azonosító neve** | **Aktuális UDP push főstátusz azonosító értéke** | **Aktuális UDP push főstátusz azonosító leírása** |
| --- | --- | --- |
| UDP_PUSH_IDLE | 0 | Várakozó / alapértelmezett állapot. |
| UDP_PUSH_REQUEST | 1 | Amennyiben UDP push igény detektálható, akkor a beállítások validációját ebben az állapotban történik. |
| UDP_PUSH_IN_PROGRESS | 2 | UDP push folyamatban állapot. |
| UDP_PUSH_FINISH | 3 | UDP push befejeződött állapot. |

| **Aktuális UDP push alstátusz azonosító neve** | **Aktuális UDP push alstátusz azonosító értéke** | **Aktuális UDP push alstátusz azonosító leírása** |
| --- | --- | --- |
| UDP_PUSH_CONNECT | 0 | UDP push-hoz szükséges kimenő UDP socket konfiguráció és megnyitása. |
| UDP_PUSH_CONNECT_RESULT | 1 | UDP push-hoz szükséges kimenő UDP socket nyitás állapota. |
| UDP_PUSH_SEND_DATA | 2 | UDP push adatküldés állapota. |
| UDP_PUSH_DISCONNECT | 3 | UDP push kimenő UDP socket zárása. |
| UDP_PUSH_ERROR | 4 | A push alatt fellépő, valamilyen hiba esetén ebbe az állapotba lép az eszköz. |

#### MESSAGE_UDP_TYPE

UDP push típusáról tárolt bejegyzés. Az üzenet formátuma az alábbi:

- "%u" → Push esemény típusa.
| **Típus azonosító neve** | **Típus azonosító értéke** | **Típus azonosító leírása** |
| --- | --- | --- |
| EVENT_TYPE_PUSH | 3 | Adatküldés esetén használt típusa. |
| EVENT_TYPE_ALARM | 4 | Minden kiküldendő alarm típusú. Pl. Lastgasp |

#### MESSAGE_UDP_ERROR

UDP push alatt előforduló hibákról tárolt bejegyzések. Az üzenet formátuma az alábbi:

- "%u" → Push alatt előforduló hiba azonosító
| **UDP push hiba állapot azonosító neve** | **UDP push hiba állapot azonosító értéke** | **UDP push hiba állapot azonosító leírása** |
| --- | --- | --- |
| UDP_PUSH_ERROR_CONFIG | 0 | UDP push konfiguráció hibás. (IP / host cím nincs bekonfigurálva) |
| UDP_PUSH_ERROR_SOCKET_CONNECT | 1 | UDP socket kapcsolat kiépítési hiba esetén tárolt bejegyzés. |
| UDP_PUSH_ERROR_SOCKET_CONNECT_TIMEOUT | 2 | UDP socket kapcsolat kiépítés időtúllépés miatt nem lehetséges. |
| UDP_PUSH_ERROR_SOCKET_STATUS | 3 | UDP socket státusz állapota nem megfelelő. |
| UDP_PUSH_ERROR_SOCKET_DISCONNECT | 4 | UDP socket zárása alatt fellépő hiba. |
| UDP_PUSH_ERROR_SOCKET_WRITE | 5 | UDP socketre írás hibával tér vissza. |
| UDP_PUSH_ERROR_SOCKET_ERROR | 6 | UDP socket nyitás alatt fellépő egyéb hiba. |

#### MESSAGE_UDP_RESULT

Sikeres UDP push után tárolt esemény. A bejegyzésnek nincs speciális értéke.

### CATEGORY_FTP

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_FTP_STATUS | 0 | FTP push fő- és alstátusz állapotáról tárolt bejegyzések. |
| MESSAGE_FTP_TYPE | 1 | FTP push típusáról tárolt bejegyzés. |
| MESSAGE_FTP_ERROR | 2 | FTP push alatt előforduló hibákról tárolt bejegyzések. |
| MESSAGE_FTP_COMMAND_ERROR | 3 | FTP parancs hiba esetén tárolt esemény. |
| MESSAGE_FTP_RESULT | 4 | Sikeres FTP push után tárolt esemény. |

#### MESSAGE_FTP_STATUS

FTP push fő- és alstátusz állapotáról tárolt bejegyzések. Az üzenet formátuma az alábbi:

- "%u %u" → Aktuális FTP főstátusz, Aktuális FTP alstátusz
| **Aktuális FTP push főstátusz azonosító neve** | **Aktuális FTP push főstátusz azonosító értéke** | **Aktuális FTP push főstátusz azonosító leírása** |
| --- | --- | --- |
| FTP_PUSH_IDLE | 0 | Várakozó / alapértelmezett állapot. |
| FTP_PUSH_REQUEST | 1 | Amennyiben TCP push igény detektálható, akkor a beállítások validációját ebben az állapotban történik. |
| FTP_PUSH_IN_PROGRESS | 2 | TCP push folyamatban állapot. |
| FTP_PUSH_FINISH | 3 | TCP push befejeződött állapot. |

| **Aktuális TCP push alstátusz azonosító neve** | **Aktuális TCP push alstátusz azonosító értéke** | **Aktuális TCP push alstátusz azonosító leírása** |
| --- | --- | --- |
| FTP_PUSH_OPEN | 0 | A modem konfigurációjában beállított értékek alapján TCP socket kapcsolat megnyitása. |
| FTP_PUSH_WELCOME_RESULT | 1 | FTP szerver üdvözlő üzenet feldolgozó állapot. |
| FTP_PUSH_SET_USERNAME | 2 | Felhasználónév FTP parancs küldése. |
| FTP_PUSH_SET_USERNAME_RESULT | 3 | Felhasználónév FTP parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_SET_PASSWORD | 4 | Felhasználói jelszó FTP parancs küldése. |
| FTP_PUSH_SET_PASSWORD_RESULT | 5 | Felhasználói jelszó FTP parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_OPEN_DIRECTORY | 6 | Konfigurációban beállított elérési út beállító parancs küldése. |
| FTP_PUSH_OPEN_DIRECTORY_RESULT | 7 | Elérési út parancsra adott válasz feldolgozása. Amennyiben több mappa van az elérési útban, akkor rekurzívan be tud lépni almappába a firmware. |
| FTP_PUSH_CREATE_DIRECTORY | 8 | Könyvtár létrehozó FTP parancs állapota, amennyiben erre szükség van. |
| FTP_PUSH_CREATE_DIRECTORY_RESULT | 9 | Könyvtár létrehozó FTP parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_CHANGE_FILE_TYPE | 10 | Tárolandó fájl típusának kiválasztása, ebben az FTP parancsban kerül beállításra. |
| FTP_PUSH_CHANGE_FILE_TYPE_RESULT | 11 | Típus beállító parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_SET_PASSIVE_MODE | 12 | Konfiguráció függően, amennyiben passzív FTP kapcsolatra van szükség, akkor a passzív mód FTP parancs. |
| FTP_PUSH_SET_PASSIVE_MODE_RESULT | 13 | Passzív mód FTP parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_OPEN_DATA_SOCKET | 14 | Adat TCP socket konfigurációs és megnyitó parancs. |
| FTP_PUSH_SET_PORT | 15 | Aktív FTP push esetén a listener socket port küldése parancs. |
| FTP_PUSH_SET_PORT_RESULT | 16 | Port beállító parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_CREATE_FILE | 17 | Fájlnév létrehozó FTP parancs állapot. |
| FTP_PUSH_CREATE_FILE_RESULT | 18 | Fájlnév létrehozó FTP parancs válasz feldolgozó állapot. |
| FTP_PUSH_WAIT_DATA_SOCKET | 19 | Adat socket állapot ellenőrző állapot. Addig várakozik ebben az állapotban a firmware, amíg az adat socket állapota a megfelelő állapotba nem kerül. |
| FTP_PUSH_WAIT_DATA_SOCKET_TIMEOUT | 20 | Ha a beállított időn belül nem sikerül az adat socket-et megnyitni, akkor ebbe az állapotba lép az FTP push. |
| FTP_PUSH_WAIT_DATA_SOCKET_TIMEOUT_RESULT | 21 | Ha lehetséges újrapróbálni az adat socket megnyitást, akkor ebben az állapotban tudjuk újra leindítani a csatlakozási kísérletet. |
| FTP_PUSH_SEND_FILE | 22 | Fájl küldés alatt ebben az állapotban várakozik a firmware. |
| FTP_PUSH_CLOSE_DATA_SOCKET | 23 | Adat socket bezárás állapota. |
| FTP_PUSH_SEND_FILE_RESULT | 24 | Adat socket bezárását követően a fájl küldésről kapott válasz feldolgozó állapota. |
| FTP_PUSH_RENAME_FROM | 25 | Átnevezendő fájl ellenőrző FTP parancs állapota. |
| FTP_PUSH_RENAME_FROM_RESULT | 26 | Átnevezendő fájl ellenőrző FTP parancsra adott válasz feldolgozó állapota. |
| FTP_PUSH_RENAME_TO | 27 | Átnevező FTP parancs állapot. |
| FTP_PUSH_RENAME_TO_RESULT | 28 | Átnevezés eredmény feldolgozó állapot. |
| FTP_PUSH_QUIT | 29 | FTP push lezáró parancs állapot. |
| FTP_PUSH_QUIT_RESULT | 30 | FTP push lezáró parancs válasz feldolgozó állapot. |
| FTP_PUSH_WAIT_ANSWER | 31 | Amennyiben várakozni kell, akkor ebben az állapotban állítja be a firmware a várakozás maximális hosszát. |
| FTP_PUSH_WAIT_ANSWER_RESULT | 32 | Várakozás végén a következő állapotba lép a firmware. |
| FTP_PUSH_ERROR | 33 | Az FTP push alatt fellépő hiba esetén lép ebbe az állapotba a firmware. |

#### MESSAGE_FTP_TYPE

FTP push típusáról tárolt bejegyzés. Az üzenet formátuma az alábbi:

- "%u" → Push esemény típusa.
| **Típus azonosító neve** | **Típus azonosító értéke** | **Típus azonosító leírása** |
| --- | --- | --- |
| EVENT_TYPE_PUSH | 3 | Adatküldés esetén használt típusa. |
| EVENT_TYPE_ALARM | 4 | Minden kiküldendő alarm típusú. Pl. Lastgasp |

#### MESSAGE_FTP_ERROR

FTP push alatt előforduló hibákról tárolt bejegyzések. Az üzenet formátuma az alábbi:

- "%u" → Push alatt előforduló hiba azonosító
- "%u %u" → Aktuális FTP alstátusz, Push alatt előforduló hiba azonosító
| **Aktuális TCP push alstátusz azonosító neve** | **Aktuális TCP push alstátusz azonosító értéke** | **Aktuális TCP push alstátusz azonosító leírása** |
| --- | --- | --- |
| FTP_PUSH_OPEN | 0 | A modem konfigurációjában beállított értékek alapján TCP socket kapcsolat megnyitása. |
| FTP_PUSH_WELCOME_RESULT | 1 | FTP szerver üdvözlő üzenet feldolgozó állapot. |
| FTP_PUSH_SET_USERNAME | 2 | Felhasználónév FTP parancs küldése. |
| FTP_PUSH_SET_USERNAME_RESULT | 3 | Felhasználónév FTP parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_SET_PASSWORD | 4 | Felhasználói jelszó FTP parancs küldése. |
| FTP_PUSH_SET_PASSWORD_RESULT | 5 | Felhasználói jelszó FTP parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_OPEN_DIRECTORY | 6 | Konfigurációban beállított elérési út beállító parancs küldése. |
| FTP_PUSH_OPEN_DIRECTORY_RESULT | 7 | Elérési út parancsra adott válasz feldolgozása. Amennyiben több mappa van az elérési útban, akkor rekurzívan be tud lépni almappába a firmware. |
| FTP_PUSH_CREATE_DIRECTORY | 8 | Könyvtár létrehozó FTP parancs állapota, amennyiben erre szükség van. |
| FTP_PUSH_CREATE_DIRECTORY_RESULT | 9 | Könyvtár létrehozó FTP parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_CHANGE_FILE_TYPE | 10 | Tárolandó fájl típusának kiválasztása, ebben az FTP parancsban kerül beállításra. |
| FTP_PUSH_CHANGE_FILE_TYPE_RESULT | 11 | Típus beállító parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_SET_PASSIVE_MODE | 12 | Konfiguráció függően, amennyiben passzív FTP kapcsolatra van szükség, akkor a passzív mód FTP parancs. |
| FTP_PUSH_SET_PASSIVE_MODE_RESULT | 13 | Passzív mód FTP parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_OPEN_DATA_SOCKET | 14 | Adat TCP socket konfigurációs és megnyitó parancs. |
| FTP_PUSH_SET_PORT | 15 | Aktív FTP push esetén a listener socket port küldése parancs. |
| FTP_PUSH_SET_PORT_RESULT | 16 | Port beállító parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_CREATE_FILE | 17 | Fájlnév létrehozó FTP parancs állapot. |
| FTP_PUSH_CREATE_FILE_RESULT | 18 | Fájlnév létrehozó FTP parancs válasz feldolgozó állapot. |
| FTP_PUSH_WAIT_DATA_SOCKET | 19 | Adat socket állapot ellenőrző állapot. Addig várakozik ebben az állapotban a firmware, amíg az adat socket állapota a megfelelő állapotba nem kerül. |
| FTP_PUSH_WAIT_DATA_SOCKET_TIMEOUT | 20 | Ha a beállított időn belül nem sikerül az adat socket-et megnyitni, akkor ebbe az állapotba lép az FTP push. |
| FTP_PUSH_WAIT_DATA_SOCKET_TIMEOUT_RESULT | 21 | Ha lehetséges újrapróbálni az adat socket megnyitást, akkor ebben az állapotban tudjuk újra leindítani a csatlakozási kísérletet. |
| FTP_PUSH_SEND_FILE | 22 | Fájl küldés alatt ebben az állapotban várakozik a firmware. |
| FTP_PUSH_CLOSE_DATA_SOCKET | 23 | Adat socket bezárás állapota. |
| FTP_PUSH_SEND_FILE_RESULT | 24 | Adat socket bezárását követően a fájl küldésről kapott válasz feldolgozó állapota. |
| FTP_PUSH_RENAME_FROM | 25 | Átnevezendő fájl ellenőrző FTP parancs állapota. |
| FTP_PUSH_RENAME_FROM_RESULT | 26 | Átnevezendő fájl ellenőrző FTP parancsra adott válasz feldolgozó állapota. |
| FTP_PUSH_RENAME_TO | 27 | Átnevező FTP parancs állapot. |
| FTP_PUSH_RENAME_TO_RESULT | 28 | Átnevezés eredmény feldolgozó állapot. |
| FTP_PUSH_QUIT | 29 | FTP push lezáró parancs állapot. |
| FTP_PUSH_QUIT_RESULT | 30 | FTP push lezáró parancs válasz feldolgozó állapot. |
| FTP_PUSH_WAIT_ANSWER | 31 | Amennyiben várakozni kell, akkor ebben az állapotban állítja be a firmware a várakozás maximális hosszát. |
| FTP_PUSH_WAIT_ANSWER_RESULT | 32 | Várakozás végén a következő állapotba lép a firmware. |
| FTP_PUSH_ERROR | 33 | Az FTP push alatt fellépő hiba esetén lép ebbe az állapotba a firmware. |

| **FTP push hiba állapot azonosító neve** | **FTP push hiba állapot azonosító értéke** | **FTP push hiba állapot azonosító leírása** |
| --- | --- | --- |
| FTP_PUSH_ERROR_CONFIG | 0 | FTP push konfiguráció hibás. (IP / host cím nincs bekonfigurálva) |
| FTP_PUSH_ERROR_SOCKET_CONNECT | 1 | FTP socket kapcsolat kiépítési hiba esetén tárolt bejegyzés. |
| FTP_PUSH_ERROR_SOCKET_CONNECT_TIMEOUT | 2 | FTP socket kapcsolat kiépítés időtúllépés miatt nem lehetséges. |
| FTP_PUSH_ERROR_SOCKET_STATUS | 3 | FTP socket státusz állapota nem megfelelő. |
| FTP_PUSH_ERROR_SOCKET_DISCONNECT | 4 | FTP socket zárása alatt fellépő hiba. |
| FTP_PUSH_ERROR_SOCKET_WRITE | 5 | FTP socketre írás hibával tér vissza. |
| FTP_PUSH_ERROR_SOCKET_ERROR | 6 | FTP socket nyitás alatt fellépő egyéb hiba. |
| FTP_PUSH_ERROR_TIMEOUT | 7 | FTP push hibával ért véget. |

#### MESSAGE_FTP_COMMAND_ERROR

FTP parancs hiba esetén tárolt esemény. Az üzenet formátuma az alábbi:

- "%u %d" → Aktuális FTP alstátusz, FTP parancs hiba értéke
| **Aktuális TCP push alstátusz azonosító neve** | **Aktuális TCP push alstátusz azonosító értéke** | **Aktuális TCP push alstátusz azonosító leírása** |
| --- | --- | --- |
| FTP_PUSH_OPEN | 0 | A modem konfigurációjában beállított értékek alapján TCP socket kapcsolat megnyitása. |
| FTP_PUSH_WELCOME_RESULT | 1 | FTP szerver üdvözlő üzenet feldolgozó állapot. |
| FTP_PUSH_SET_USERNAME | 2 | Felhasználónév FTP parancs küldése. |
| FTP_PUSH_SET_USERNAME_RESULT | 3 | Felhasználónév FTP parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_SET_PASSWORD | 4 | Felhasználói jelszó FTP parancs küldése. |
| FTP_PUSH_SET_PASSWORD_RESULT | 5 | Felhasználói jelszó FTP parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_OPEN_DIRECTORY | 6 | Konfigurációban beállított elérési út beállító parancs küldése. |
| FTP_PUSH_OPEN_DIRECTORY_RESULT | 7 | Elérési út parancsra adott válasz feldolgozása. Amennyiben több mappa van az elérési útban, akkor rekurzívan be tud lépni almappába a firmware. |
| FTP_PUSH_CREATE_DIRECTORY | 8 | Könyvtár létrehozó FTP parancs állapota, amennyiben erre szükség van. |
| FTP_PUSH_CREATE_DIRECTORY_RESULT | 9 | Könyvtár létrehozó FTP parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_CHANGE_FILE_TYPE | 10 | Tárolandó fájl típusának kiválasztása, ebben az FTP parancsban kerül beállításra. |
| FTP_PUSH_CHANGE_FILE_TYPE_RESULT | 11 | Típus beállító parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_SET_PASSIVE_MODE | 12 | Konfiguráció függően, amennyiben passzív FTP kapcsolatra van szükség, akkor a passzív mód FTP parancs. |
| FTP_PUSH_SET_PASSIVE_MODE_RESULT | 13 | Passzív mód FTP parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_OPEN_DATA_SOCKET | 14 | Adat TCP socket konfigurációs és megnyitó parancs. |
| FTP_PUSH_SET_PORT | 15 | Aktív FTP push esetén a listener socket port küldése parancs. |
| FTP_PUSH_SET_PORT_RESULT | 16 | Port beállító parancsra adott válasz feldolgozó állapot. |
| FTP_PUSH_CREATE_FILE | 17 | Fájlnév létrehozó FTP parancs állapot. |
| FTP_PUSH_CREATE_FILE_RESULT | 18 | Fájlnév létrehozó FTP parancs válasz feldolgozó állapot. |
| FTP_PUSH_WAIT_DATA_SOCKET | 19 | Adat socket állapot ellenőrző állapot. Addig várakozik ebben az állapotban a firmware, amíg az adat socket állapota a megfelelő állapotba nem kerül. |
| FTP_PUSH_WAIT_DATA_SOCKET_TIMEOUT | 20 | Ha a beállított időn belül nem sikerül az adat socket-et megnyitni, akkor ebbe az állapotba lép az FTP push. |
| FTP_PUSH_WAIT_DATA_SOCKET_TIMEOUT_RESULT | 21 | Ha lehetséges újrapróbálni az adat socket megnyitást, akkor ebben az állapotban tudjuk újra leindítani a csatlakozási kísérletet. |
| FTP_PUSH_SEND_FILE | 22 | Fájl küldés alatt ebben az állapotban várakozik a firmware. |
| FTP_PUSH_CLOSE_DATA_SOCKET | 23 | Adat socket bezárás állapota. |
| FTP_PUSH_SEND_FILE_RESULT | 24 | Adat socket bezárását követően a fájl küldésről kapott válasz feldolgozó állapota. |
| FTP_PUSH_RENAME_FROM | 25 | Átnevezendő fájl ellenőrző FTP parancs állapota. |
| FTP_PUSH_RENAME_FROM_RESULT | 26 | Átnevezendő fájl ellenőrző FTP parancsra adott válasz feldolgozó állapota. |
| FTP_PUSH_RENAME_TO | 27 | Átnevező FTP parancs állapot. |
| FTP_PUSH_RENAME_TO_RESULT | 28 | Átnevezés eredmény feldolgozó állapot. |
| FTP_PUSH_QUIT | 29 | FTP push lezáró parancs állapot. |
| FTP_PUSH_QUIT_RESULT | 30 | FTP push lezáró parancs válasz feldolgozó állapot. |
| FTP_PUSH_WAIT_ANSWER | 31 | Amennyiben várakozni kell, akkor ebben az állapotban állítja be a firmware a várakozás maximális hosszát. |
| FTP_PUSH_WAIT_ANSWER_RESULT | 32 | Várakozás végén a következő állapotba lép a firmware. |
| FTP_PUSH_ERROR | 33 | Az FTP push alatt fellépő hiba esetén lép ebbe az állapotba a firmware. |

#### MESSAGE_FTP_RESULT

Sikeres FTP push után tárolt esemény. A bejegyzésnek nincs speciális értéke.

### CATEGORY_EI

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_EI_STATUS | 0 | EI kliens funkció fő- és alállapotáról tárolt bejegyzések. |
| MESSAGE_EI_TYPE | 1 | EI kliens autentikációs protokoll típusáról tárolt bejegyzés. |
| MESSAGE_EI_ERROR | 2 | EI kliens kommunikáció alatt előforduló hibákról tárolt bejegyzések. |
| MESSAGE_EI_RESULT | 3 | Nem használt üzenet. |

#### MESSAGE_EI_STATUS

EI kliens funkció fő- és alállapotáról tárolt bejegyzések. Az üzenet formátuma az alábbi:

- "%u %u" → Aktuális EI kliens főstátusz, Aktuális EI kliens alstátusz
| **Aktuális EI kliens főstátusz azonosító neve** | **Aktuális EI kliens főstátusz azonosító értéke** | **Aktuális EI kliens push főstátusz azonosító leírása** |
| --- | --- | --- |
| EI_STATUS_IDLE | 0 | Várakozó / alapértelmezett állapot, melyben ellenőrzi a firmware, hogy az EI kliens konfiguráció érvényes-e. |
| EI_STATUS_IN_PROGRESS | 1 | Amennyiben EI kliens konfigurációja megfelelő, akkor a funkció ebben az állapotban van folyamatosan, amíg van kommunikáció a mérő és a HES között. |
| EI_STATUS_FINISHED | 2 | EI kliens komminukáció végén. |

| **Aktuális EI kliens push alstátusz azonosító neve** | **Aktuális EI kliens alstátusz azonosító értéke** | **Aktuális EI kliens alstátusz azonosító leírása** |
| --- | --- | --- |
| EI_CLIENT_CONNECT | 0 | EI klienshez szükséges kimenő TCP socket konfiguráció és megnyitása. |
| EI_CLIENT_CONNECT_RESULT | 1 | EI klienshez szükséges kimenő TCP socket nyitás állapota. |
| EI_CLIENT_AUTENTICATION | 2 | Amennyiben a konfigurációban olyan protokoll van beállítva, amihez autentikáció szükséges, akkor az autentikációs parancs ebben az állapotban kerül kiküldésre. |
| EI_CLIENT_AUTENTICATION_CHECK | 3 | Autentikáció eredményének ellenrző állapota. |
| EI_CLIENT_WAIT_IPT_REQUEST | 4 | IPT protokoll esetén, a HES-től érkező kérésekre itt várakozik a firmware. |
| EI_CLIENT_SEND_AND_RECEIVE_DATA | 5 | Transzparens adatküldés állapota. |
| EI_CLIENT_DISCONNECT_IPT_REQUEST | 6 | IPT protokoll esetén, a HES-től kapcsolatbontás kérés érkezett és erre kell válaszolnia a modemnek. Ezt követően a EI_CLIENT_WAIT_IPT_REQUEST állapotba lép vissza a firmware. |
| EI_CLIENT_DISCONNECT | 7 | Hiba, vagy a távoli fél által történt bontást követő állapot. |

#### MESSAGE_EI_TYPE

EI kliens autentikációs protokoll típusáról tárolt bejegyzés. Az üzenet formátuma az alábbi:

- "%c" → EI kliens típusa
| **EI kliens típus értéke** | **EI kliens típus leírása** |
| --- | --- |
| E | EI kliens felhasználónév és jelszóval történő autentikációja. Amennyiben a fent említett adatok helyesek, a HES <ACK> választ küld. |
| I | IPT protokollnak megfelelő autentikációs típus. |
| \0 | EI kliens sima transzparens csatorna. |

#### MESSAGE_EI_ERROR

EI kliens kommunikáció alatt előforduló hibákról tárolt bejegyzések. Az üzenet formátuma az alábbi:

- "%u" → EI kliens hiba azonosító
| **EI kliens hiba azonosító neve** | **EI kliens hiba azonosító értéke** | **EI kliens hiba azonosító leírása** |
| --- | --- | --- |
| EI_CLIENT_ERROR_CONFIG | 0 | EI kliens konfiguráció hibás. (IP nincs bekonfigurálva vagy hibás) |
| EI_CLIENT_ERROR_SOCKET_CONNECT | 1 | EI kliens socket kapcsolat kiépítési hiba esetén tárolt bejegyzés. |
| EI_CLIENT_ERROR_SOCKET_CONNECT_TIMEOUT | 2 | EI kliens socket kapcsolat kiépítés időtúllépés miatt nem lehetséges. |
| EI_CLIENT_ERROR_SOCKET_STATUS | 3 | EI kliens socket státusz állapota nem megfelelő. |
| EI_CLIENT_ERROR_SOCKET_DISCONNECT | 4 | EI kliens socket zárása alatt fellépő hiba. |
| EI_CLIENT_ERROR_SOCKET_WRITE | 5 | EI kliens socketre írás hibával tér vissza. |
| EI_CLIENT_ERROR_SOCKET_READ | 6 | EI kliens socketről olvasás hibával tér vissza. |
| EI_CLIENT_ERROR_SOCKET_ERROR | 7 | EI kliens push hibával ért véget. |
| EI_CLIENT_ERROR_TIMEOUT | 8 | EI kliens autentikációs időtúllépés esetén. |
| EI_CLIENT_ERROR_PROTOCOL | 9 | EI kliens autentikációs hiba esetén. |

### CATEGORY_IEC

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_IEC_MESSAGE | 0 | IEC üzenet kód azonosítójának tárolása. |
| MESSAGE_IEC_ERROR | 1 | IEC folyamat alatt fellépő hiba esetén tárolt esemény. |
| MESSAGE_IEC_RESULT | 2 | IEC művelet eredményéről tárolt bejegyzés. |

#### MESSAGE_IEC_MESSAGE

IEC üzenet kód azonosítójának tárolása. Az üzenet formátuma az alábbi:

- "%u" → IEC kód azonosító
| **IEC kód azonosító neve** | **IEC kód azonosító értéke** | **IEC kód azonosító leírása** |
| --- | --- | --- |
| EVENT_CODE_IEC_EMETER_DATETIME_SET | 2 | IEC mérő dátum / idő módosításának eseményekor tárolt kód. |
| EVENT_CODE_IEC_REGISTER_READOUT | 3 | IEC mérő regiszter olvasásakor használt kód. |
| EVENT_CODE_IEC_TABLE_READOUT | 4 | IEC mérő tábla olvasásakor használandó kód. |
| EVENT_CODE_IEC_DISPLAY_LIST_READOUT | 5 | IEC mérő display list lekérdezésekor használandó kód. |
| EVENT_CODE_IEC_SERVICE_LIST_READOUT | 6 | IEC mérő service list lekérdezésekor használandó kód. |

#### MESSAGE_IEC_ERROR

IEC folyamat alatt fellépő hiba esetén tárolt esemény. Az üzenet formátuma az alábbi:

- "%u" → IEC folyamat hiba kódja
| **IEC hibakód azonosító neve** | **IEC hibakód azonosító értéke** | **IEC hibakód azonosító leírása** |
| --- | --- | --- |
| IEC_ERROR_TABLE_READOUT | 0 | IEC táblaolvasás során fellépő hiba esetén: ·BCC hiba. ·Tábla olvasási hiba elérte a maximális próbálkozás számot. |
| IEC_ERROR_LIST_READOUT | 1 | Service / display list olvasás közben fellépő hiba: ·BCC hiba. |
| IEC_ERROR_TIMEOUT | 2 | Nem használt hiba eset. |

#### MESSAGE_IEC_RESULT

IEC művelet eredményéről tárolt bejegyzés. Az üzenet formátuma az alábbi:

- "%u" → IEC kód azonosító
| **IEC kód azonosító neve** | **IEC kód azonosító értéke** | **IEC kód azonosító leírása** |
| --- | --- | --- |
| EVENT_CODE_IEC_EMETER_DATETIME_SET | 2 | IEC mérő dátum / idő módosításának eseményekor tárolt kód. |
| EVENT_CODE_IEC_REGISTER_READOUT | 3 | IEC mérő regiszter olvasásakor használt kód. |
| EVENT_CODE_IEC_TABLE_READOUT | 4 | IEC mérő tábla olvasásakor használandó kód. |
| EVENT_CODE_IEC_DISPLAY_LIST_READOUT | 5 | IEC mérő display list lekérdezésekor használandó kód. |
| EVENT_CODE_IEC_SERVICE_LIST_READOUT | 6 | IEC mérő service list lekérdezésekor használandó kód. |

### CATEGORY_C86X

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_C86X_CHANGE | 0 | C.86.X regiszter érték változás esetén tárolt esemény. |

#### MESSAGE_C86X_CHANGE

C.86.X regiszter érték változás esetén tárolt esemény. Az üzenet formátuma az alábbi:

- "%u %s" → C.86.X regiszter index, C.86.X regiszter érték
| **C.86.X regiszter neve** | **C.86.X regiszter index** |
| --- | --- |
| C.86.0 | 0 |
| C.86.6 | 1 |

### CATEGORY_WAKEUP

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_WAKEUP_STATUS | 0 | Wakeup esemény állapotgép státusz változásról tárolt esemény. |

#### MESSAGE_WAKEUP_STATUS

Wakeup esemény állapotgép státusz változásról tárolt esemény. Az üzenet formátuma az alábbi:

- "%u" → Wakeup státusz
| **Wakeup státusz******azonosító neve**** | **Wakeup státusz azonosító értéke** | **Wakeup státusz azonosító leírása** |
| --- | --- | --- |
| WAKEUP_STATUS_IDLE | 0 | Várakozó / alapértelmezett állapot. |
| WAKEUP_STATUS_REQUEST | 1 | Wakeup kérelem esetén ebbe az állapotba lép az állapotgép. |
| WAKEUP_STATUS_PDP_ATTACH | 2 | PDP context aktiválást indítása zajlik ebben az állapotban. |
| WAKEUP_STATUS_PDP_ATTACH_WAIT | 3 | Várakozó állapot, hogy a PDP context aktiválása befejeződjön. |
| WAKEUP_STATUS_PDP_DETACH_WAIT | 4 | Várakozó állapot, hogy a PDP context deaktiválást detektálja a firmware. |

### CATEGORY_DM

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_DM_STATUS | 0 | DM push funkció fő- és alállapotáról tárolt bejegyzések. |
| MESSAGE_DM_ERROR | 1 | DM push alatt fellépő hibákról tárolt esemény. |
| MESSAGE_DM_RESULT | 2 | DM push eredményről tárolt bejegyzés. |

#### MESSAGE_DM_STATUS

DM push funkció fő- és alállapotáról tárolt bejegyzések. Az üzenet formátuma az alábbi:

- "%u %u" → Aktuális DM push főstátusz, Aktuális DM push alstátusz
| **Aktuális DM push főstátusz azonosító neve** | **Aktuális DM push főstátusz azonosító értéke** | **Aktuális DM push főstátusz azonosító leírása** |
| --- | --- | --- |
| DM_PUSH_IDLE | 0 | Várakozó / alapértelmezett állapot. Amennyiben DM push igény detektálható, akkor a beállítások validációja. |
| DM_PUSH_IN_PROGRESS | 1 | DM push folyamatban állapot. |
| DM_PUSH_FINISH | 2 | Következő DM push időzítésének beállítása, és a push vége. |

| **Aktuális TCP push alstátusz azonosító neve** | **Aktuális TCP push alstátusz azonosító értéke** | **Aktuális TCP push alstátusz azonosító leírása** |
| --- | --- | --- |
| DM_PUSH_CONNECT | 0 | DM push-hoz szükséges kimenő TCP socket konfiguráció és megnyitása. |
| DM_PUSH_CONNECT_RESULT | 1 | DM push-hoz szükséges kimenő TCP socket nyitás állapota. |
| DM_PUSH_SEND_DATA | 2 | DM push adatküldés állapota. |
| DM_PUSH_DISCONNECT | 3 | DM push kimenő TCP socket zárása. |

#### MESSAGE_DM_ERROR

DM push alatt fellépő hibákról tárolt esemény. Az üzenet formátuma az alábbi:

- "%u" → Push alatt előforduló hiba azonosító
| **DM push hiba állapot azonosító neve** | **DM push hiba állapot azonosító értéke** | **DM push hiba állapot azonosító leírása** |
| --- | --- | --- |
| DM_PUSH_ERROR_CONFIG | 0 | DM push konfiguráció hibás. (IP / host cím nincs bekonfigurálva) |
| DM_PUSH_ERROR_SOCKET_CONNECT | 1 | TCP socket kapcsolat kiépítési hiba esetén tárolt bejegyzés. |
| DM_PUSH_ERROR_SOCKET_CONNECT_TIMEOUT | 2 | TCP socket kapcsolat kiépítés időtúllépés miatt nem lehetséges. |
| DM_PUSH_ERROR_SOCKET_STATUS | 3 | TCP socket státusz állapota nem megfelelő. |
| DM_PUSH_ERROR_SOCKET_DISCONNECT | 4 | TCP socket zárása alatt fellépő hiba. |
| DM_PUSH_ERROR_SOCKET_WRITE | 5 | TCP socketre írás hibával tér vissza. |
| DM_PUSH_ERROR_SOCKET_ERROR | 6 | TCP socket nyitás alatt fellépő egyéb hiba. |

#### MESSAGE_DM_RESULT

DM push eredményről tárolt bejegyzés. A bejegyzésnek nincs speciális értéke.

### CATEGORY_INPUT

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_INPUT_CHANGE | 0 | Analóg / digitális bemenet állapot változásáról tárolt esemény. |

#### MESSAGE_INPUT_CHANGE

Analóg bemenet állapot változásáról tárolt esemény. Az üzenet formátuma az alábbi:

- "%u" → Input állapot ((((bemenet index + 1) << 4) | analóg állapot)
| **Bemenet index** | **Bemenet azonosító** |
| --- | --- |
| 0 | 1 |
| 1 | 2 |

| **Analóg bemenet állapot azonosító neve** | **Analóg bemenet állapot azonosító értéke** | **Analóg bemenet állapot azonosító leírása** |
| --- | --- | --- |
| INPUT_STATE_QUIESCENT_I | 0 | Inaktív bemenet állapot. |
| INPUT_STATE_ACTIVE_I | 1 | Aktív bemenet állapot. |
| INPUT_STATE_SABOTAGE_I | 2 | Szabotázs állapot. |
| INPUT_STATE_NOT_DETERMINED_I | 3 | Definiálatlan állapot. |

Digitális bemenet állapot változásáról tárolt esemény. Az üzenet formátuma az alábbi:

- "%u" → Input állapot ((bemenet típus << 6) | ((bemenet index) << 4)) | digitális állapot)
| **Bemenet típus azonosító neve** | **Bemenet típus állapot azonosító értéke** | **Bemenet típus állapot azonosító leírása** |
| --- | --- | --- |
| DIN | 0 | Digitális bemenet |
| TAMPER | 1 | Tamper bemenet. |

| **Bemenet index** | **Bemenet azonosító** |
| --- | --- |
| 1 | 1 |
| 2 | 2 |

| **Digitális bemenet állapot azonosító neve** | **Digitális bemenet állapot azonosító értéke** | **Digitális bemenet állapot azonosító leírása** |
| --- | --- | --- |
| INPUT_STATE_LOW | 0 | Logikai alacsony bemenet állapot. |
| INPUT_STATE_HIGH | 1 | Logikai magas bemenet állapot. |

### CATEGORY_CI

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_CI_STATUS | 0 | Customer interface lista olvasás állapotáról mentett bejegyzés. |
| MESSAGE_CI_ERROR | 1 | CI folyamat alatt fellépő hibáról tárolt esemény. |
| MESSAGE_CI_RESULT | 2 | Sikeres CI művelet végén tárolt bejegyzés. |

#### MESSAGE_CI_STATUS

Customer interface lista olvasás állapotáról mentett bejegyzés. Az üzenet formátuma az alábbi:

- "%u %u" → IEC kód azonosító, Aktuális CI státusz
| **IEC kód azonosító neve** | **IEC kód azonosító értéke** | **IEC kód azonosító leírása** |
| --- | --- | --- |
| EVENT_CODE_IEC_DISPLAY_LIST_READOUT | 5 | IEC mérő display list lekérdezésekor használandó kód. |
| EVENT_CODE_IEC_SERVICE_LIST_READOUT | 6 | IEC mérő service list lekérdezésekor használandó kód. |

| **Aktuális CI státusz azonosító neve** | **Aktuális CI státusz azonosító értéke** | **Aktuális CI státusz azonosító leírása** |
| --- | --- | --- |
| CI_LIST_READ | 0 | IEC mérő service /display list lekérdezés állapota. |
| CI_LIST_READOUT_PROCESS | 1 | IEC mérőről kiolvasott service / display list feldolgozásának állapota. |
| CI_LIST_WRITE | 2 | Feldolgozott adat küldése CI interfészre. |

#### MESSAGE_CI_ERROR

CI folyamat alatt fellépő hibáról tárolt esemény. Az üzenet formátuma az alábbi:

- "%u %u" → IEC kód azonosító, Aktuális CI státusz
| **IEC kód azonosító neve** | **IEC kód azonosító értéke** | **IEC kód azonosító leírása** |
| --- | --- | --- |
| EVENT_CODE_IEC_DISPLAY_LIST_READOUT | 5 | IEC mérő display list lekérdezésekor használandó kód. |
| EVENT_CODE_IEC_SERVICE_LIST_READOUT | 6 | IEC mérő service list lekérdezésekor használandó kód. |

| **Aktuális CI státusz azonosító neve** | **Aktuális CI státusz azonosító értéke** | **Aktuális CI státusz azonosító leírása** |
| --- | --- | --- |
| CI_LIST_READ | 0 | IEC mérő service /display list lekérdezés állapota. |
| CI_LIST_READOUT_PROCESS | 1 | IEC mérőről kiolvasott service / display list feldolgozásának állapota. |
| CI_LIST_WRITE | 2 | Feldolgozott adat küldése CI interfészre. |

#### MESSAGE_CI_RESULT

Sikeres CI művelet végén tárolt bejegyzés. Az üzenet formátuma az alábbi:

- "%u” → IEC kód azonosító
| **IEC kód azonosító neve** | **IEC kód azonosító értéke** | **IEC kód azonosító leírása** |
| --- | --- | --- |
| EVENT_CODE_IEC_DISPLAY_LIST_READOUT | 5 | IEC mérő display list lekérdezésekor használandó kód. |
| EVENT_CODE_IEC_SERVICE_LIST_READOUT | 6 | IEC mérő service list lekérdezésekor használandó kód. |

### CATEGORY_SNMP

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_SNMP_TRAP | 0 | SNMP trap alarm esemény küldés után tárolt bejegyzés. |

#### MESSAGE_SNMP_TRAP

SNMP trap alarm esemény küldés után tárolt bejegyzés. A bejegyzésnek nincs speciális értéke.

### CATEGORY_TLS

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_TLS_SERVER_STATUS | 0 | TLS szerver socket állapotáról tárolt bejegyzés. |
| MESSAGE_TLS_SERVER_ERROR | 1 | TLS szerver socketen fellépő hibákról mentett esemény. |

#### MESSAGE_TLS_SERVER_STATUS

TLS szerver socket állapotáról tárolt bejegyzés. Az üzenet formátuma az alábbi:

- "%u %u" → TLS szerver socket index, Aktuális TLS szerver állapot
| **TLS szerver socket index azonosító neve** | **TLS szerver socket index azonosító értéke** | **TLS szerver socket index azonosító leírása** |
| --- | --- | --- |
| SOCKET_SERVER_SRV_CH1 | 0 | Utility sockethez tartozó index. |
| SOCKET_SERVER_SRV_CH2 | 1 | Felhasználó sockethez tartozó index. |

| **Aktuális TLS szerver állapot azonosító neve** | **Aktuális TLS szerver állapot azonosító értéke** | **Aktuális TLS szerver állapot azonosító leírása** |
| --- | --- | --- |
| TLS_SERVER_INIT | 0 | TLS szerver inicializáló állapot. |
| TLS_SERVER_DEINIT | 1 | TLS szerver deinicializálás állapota. |
| TLS_SERVER_CONNECT | 2 | TLS szerver socket bejövő kapcsolat fogadása állapot. |
| TLS_SERVER_DISCONNECT_GRACEFULLY | 3 | Peer által normálisan bezárt socket kapcsolat. |
| TLS_SERVER_DISCONNECT_PEER | 4 | Peer által hiba miatt bezárt socket kapcsolat. |
| TLS_SERVER_ERROR | 5 | Nem használt állapot. |

#### MESSAGE_TLS_SERVER_ERROR

TLS szerver socketen fellépő hibákról mentett esemény. Az üzenet formátuma az alábbi:

- "%u %u" → TLS szerver socket index, Aktuális TLS szerver állapot
- "%u %u %d" → TLS szerver socket index, TLS_SERVER_ERROR, Hiba kód
| **TLS szerver socket index azonosító neve** | **TLS szerver socket index azonosító értéke** | **TLS szerver socket index azonosító leírása** |
| --- | --- | --- |
| SOCKET_SERVER_SRV_CH1 | 0 | Utility sockethez tartozó index. |
| SOCKET_SERVER_SRV_CH2 | 1 | Felhasználó sockethez tartozó index. |

| **Aktuális TLS szerver állapot azonosító neve** | **Aktuális TLS szerver állapot azonosító értéke** | **Aktuális TLS szerver állapot azonosító leírása** |
| --- | --- | --- |
| TLS_SERVER_INIT | 0 | TLS szerver inicializáló állapot. |
| TLS_SERVER_CONNECT | 2 | TLS szerver socket bejövő kapcsolat fogadása állapot. |
| TLS_SERVER_ERROR | 5 | Nem használt állapot. |

### CATEGORY_INTERFACE

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_INTERFACE_STATUS | 0 | Interfész ki / bemenő adatfolyam módosításról tárolt bejegyzés. |

#### MESSAGE_INTERFACE_STATUS

Interfész ki / bemenő adatfolyam módosításról tárolt bejegyzés. Az üzenet formátuma az alábbi:

- "%u 0x%08X 0x%08X" → Interfész azonosító, Interfész kimeneti adatfolyam azonosító, Interfész bemeneti adatfolyam azonosító
| **Interfész azonosító neve** | **Interfész azonosító értéke** | **Interfész azonosító leírása** |
| --- | --- | --- |
| LOCAL_CONFIG_ID | 0 | Lokál interfész. |
| EXTENSION_ID | 1 | Kiegészítő panelhez tartozó interfész. |
| EMETER_ID | 2 | Emeterhez tartozó interfész. |
| CLO_ID | 3 | Current loop interfész. |
| CI_ID | 4 | Customer interfész. |
| MODEM_ID_SERVER_SRV_CH1 | 5 | Szerver socket 1. csatorna interfésze. |
| MODEM_ID_SERVER_SRV_CH2 | 6 | Szerver socket 2. csatorna interfésze. |
| MODEM_ID_SERVER_SRV_CH3 | 7 | Szerver socket 3. csatorna interfésze. |
| MODEM_ID_SERVER_SRV_TLS_DEC_CH1 | 8 | TLS szerver socket 1. csatorna titkosított adatok visszafejtésére használt interfész. |
| MODEM_ID_SERVER_SRV_TLS_DEC_CH2 | 9 | TLS szerver socket 2. csatorna titkosított adatok visszafejtésére használt interfész. |
| MODEM_ID_SERVER_SRV_TLS_ENC_CH1 | 10 | TLS szerver socket 1. csatorna adatok titkosítására használt interfész. |
| MODEM_ID_SERVER_SRV_TLS_ENC_CH2 | 11 | TLS szerver socket 2. csatorna adatok titkosítására használt interfész. |
| TRANSPARENT_AT_ID | 12 | Transzparens AT funkció interfésze. |
| IEC_ID | 13 | IEC funkció interfésze. |
| EI_ID | 14 | EI kliens interfésze. |

| **Interfész kimeneti / bemeneti adatfolyam azonosító neve** | **Interfész kimeneti / bemeneti adatfolyam azonosító értéke** | **Interfész kimeneti / bemeneti adatfolyam azonosító leírása** |
| --- | --- | --- |
| DATAFLOW_NONE | 0x00000000 | Nem használt interfész. |
| DATAFLOW_CONFIG | 0x00000001 | Konfigurációs interfész. |
| DATAFLOW_EMETER | 0x00000002 | Emeter interfész. |
| DATAFLOW_MODEM_TCP_SRV_A | 0x00000004 | Utility socket interfész. |
| DATAFLOW_MODEM_TCP_SRV_B | 0x00000008 | Customer interfész. |
| DATAFLOW_LOCAL_CONFIG | 0x00000010 | Lokál konfigurációs interfész. |
| DATAFLOW_CLO | 0x00000020 | Current loop interfész. |
| DATAFLOW_TRANSPARENT_AT | 0x00000040 | Transzparens AT funkció interfésze. |
| DATAFLOW_IEC_INT_CTRL | 0x00000080 | IEC mérőolvasó funkció interfésze. |
| DATAFLOW_SNMP | 0x00000100 | SNMP funkció interfésze. |
| DATAFLOW_MODEM_CSD | 0x00000200 | CSD funkció interfésze. |
| DATAFLOW_EXTENSION | 0x00000400 | Kiegészítő panel interfésze. |
| DATAFLOW_MODEM_EI_CLIENT | 0x00000800 | EI kliens funkció transzparens interfésze. |
| DATAFLOW_MODEM_EI_CLIENT_PREPROCESS | 0x00001000 | EI kliens protokoll előfeldolgozó interfésze. |
| DATAFLOW_MODEM_EI_CLIENT_POSTPROCESS | 0x00002000 | EI kliens protokoll utófeldolgozó interfésze. |
| DATAFLOW_MODEM_TCP_SRV_C | 0x00004000 | Másodlagos utility socket interfésze. |
| DATAFLOW_MODEM_TCP_SRV_TLS_ENCRYPTED_A | 0x00008000 | Utility socket titkosított adat tároló interfésze. |
| DATAFLOW_MODEM_TCP_SRV_TLS_DECRYPTED_A | 0x00010000 | Utility socket titkosított adat visszafejtést követő adattároló interfésze. |
| DATAFLOW_MODEM_TCP_SRV_TLS_ENCRYPTED_B | 0x00020000 | Customer socket titkosított adat tároló interfésze. |
| DATAFLOW_MODEM_TCP_SRV_TLS_DECRYPTED_B | 0x00040000 | Customer socket titkosított adat visszafejtést követő adattároló interfésze. |

## Firmware paraméterek

A fejlesztői és felhasználói rendszerüzenetek külön paraméterekkel teljesen testreszabhatóak. Mind a kategória, mind az üzenet típusok külön szűrővel állíthatóak.

| **Paraméter neve** | **Paraméter alapértelmezett értéke** | **Paraméter leírása** |
| --- | --- | --- |
| syslog.category_id_filter | 105398939 | Fejlesztői napló kategória szűrő. |
| syslog.message_id_filter | 65535.31.0.8191.255.0.0.15.0.1.0.0.0.0.7.0.0.0.0.7.0.0.7.0.0.1.3.0.0.0.0.0 | Fejlesztői napló üzenet típus szűrő. |
| user_syslog.category_id_filter | 105398939 | Felhasználói napló kategória szűrő. |
| user_syslog.message_id_filter | 65535.30.0.8191.255.0.0.15.0.1.0.0.0.0.4.0.0.0.0.4.0.0.7.0.0.1.2.0.0.0.0.0 | Felhasználói napló üzenet típus szűrő. |

A kategória szűrő paraméterek egy 4 bájtos paraméter, melynek minden bitje egy egy kategóriát jelöl. Értelemszerűen, ha az adott bit 1, akkor a kategóriába tartozó üzenet típusokról tud a firmware bejegyzéseket menteni.

| **Bit index** | **Kategória neve** |
| --- | --- |
| 0 | CATEGORY_DEVICE |
| 1 | CATEGORY_FW_UPDATE |
| 2 | CATEGORY_AT |
| 3 | CATEGORY_GSM |
| 4 | CATEGORY_PDP |
| 5 | CATEGORY_CSD |
| 6 | CATEGORY_SMS |
| 7 | CATEGORY_SOCKET |
| 8 | CATEGORY_RTC |
| 9 | CATEGORY_LASTGASP |
| 10 | CATEGORY_EVENT_QUEUE |
| 11 | CATEGORY_TRANSPARENT_AT |
| 12 | CATEGORY_PUSH_SCHEDULER |
| 13 | CATEGORY_PING |
| 14 | CATEGORY_NTP |
| 15 | CATEGORY_TCP |
| 16 | CATEGORY_UDP |
| 17 | CATEGORY_FTP |
| 18 | CATEGORY_EI |
| 19 | CATEGORY_IEC |
| 20 | CATEGORY_C86X |
| 21 | CATEGORY_WAKEUP |
| 22 | CATEGORY_DM |
| 23 | CATEGORY_INPUT |
| 24 | CATEGORY_CI |
| 25 | CATEGORY_SNMP |
| 26 | CATEGORY_TLS |
| 27 | CATEGORY_INTERFACE |

Az üzenet típus szűrő paraméter egy 16 bites tömb elemekből álló tömb, mely 32 elemből áll. Minden tömbelem a tömb indexének megfelelő kategóriának az üzenet típusainak szűrője. A fent említett alapértelmezett értékek alapján egy példa:

- syslog.category_id_filter → 105398939d → 0110010010000100001010011011b
Tehát a CATEGORY_DEVICE bit indexen az érték 1, így a CATEGORY_DEVICE alá tartozó üzenettípusok engedélyezve vannak.

- syslog.message_id_filter → 65535.31.0.8191.255.0.0.15.0.1.0.0.0.0.7.0.0.0.0.7.0.0.7.0.0.1.3.0.0.0.0.0
A tömb első eleme 65535d, ahogy ezt fent már említettem, ez azt jelenti, hogy a CATEGORY_DEVICE kategóriához tartozó üzenet típusok szűrőjét lehet ezzel az elemmel állítani. A 65535d → 1111111111111111b ami azt jelenti, hogy a CATEGORY_DEVICE kategórián belül mindegyik üzenet típus engedélyezve van:

| **Üzenet neve** | **Üzenet azonosító** | **Üzenet leírása** |
| --- | --- | --- |
| MESSAGE_DEVICE_SYSLOG_CLEAR | 0 | WM-ETerm-ből lehetőség van a syslog bejegyzéseket tartozó területeket törölni. A törlést követően ez az üzenet kerül bejegyzésre. |
| MESSAGE_DEVICE_POWER_UP | 1 | A firmware indulása után létrehozott bejegyzés. A bejegyzésben a firmware verzió és a hardver verzió kerül tárolásra. Pl.: 5.3.45.0, 1 |
| MESSAGE_DEVICE_FW_RESTART_UPDATE | 2 | Firmware frissítés / modul indulási hiba utáni bejegyzés. A bejegyzésben tárolásra kerül az eredmény. |
| MESSAGE_DEVICE_FW_RESTART_CONFIG | 3 | Sikeres / Sikertelen konfiguráció utáni újraindulásról mentett bejegyzés. |
| MESSAGE_DEVICE_FW_RESTART_SCHEDULE | 4 | Periódikus / idő alapú újraindulás után. |
| MESSAGE_DEVICE_FW_RESTART_WAKEUP | 5 | SMS-ből kiadott újraindítási parancs után. |
| MESSAGE_DEVICE_FW_RESTART_MODEM | 6 | Nem implementált üzenet. |
| MESSAGE_DEVICE_ERROR_WDG | 7 | Amennyiben valamelyik RTOS task megáll, akkor watchdog újraindulás lesz. |
| MESSAGE_DEVICE_ERROR_OVERFLOW | 8 | Interfész buffer túlcsordulás esetén tárolt bejegyzés. |
| MESSAGE_DEVICE_ERROR_CONFIG | 9 | Hibás konfiguráció / works betöltés esetén. |
| MESSAGE_DEVICE_ERROR_MODEM | 10 | Egy percig folyamatos modem hálózati státusz hiba esetén. |
| MESSAGE_DEVICE_ERROR_INIT | 11 | Modul bekapcsolási szekvencia hiba esetén. |
| MESSAGE_DEVICE_CONFIG_START | 12 | Konfigurációs művelet indulását követően. |
| MESSAGE_DEVICE_CONFIG_END_OK | 13 | Konfigurációs művelet sikeres befejezését követően tárolt bejegyzés. |
| MESSAGE_DEVICE_CONFIG_END_ERROR | 14 | Konfigurációs művelet sikertelen befejezését követően tárolt bejegyzés. |
| MESSAGE_DEVICE_CONFIG_OPERATION | 15 | Konfigurációs művelet típusának tárolása. |

## WM-ETerm

### WM-ETerm-es konfiguráció

Az alábbi képeken látható a már fent említett paraméterek WM-ETerm-es implementációja.

![](Syslog.fld/image001.png)

![](Syslog.fld/image002.png)![](Syslog.fld/image003.png)

A lenyíló menüben lehet beállítani, hogy milyen üzenet típusokra és kategóriákra szeretnénk szűrni, fontos, hogy a bepipált értékeket tudja a firmware onnantól kezdve menteni. A módosítás hatására a korábban tárolt bejegyzések nem fognak módosulni.

### WM-ETerm napló műveletek

A “Tools“ menü alatt elérhető a rendszer és a felhasználói napló menü.

![](Syslog.fld/image004.png)

Mindkét napló esetén a funkciók megegyeznek, így nincs értelme mindkét verzióról képet bevágni. Az elérhető jelenlegi funkciók:

- Egész napló kiolvasása.
![](Syslog.fld/image005.png)

- N csomag napló bejegyzés kiolvasása.
![](Syslog.fld/image006.png)

- Napló bejegyzések mentése.
![](Syslog.fld/image007.png)

![](Syslog.fld/image008.png)

- Napló bejegyzések törlése.
![](Syslog.fld/image009.png)
