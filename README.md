# vagrant-ansible-flask-lab

![Status](https://img.shields.io/badge/Status-Klar-brightgreen)
![VMs](https://img.shields.io/badge/VMs-5-blue)
![Tester](https://img.shields.io/badge/Tester-18%2F18%20PASS-brightgreen)
![Ansible](https://img.shields.io/badge/Ansible-2.10-red)
![Vagrant](https://img.shields.io/badge/Vagrant-2.4-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-orange)

> En automatiserad infrastruktur med en lastbalanserad Flask-webbapplikation driftsatt på två separata VMs via Ansible, med en isolerad PostgreSQL-databasserver. Hela miljön provisioneras från en dedikerad kontrollnod.

Föreställ dig att du ska sätta upp fem servrar på ett företag. Traditionellt tar det dagar och massor av manuellt arbete. Det här projektet gör allt automatiskt med ett enda kommando.

**Vad du får när projektet är klart:**

- En webbapplikation lastbalanserad mellan två servrar
- En isolerad databasserver som bara applikationsservrarna når
- Automatisk säkerhetshärdning på alla servrar
- 18 automatiserade tester som bevisar att allt fungerar

**Tid att sätta upp:** ca 20–30 minuter

**Författare:** Sushanta Shekhar Modak och Farhad Norman  
**Kurs:** Virtualiseringsteknik och automation, YH Enköping

---

## Innehållsförteckning

| Nr | Sektion |
|----|---------|
| 1 | [Vad är verktygen?](#vad-är-verktygen) |
| 2 | [Arkitektur](#arkitektur) |
| 3 | [Krav](#krav) |
| 4 | [Steg-för-steg installation](#steg-för-steg-installation) |
| 5 | [Säkerhetsåtgärder](#säkerhetsåtgärder) |
| 6 | [Säkerhetsanalys STRIDE](#säkerhetsanalys-stride) |
| 7 | [Verifiering](#verifiering) |
| 8 | [Designval och motivering](#designval-och-motivering) |
| 9 | [Felsökning](#felsökning) |
| 10 | [Ordlista](#ordlista) |

---

## Vad är verktygen?

> Hoppa gärna förbi det här om du redan vet vad verktygen gör. Alla tekniska begrepp förklaras i [Ordlistan](#ordlista).

### VirtualBox — din dator i datorn

VirtualBox låter dig skapa virtuella datorer inuti din riktiga dator. Tänk dig att du har fem laptops inuti din laptop — var och en med eget operativsystem, eget nätverk och egna program.

Vi använder VirtualBox för att skapa fem virtuella Ubuntu-servrar som pratar med varandra via ett privat nätverk.

### Vagrant — automatisk skapare av virtuella datorer

Istället för att klicka ihop virtuella datorer manuellt i VirtualBox beskriver du dem i en textfil som heter `Vagrantfile`. Vagrant läser filen och skapar allt automatiskt.

**Analogin:** Vagrant är som ett recept. VirtualBox är köket. Du följer receptet och får samma rätt varje gång.

|               | Utan Vagrant              | Med Vagrant                    |
|---------------|---------------------------|--------------------------------|
| Tid           | 45 min manuellt per server | `vagrant up` — klart på 15 min |
| Repeterbarhet | Olika varje gång           | Identiskt varje gång           |
| Felsökning    | Börja om manuellt          | `vagrant destroy && vagrant up` |

Det här kallas [IaC (Infrastructure as Code)](#iac--infrastructure-as-code).

### Ansible — automatisk serverkonfigurerare

När dina virtuella datorer är skapade behöver de konfigureras. Ansible gör det automatiskt via [SSH](#ssh--secure-shell). Du skriver vad du vill ha, och Ansible räknar ut hur det ska göras på alla servrar samtidigt. Det kallas [idempotens](#idempotens).

Ansible organiserar arbetet i [roller](#roll-ansible-role) och [playbooks](#playbook).

**Analogin:** Ansible är som en servicetekniker med en checklista. Du ger hen checklistan, hen fixar allt på alla maskiner.

|        | Utan Ansible                   | Med Ansible      |
|--------|--------------------------------|------------------|
| Metod  | Logga in på 5 servrar manuellt | Ett kommando     |
| Tid    | Timmar                         | 5 minuter        |
| Risk   | Lätt att missa något           | Alltid identiskt |

### Flask — webbapplikationen

Flask är ett minimalt Python-webbramverk. Vår applikation tar emot webbförfrågningar, hämtar data från databasen och svarar tillbaka.

**Vår app har tre endpoints:**

| Endpoint | Vad den gör |
|----------|-------------|
| `/`      | Returnerar `Hello from web1!` eller `Hello from web2!` |
| `/health` | Returnerar `status: ok` — används av nginx för hälsocheck |
| `/info`  | Returnerar JSON med databas-status och tidsstämpel |

### Gunicorn — produktionswebbservern

Flask har en inbyggd webbserver men den är bara för utveckling. Gunicorn är en riktig produktionsserver som hanterar många användare samtidigt. Vi kör Gunicorn som en [systemd-tjänst](#systemd).

|                     | Flasks dev-server    | Gunicorn               |
|---------------------|----------------------|------------------------|
| Användare samtidigt | 1                    | Många (flera workers)  |
| Felmeddelanden      | Visas i webbläsaren  | Loggas internt         |
| Vid krasch          | Stannar nere         | Startar om automatiskt |
| Lämpar sig för      | Utveckling           | Produktion             |

**Analogin:** Flasks dev-server är en hemmasnickrad pall. Gunicorn är stolen som tål att stå i ett kafé hela dagen.

### nginx — lastbalanseraren

nginx (uttalas *engine-x*) fungerar som en trafikpolis för webbtrafik.

- **Som lastbalanserare:** nginx tar emot all trafik utifrån och bestämmer vilken server som ska svara via [round-robin](#round-robin).
- **Som omvänd proxy:** nginx tar emot förfrågningar på port 80 och skickar dem vidare till Flask på port 5000. Användaren ser aldrig Flask direkt.

nginx-konfigurationen genereras automatiskt från en [Jinja2-template](#jinja2) — vilket betyder att du kan lägga till fler servrar utan att ändra nginx-koden.

**Analogin:** Tänk på nginx som receptionen på ett sjukhus. Alla patienter går in genom receptionen. Receptionen bestämmer vilken läkare som tar nästa patient.

### PostgreSQL — databasen

PostgreSQL är en relationsdatabas där vår applikation sparar och hämtar data. Den körs på en helt separat server och är bara nåbar från web1 och web2 — inte från omvärlden.

---

## Arkitektur

### Systemdiagram

```
Windows-laptop (host)
        |
        | Port 8080 (port forwarding)
        |
┌───────▼──────────────────────────────────────────┐
│         Privat nätverk 192.168.56.0/24            │
│                                                   │
│  ┌──────────────┐                                 │
│  │   control    │  Ansible kör härifrån           │
│  │   .10        │  via SSH-nycklar                │
│  └──────┬───────┘                                 │
│         │ provisionerar                           │
│         ▼                                         │
│  ┌──────────────┐                                 │
│  │   nginx      │  ◄── inkommande HTTP            │
│  │   .11        │                                 │
│  └──────┬───────┘                                 │
│         │ round-robin                             │
│    ┌────┴────┐                                    │
│    ▼         ▼                                    │
│  ┌──────┐  ┌──────┐                               │
│  │ web1 │  │ web2 │  Flask + Gunicorn             │
│  │ .12  │  │ .13  │                               │
│  └──┬───┘  └──┬───┘                               │
│     └────┬────┘                                   │
│          ▼                                        │
│  ┌──────────────┐                                 │
│  │  database    │  PostgreSQL                     │
│  │   .14        │  UFW: bara web1, web2           │
│  └──────────────┘                                 │
└──────────────────────────────────────────────────┘
```

### IP-adresser och resurser

| VM         | Roll               | IP-adress      | Port forwarding       | RAM    |
|------------|--------------------|----------------|-----------------------|--------|
| `control`  | Ansible-kontroll   | 192.168.56.10  | —                     | 512 MB |
| `nginx`    | Lastbalanserare    | 192.168.56.11  | `:80 → host:8080`     | 512 MB |
| `web1`     | Flask + Gunicorn   | 192.168.56.12  | —                     | 512 MB |
| `web2`     | Flask + Gunicorn   | 192.168.56.13  | —                     | 512 MB |
| `database` | PostgreSQL         | 192.168.56.14  | —                     | 768 MB |

Totalt RAM: ca 3 GB. Du behöver minst 8 GB RAM.

### Säkerhetsdesignen förklarad

**Varför har bara nginx port forwarding?**  
web1, web2 och database är helt osynliga utifrån. En angripare kan nå nginx — men inte databasen direkt.

**Varför får inte nginx prata med databasen?**  
UFW på databasservern tillåter bara anslutningar från web1 (.12) och web2 (.13). Nginx (.11) blockeras helt. Det kallas [nätverkssegmentering](#nätverkssegmentering).

**Varför kör vi Ansible från control-VM?**  
Om du kör Ansible från laptopen ligger SSH-nycklarna på samma dator där du surfar. Control-VM är en separat säkerhetsdomän — minimal och dedikerad.

### Mappstrukturen

```
vagrant-ansible-flask-lab/
│
├── vagrant/
│   ├── Vagrantfile              # Beskriver alla 5 VMs
│   └── secrets.yml              # GITIGNORERAD — lösenord
│
├── ansible/
│   ├── ansible.cfg              # Ansible-konfiguration
│   ├── inventory.ini            # Lista på alla servrar
│   ├── site.yml                 # Master-playbook
│   ├── secrets_example.yml      # Mall för secrets.yml
│   │
│   ├── roles/
│   │   ├── database/            # PostgreSQL + UFW
│   │   ├── flask/               # Flask + Gunicorn
│   │   ├── nginx/               # Lastbalanseraren
│   │   └── security_hardening/  # SSH + fail2ban + auditd
│   │
│   └── test/
│       ├── verify.sh            # 14 tester (Linux)
│       └── verify_host.ps1      # 4 tester (Windows)
│
├── docs/
├── .gitignore
└── README.md
```

---

## Krav

Innan du börjar — se till att du har följande installerat.

### Program du behöver installera

| Program    | Version | Ladda ner från    |
|------------|---------|-------------------|
| VirtualBox | 7.x     | virtualbox.org    |
| Vagrant    | 2.x     | vagrantup.com     |
| Git        | Senaste | git-scm.com       |

### Hårdvarukrav

| Krav           | Minimum                          |
|----------------|----------------------------------|
| RAM            | 8 GB (projektet använder ca 3 GB)|
| Diskutrymme    | 20 GB ledigt                     |
| Operativsystem | Windows 10 eller nyare           |

### Verifiera att allt är installerat

Öppna PowerShell och kör dessa kommandon ett i taget:

```powershell
# Kontrollera VirtualBox
VBoxManage --version
# Du ska se: 7.x.x

# Kontrollera Vagrant
vagrant --version
# Du ska se: Vagrant 2.x.x

# Kontrollera Git
git --version
# Du ska se: git version 2.x.x
```

> Om något saknas — installera det från länkarna ovan och kör kommandot igen.

---

## Steg-för-steg installation

> Följ varje steg i ordning. Hoppa inte över något.

### Steg 1 — Klona projektet till din dator

**Vad vi gör:** Vi laddar ner projektet från GitHub till din dator.  
**Varför:** Alla projektfiler behöver finnas lokalt på din dator.

Öppna PowerShell och navigera till en lämplig mapp:

```powershell
# Gå till din projektmapp
# Tips: Undvik OneDrive-mappar — de kan låsa filer mitt i vagrant up
cd F:\Projects

# Ladda ner projektet från GitHub
git clone https://github.com/SSM-debug/vagrant-ansible-flask-lab.git
```

Du ska se:

```
Cloning into 'vagrant-ansible-flask-lab'...
remote: Counting objects: done.
```

Gå in i projektmappen:

```powershell
cd vagrant-ansible-flask-lab
```

### Steg 2 — Skapa din secrets-fil

**Vad vi gör:** Vi skapar en lokal fil med lösenord till databasen.  
**Varför:** Lösenord får aldrig ligga i koden på GitHub. Botar skannar GitHub konstant och hittar lösenord inom minuter. Filen `secrets.yml` är gitignorerad och finns aldrig i repot.

```powershell
# Kopiera mallen till en riktig secrets-fil
copy ansible\secrets_example.yml vagrant\secrets.yml

# Öppna secrets-filen för redigering
notepad vagrant\secrets.yml
```

Filen ser ut så här — byt ut platshållarna:

```yaml
# Dina databasinställningar
db_name: "flaskapp"
db_user: "flaskuser"
db_password: "VäljEttStarktLösenord123!"

# En hemlig nyckel för Flask
flask_secret_key: "en-lång-hemlig-nyckel-som-ingen-ska-se"
```

Spara och stäng Notepad.

```powershell
# Kontrollera att secrets.yml är gitignorerad
git status
# secrets.yml ska INTE synas i listan
```

### Steg 3 — Starta de virtuella datorerna

**Vad vi gör:** Vi startar alla 5 virtuella datorer med ett kommando.  
**Varför:** Vagrant läser Vagrantfile och skapar alla VMs automatiskt. Första gången laddas Ubuntu-systemet ner (ca 500 MB).

```powershell
# Gå till vagrant-mappen där Vagrantfile ligger
cd vagrant

# Starta alla 5 virtuella datorer
# Det här tar 10–15 minuter första gången
vagrant up
```

Du ser massor av text rulla förbi — det är normalt. Vagrant berättar vad den gör. När det är klart ser du:

```
==> control: === Ansible control node ready ===
```

Verifiera att alla VMs är uppe:

```powershell
vagrant status
```

Du ska se:

```
control   running (virtualbox)
nginx     running (virtualbox)
web1      running (virtualbox)
web2      running (virtualbox)
database  running (virtualbox)
```

> Om en VM inte startar — kör: `vagrant up <vmnamn>`. Se [Felsökning](#felsökning) för mer hjälp.

### Steg 4 — Konfigurera alla servrar med Ansible

**Vad vi gör:** Vi kör Ansible-playbooken som installerar och konfigurerar Flask, nginx, PostgreSQL och säkerhetsprogramvara.  
**Varför:** Vagrant skapade servrarna men de är tomma Ubuntu-installationer. Ansible fyller dem med rätt program och inställningar.

SSH in på control-VM:

```powershell
vagrant ssh control
```

Du ska nu se en Linux-prompt:

```
vagrant@control:~$
```

Kör master-playbooken:

```bash
# Kör Ansible-playbooken som konfigurerar alla servrar
# Det här tar 5–10 minuter
ansible-playbook ~/ansible/site.yml
```

Du ser Ansible arbeta sig igenom varje server. När det är klart ser du `PLAY RECAP`:

```
database : ok=XX  failed=0
nginx    : ok=XX  failed=0
web1     : ok=XX  failed=0
web2     : ok=XX  failed=0
```

`failed=0` på alla noder = allt gick bra! Om du ser `failed=1` — se [Felsökning](#felsökning).

### Steg 5 — Verifiera att systemet fungerar

**Vad vi gör:** Vi kör ett automatiserat testskript som kontrollerar att allt fungerar korrekt.  
**Varför:** Ansible kan säga `ok` utan att systemet faktiskt fungerar. Testerna kontrollerar det verkliga utfallet.

Kvar inne på control-VM, kör verifieringsskriptet:

```bash
bash ~/ansible/test/verify.sh
```

Du ska se 14 gröna PASS-rader:

```
[PASS] T01: nginx svarar på port 80 (HTTP 200)
[PASS] T02: Lastbalanseraren returnerar svar
[PASS] T03: Round-robin verifierat
[PASS] T04: Flask /health på web1 svarar ok
[PASS] T05: Flask /health på web2 svarar ok
[PASS] T06: Flask på web1 är ansluten till PostgreSQL
[PASS] T07: web1 kan ansluta till PostgreSQL port 5432
[PASS] T08: web2 kan ansluta till PostgreSQL port 5432
[PASS] T09: UFW blockerar nginx från PostgreSQL
[PASS] T10: SSH nyckelautentisering fungerar på web1
[PASS] T11: fail2ban är aktivt på web1
[PASS] T12: auditd är aktivt på database-VM
[PASS] T13: Flask systemd-tjänst är aktiv på web1
[PASS] T14: PostgreSQL lyssnar på 192.168.56.14

RESULTAT: 14 PASS / 0 FAIL
Alla tester godkända!
```

Avsluta control-VM:

```bash
exit
```

Kör Windows-testerna:

```powershell
powershell -ExecutionPolicy Bypass -File ..\ansible\test\verify_host.ps1
```

Du ska se:

```
[PASS] T15: nginx reachable via port forwarding :8080
[PASS] T16: nginx port 80 NOT exposed on host
[PASS] T17: PostgreSQL NOT exposed via port forwarding
[PASS] T18: Flask port 5000 NOT exposed via port forwarding

RESULT: 4 PASS / 0 FAIL
```

### Steg 6 — Testa i webbläsaren

**Vad vi gör:** Vi öppnar systemet i webbläsaren och ser round-robin i aktion.

Öppna din webbläsare och gå till:

```
http://localhost:8080/
```

Du ska se: `Hello from web1!`

Ladda om sidan (F5) — du ska nu se: `Hello from web2!`

Ladda om igen — `Hello from web1!`

Det här är round-robin lastbalansering i aktion! nginx fördelar trafiken jämnt mellan web1 och web2.

| URL                        | Förväntat svar                                |
|----------------------------|-----------------------------------------------|
| `http://localhost:8080/`   | `Hello from web1!` eller `Hello from web2!`   |
| `http://localhost:8080/health` | `{"status": "ok", "host": "web1"}`        |
| `http://localhost:8080/info`   | JSON med `db_status: connected`           |

> Om du ser `db_status: connected` i `/info` — Flask pratar med PostgreSQL. Hela kedjan fungerar!

### Steg 7 — Testa reproducerbarhet (VG-krav)

**Vad vi gör:** Vi förstör hela miljön och bygger upp den från noll — för att bevisa att allt är automatiserat.  
**Varför:** Det här är ett av de viktigaste VG-kraven: `destroy && up` ger identisk miljö. Det bevisar att infrastrukturen verkligen är kod — inte manuellt arbete.

Förstör alla VMs:

```powershell
vagrant destroy -f
```

Bygg upp allt från noll:

```powershell
vagrant up
```

SSH in och kör Ansible:

```bash
vagrant ssh control
ansible-playbook ~/ansible/site.yml
bash ~/ansible/test/verify.sh
```

> Om testerna visar 14/14 PASS är infrastrukturen fullt reproducerbar. Det är Infrastructure as Code!

---

## Säkerhetsåtgärder

Alla säkerhetsåtgärder appliceras automatiskt av Ansible-rollen `security_hardening` på samtliga 4 noder.

### SSH-härdning

Konfigurerad i `ansible/roles/security_hardening/templates/sshd_config.j2`

| Inställning              | Värde   | Skyddar mot                      |
|--------------------------|---------|----------------------------------|
| `PasswordAuthentication` | no      | Credential stuffing, brute force |
| `PermitRootLogin`        | no      | Direkt root-åtkomst              |
| `AllowUsers`             | vagrant | Obehöriga konton                 |
| `MaxAuthTries`           | 3       | Automatiserade inloggningsförsök |

> Med `PasswordAuthentication no` spelar det ingen roll om en angripare har miljoner stulna lösenord — SSH accepterar bara nycklar.

### fail2ban — automatisk IP-blockering

Installerat på alla 4 noder. När någon misslyckas med SSH-inloggning 5 gånger inom 10 minuter blockeras deras IP-adress automatiskt i 10 minuter.

```
# Hur fail2ban fungerar:
Angripare försöker logga in
  --> 5 misslyckanden inom 10 minuter
  --> IP blockeras automatiskt i 600 sekunder
  --> Angriparen måste vänta innan nästa försök
```

### auditd — filsystemövervakning

Loggar automatiskt när någon läser eller ändrar känsliga filer:

| Fil            | Varför den övervakas |
|----------------|----------------------|
| `/etc/passwd`  | Användarkonton       |
| `/etc/shadow`  | Lösenordshashes      |
| `/etc/sudoers` | Sudo-rättigheter     |
| `~/.ssh/`      | SSH-nycklar          |

### UFW — nätverksbrandvägg

```
# Regler på database-VM:
Port 22 (SSH)         --> Tillåt från alla
Port 5432 (PostgreSQL)--> Tillåt BARA från 192.168.56.12 och .13
Allt annat            --> Blockera
```

### Principle of Least Privilege

Flask ansluter till PostgreSQL som `flaskuser` — inte som `postgres` (superanvändaren).

```sql
-- flaskuser har BARA dessa rättigheter:
-- SELECT, INSERT, UPDATE, DELETE på applikationens tabeller
-- Ingen CREATE, DROP, SUPERUSER eller CREATEDB
```

En SQL-injection-attack kan inte ta över hela databasservern.

### systemd-härdning

Flask/Gunicorn körs med extra säkerhetsinställningar:

```ini
# Säkerhetsinställningar i flask.service
Restart=always          # Startar om vid krasch
NoNewPrivileges=true    # Kan inte få fler rättigheter
PrivateTmp=true         # Egen isolerad /tmp-mapp
```

---

## Säkerhetsanalys STRIDE

STRIDE är ett ramverk för hotmodellering med sex kategorier. Vi tittar på arkitekturen från sex vinklar och frågar: "hur kan just det här gå sönder?"

| Hot                       | Var i vår arkitektur            | Konsekvens                          | Vår åtgärd                    |
|---------------------------|---------------------------------|-------------------------------------|-------------------------------|
| S — Spoofing              | SSH-nycklar på control-VM       | Angripare loggar in som admin       | `PasswordAuthentication no`   |
| T — Tampering             | `/opt/flask/app.py`             | Bakdörr i applikationen             | Ansible återställer från Git  |
| R — Repudiation           | Alla noder                      | Ingen kan bevisa vem som gjorde vad | journald, auditd              |
| I — Information Disclosure| `secrets.yml`, miljövariabler   | Lösenord hamnar hos angripare       | gitignore, 0600-rättigheter   |
| D — Denial of Service     | nginx (Single Point of Failure) | Hela systemet nere                  | systemd `Restart=always`      |
| E — Elevation of Privilege| Flask till PostgreSQL           | SQL-injection ger superuser         | flaskuser utan superuser      |

### Kända kvarvarande brister

Att känna till sina svagheter är lika viktigt som att implementera skydd.

| Nr | Brist                                      | Konsekvens                          | Lösning i produktion               |
|----|--------------------------------------------|-------------------------------------|------------------------------------|
| 1  | nginx är en Single Point of Failure        | Hela systemet nere vid krasch       | Keepalived/VRRP för failover       |
| 2  | Lösenord synliga i miljövariabler          | Lösenord läckage via `ps auxe`      | HashiCorp Vault                    |
| 3  | host-only nätverk nås från Windows         | VMs inte fullt isolerade            | `intnet` istället för `private_network` |
| 4  | `secrets.yml` i klartext på disk           | Läsbart om disk komprometteras      | `ansible-vault encrypt`            |

---

## Verifiering

### Kör alla tester från control-VM (14 tester)

```bash
# SSH in på control-VM
vagrant ssh control

# Kör alla 14 automatiserade tester
bash ~/ansible/test/verify.sh

# Logga ut från control-VM
exit
```

### Kör Windows-tester (4 tester)

```powershell
powershell -ExecutionPolicy Bypass -File ansible\test\verify_host.ps1
```

### Vad testerna bevisar

| Test    | Vad det bevisar                             |
|---------|---------------------------------------------|
| T01–T02 | nginx fungerar och svarar                   |
| T03     | Round-robin lastbalansering fungerar        |
| T04–T05 | Flask körs på båda webbservrarna            |
| T06     | Flask når PostgreSQL (hela kedjan fungerar) |
| T07–T08 | web1 och web2 når databasen                 |
| T09     | UFW-segmentering fungerar (nginx blockeras) |
| T10     | SSH-härdning fungerar                       |
| T11–T12 | fail2ban och auditd är aktiva               |
| T13     | Flask systemd-tjänst är igång               |
| T14     | PostgreSQL lyssnar på rätt IP               |
| T15–T18 | Interna portar inte exponerade utifrån      |

---

## Designval och motivering

### Varför control-VM istället för Ansible från laptopen?

Ansible stöds inte officiellt på Windows. Men det finns en viktigare säkerhetssak: om du kör Ansible från laptopen ligger SSH-nycklarna på samma maskin där du surfar och läser e-post.

Control-VM är en separat säkerhetsgräns — minimal, dedikerad, kan stängas av när den inte används.

### Varför Gunicorn istället för Flasks inbyggda server?

|                     | Flasks dev-server   | Gunicorn         |
|---------------------|---------------------|------------------|
| Användare samtidigt | 1                   | Många            |
| Felmeddelanden      | Visas i webbläsaren | Loggas internt   |
| Produktion          | Nej                 | Ja               |
| Automatisk omstart  | Nej                 | Ja (via systemd) |

### Varför dynamisk upstream i nginx?

`nginx.conf` genereras från `groups["webservers"]` i inventory via Jinja2-template. Att lägga till web3 kräver bara en rad i inventory — ingen kodändring i nginx.

```ini
# Lägg till i inventory.ini för att utöka med web3:
[webservers]
web1 ansible_host=192.168.56.12
web2 ansible_host=192.168.56.13
web3 ansible_host=192.168.56.15  # <- Bara den här raden
```

Kör sedan `ansible-playbook site.yml` — nginx uppdateras automatiskt.

### Varför hypervisor (VirtualBox) istället för containers (Docker)?

|           | VirtualBox (hypervisor)  | Docker (containers)          |
|-----------|--------------------------|------------------------------|
| Isolering | Eget OS per VM           | Delar kärnan med hosten      |
| Säkerhet  | Starkare isolering       | Kärn-exploits påverkar alla  |
| Realism   | Som riktiga servrar      | Som applikationsplattform    |

För ett säkerhetsprojekt väljer vi VirtualBox — starkare isolering och mer realistisk representation av produktionsmiljöer.

---

## Felsökning

### Problem: `vagrant up` hänger sig eller kraschar

Kontrollera status på alla VMs:

```powershell
vagrant status

# Stäng ner en specifik VM
vagrant halt control

# Starta den igen
vagrant up control
```

### Problem: `ansible-playbook` misslyckas

Kontrollera att Ansible når alla noder:

```bash
ansible all -m ping
# Du ska se pong från alla 4 noder
```

### Problem: `localhost:8080` svarar inte

Kör om Ansible-konfigurationen:

```bash
ansible-playbook ~/ansible/site.yml
```

### Problem: `db_status` visar error i `/info`

Kontrollera att PostgreSQL körs:

```bash
ssh -i ~/.ssh/control_ed25519 vagrant@192.168.56.14 "systemctl status postgresql"
```

### Kärnlösning — börja om från noll

Det fina med IaC är att börja om tar bara 15 minuter:

```powershell
# Radera alla VMs
vagrant destroy -f

# Bygg upp allt från noll
vagrant up
```

```bash
vagrant ssh control
ansible-playbook ~/ansible/site.yml
bash ~/ansible/test/verify.sh
```

> Om testerna visar 14/14 PASS är du tillbaka till ett fungerande system.

---

## Ordlista

> När du ser *(se Ordlista: X)* i texten — leta upp begreppet här.

### IaC — Infrastructure as Code

Infrastructure as Code betyder att du beskriver din infrastruktur i kodfiler istället för att göra det manuellt.

Fördelar:
- **Reproducerbart** — vem som helst kan återskapa miljön från koden
- **Versionshanterat** — du ser exakt vad som ändrades och när
- **Automatiserbart** — CI/CD-system kan köra det automatiskt

### Idempotens

Idempotens betyder att du kan köra samma operation hur många gånger som helst och alltid få samma resultat.

```
# Exempel:
Körning 1: Installerar nginx, skapar användare, konfigurerar brandväggen
Körning 2: Ser att nginx redan är installerat --> gör ingenting
Körning 3: Ser att allt är korrekt --> gör ingenting
```

### Inventory

En Ansible inventory-fil listar alla servrar och organiserar dem i grupper.

```ini
# ansible/inventory.ini
[lb]
nginx ansible_host=192.168.56.11

[webservers]
web1 ansible_host=192.168.56.12
web2 ansible_host=192.168.56.13

[db]
database ansible_host=192.168.56.14
```

### Jinja2

Jinja2 är en template-motor som låter dig skapa textfiler med platshållare som fylls i automatiskt.

```jinja2
# Exempel från nginx.conf.j2:
upstream backend {
{% for host in groups["webservers"] %}
    server {{ hostvars[host]["ansible_host"] }}:5000;
{% endfor %}
}

# Genererar automatiskt:
upstream backend {
    server 192.168.56.12:5000;
    server 192.168.56.13:5000;
}
```

### Nätverkssegmentering

Nätverkssegmentering delar upp nätverket i zoner med olika säkerhetsnivåer.

```
# Våra tre zoner:
Zon 1 -- Publik:   nginx (.11) -- nåbar utifrån via port 8080
Zon 2 -- App:      web1 (.12), web2 (.13) -- nåbar från nginx
Zon 3 -- Databas:  database (.14) -- nåbar BARA från web1/web2
```

### Omvänd proxy (Reverse Proxy)

En omvänd proxy tar emot förfrågningar och vidarebefordrar dem till backend-servrar. Klienten ser bara proxyn.

```
# Flöde:
Klient --> nginx (proxy) --> Flask på web1 eller web2
```

### Playbook

En Ansible-playbook beskriver vad som ska göras på vilka servrar i vilken ordning.

```yaml
# ansible/site.yml
- name: Configure database server
  hosts: db
  roles:
    - database

- name: Configure web servers
  hosts: webservers
  roles:
    - flask
```

### Roll (Ansible Role)

En Ansible-roll är en samling tasks och templates med ett specifikt ansvar.

```
# Struktur för database-rollen:
roles/database/
├── tasks/main.yml        # Vad som ska göras
├── handlers/main.yml     # Vad som körs vid notify
├── defaults/main.yml     # Standardvärden
└── templates/            # Jinja2-templates
```

### Round-robin

Round-robin fördelar förfrågningar i turordning.

```
# Hur round-robin fungerar:
Förfrågan 1 --> web1
Förfrågan 2 --> web2
Förfrågan 3 --> web1
Förfrågan 4 --> web2
```

### SSH — Secure Shell

SSH är ett protokoll för att logga in på en annan dator säkert över nätverket. All kommunikation är krypterad.

```
# SSH-nycklar:
Privat nyckel --> ligger på control-VM, får ALDRIG lämna den
Publik nyckel --> installeras på alla noder

# Analogin:
Privat nyckel = din husnyckel
Publik nyckel = ditt lås
```

### systemd

systemd hanterar tjänster i Linux som ska köra kontinuerligt.

```ini
# Säkerhetsinställningar i vår flask.service:
Restart=always          # Startar om vid krasch
NoNewPrivileges=true    # Kan inte få fler rättigheter
PrivateTmp=true         # Egen isolerad /tmp-mapp
```

### UFW — Uncomplicated Firewall

UFW bestämmer vilken nätverkstrafik som tillåts och vilken som blockeras.

```
# UFW-regler på database-VM:
Port 22   --> Tillåt SSH från alla
Port 5432 --> Tillåt BARA från web1 och web2
Allt annat --> Blockera
```

---

*README genererad som en del av examensprojektet i kursen Virtualiseringsteknik och automation, YH Enköping 2026.*  
*Skapad av: Sushanta Shekhar Modak och Farhad Norman*
