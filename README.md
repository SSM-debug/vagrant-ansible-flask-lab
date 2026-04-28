# vagrant-ansible-flask-lab

![Status](https://img.shields.io/badge/Status-Klar-brightgreen)
![VMs](https://img.shields.io/badge/VMs-5-blue)
![Tests](https://img.shields.io/badge/Tester-18%2F18_PASS-brightgreen)
![Ansible](https://img.shields.io/badge/Ansible-2.10-red)
![Vagrant](https://img.shields.io/badge/Vagrant-2.4-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-orange)
![Kurs](https://img.shields.io/badge/YH_Enkoping-IT--sakerhet-purple)

> Forestall dig att du ska satta upp fem servrar pa ett foretag.
> Traditionellt tar det dagar och massor av manuellt arbete.
> Det har projektet gor allt automatiskt med ett enda kommando.

**Vad du far nar projektet ar klart:**

- En webbapplikation lastbalanserad mellan tva servrar
- En isolerad databasserver som bara applikationsservrarna nar
- Automatisk sakerhetshardning pa alla servrar
- 18 automatiserade tester som bevisar att allt fungerar

**Tid att satta upp:** ca 20-30 minuter

**Forfattare:** Sushanta Shekhar Modak och Farhad Norman

**Kurs:** Virtualiseringsteknik och automation, YH Enkoping

---

## Innehallsforteckning

| Nr | Sektion |
|----|---------|
| 1 | [Vad ar verktygen?](#vad-ar-verktygen) |
| 2 | [Arkitektur](#arkitektur) |
| 3 | [Krav](#krav) |
| 4 | [Steg-for-steg installation](#steg-for-steg-installation) |
| 5 | [Sakerhetsatgarder](#sakerhetsatgarder) |
| 6 | [Sakerhetsanalys STRIDE](#sakerhetsanalys-stride) |
| 7 | [Verifiering](#verifiering) |
| 8 | [Designval och motivering](#designval-och-motivering) |
| 9 | [Felsokning](#felsokning) |
| 10 | [Ordlista](#ordlista) |

---
## Vad ar verktygen?

> Hoppa garna forbi det har om du redan vet vad verktygen gor.
> Alla tekniska begrepp forklaras i [Ordlistan](#ordlista).

### VirtualBox — din dator i datorn

VirtualBox later dig skapa virtuella datorer inuti din riktiga dator.
Tank dig att du har fem laptops inuti din laptop — var och en med eget
operativsystem, eget natverk och egna program.

Vi anvander VirtualBox for att skapa fem virtuella Ubuntu-servrar som
pratar med varandra via ett privat natverk.

### Vagrant — automatisk skapare av virtuella datorer

Istallet for att klicka ihop virtuella datorer manuellt i VirtualBox
beskriver du dem i en textfil som heter Vagrantfile. Vagrant laser
filen och skapar allt automatiskt.

**Analogin:** Vagrant ar som ett recept. VirtualBox ar koket.
Du foljer receptet och far samma ratt varje gang.

| | Utan Vagrant | Med Vagrant |
|--|--|--|
| Tid | 45 min manuellt per server | vagrant up - klart pa 15 min |
| Repeterbarhet | Olika varje gang | Identiskt varje gang |
| Felsokning | Borja om manuellt | vagrant destroy && vagrant up |

Det har kallas IaC (Infrastructure as Code) *(se [Ordlista: IaC](#iac--infrastructure-as-code))*.

### Ansible — automatisk serverkonfigurerare

Nar dina virtuella datorer ar skapade behoever de konfigureras.
Ansible gor det automatiskt via SSH *(se [Ordlista: SSH](#ssh--secure-shell))*.

Du skriver vad du vill ha, och Ansible raknar ut hur det ska goras
pa alla servrar samtidigt. Det kallas idempotens
*(se [Ordlista: Idempotens](#idempotens))*.

Ansible organiserar arbetet i roller *(se [Ordlista: Roll](#roll-ansible-role))*
och playbooks *(se [Ordlista: Playbook](#playbook))*.

**Analogin:** Ansible ar som en servicetekniker med en checklista.
Du ger hen checklistan, hen fixar allt pa alla maskiner.

| | Utan Ansible | Med Ansible |
|--|--|--|
| Metod | Logga in pa 5 servrar manuellt | Ett kommando |
| Tid | Timmar | 5 minuter |
| Risk | Latt att missa nagot | Alltid identiskt |

### Flask — webbapplikationen

Flask ar ett minimalt Python *(se [Ordlista: Python](#python))*-webbramverk.
Var applikation tar emot webbforfragningar, hamtar data fran databasen
och svarar tillbaka.

**Var app har tre endpoints:**

| Endpoint | Vad den gor |
|----------|------------|
| / | Returnerar Hello from web1! eller Hello from web2! |
| /health | Returnerar status ok — anvands av nginx for halsocheck |
| /info | Returnerar JSON med databas-status och timestamp |

### Gunicorn — produktionswebbservern

Flask har en inbyggd webbserver men den ar bara for utveckling.
Gunicorn ar en riktig produktionsserver som hanterar manga anvandare
samtidigt. Vi kor Gunicorn som en systemd-tjanst
*(se [Ordlista: systemd](#systemd))*.

| | Flasks dev-server | Gunicorn |
|--|--|--|
| Anvandare samtidigt | 1 | Manga (flera workers) |
| Felmeddelanden | Visas i webblasaren | Loggas internt |
| Vid krasch | Stannar nere | Startar om automatiskt |
| Lampar sig for | Utveckling | Produktion |

**Analogin:** Flasks dev-server ar en hemmasnickrad pall.
Gunicorn ar stolen som tal att sta i ett kafe hela dagen.

### nginx — lastbalanseraren

nginx (uttalas engine-x) fungerar som en trafikpolis for webbtrafik.

**Som lastbalanserare:** nginx tar emot all trafik utifran och bestaemmer
vilken server som ska svara via round-robin
*(se [Ordlista: Round-robin](#round-robin))*.

**Som omvand proxy** *(se [Ordlista: Omvand proxy](#omvand-proxy-reverse-proxy))*:
nginx tar emot forfragningar pa port 80 och skickar dem vidare till
Flask pa port 5000. Anvandaren ser aldrig Flask direkt.

nginx-konfigurationen genereras automatiskt fran en Jinja2-template
*(se [Ordlista: Jinja2](#jinja2))* — vilket betyder att du kan lagga
till fler servrar utan att andra nginx-koden.

**Analogin:** Tank pa nginx som receptionen pa ett sjukhus. Alla
patienter gar in genom receptionen. Receptionen bestaemmer vilken
lakare som tar nasta patient.

### PostgreSQL — databasen

PostgreSQL ar en relationsdatabas dar var applikation sparar och hamtar
data. Den kors pa en helt separat server och ar bara nabar fran web1
och web2 — inte fran omvarlden.

---
## Arkitektur

### Systemdiagram

```
Windows-laptop
     |
     | Port 8080
     |
[nginx .11] -- round-robin --> [web1 .12]
                          --> [web2 .13]
[web1] --> [database .14] (UFW: bara .12 och .13)
[web2] --> [database .14]
[control .10] --> hanterar alla via Ansible
```

## Arkitektur

### Systemdiagram

```
Windows-laptop
     |
     | Port 8080
     |
[nginx .11] -- round-robin --> [web1 .12]
                          --> [web2 .13]
[web1] --> [database .14] (UFW: bara .12 och .13)
[web2] --> [database .14]
[control .10] --> hanterar alla via Ansible
```

### IP-adresser och resurser

| VM | Roll | IP-adress | RAM |
|---|---|---|---|
| control | Ansible-kontroll | 192.168.56.10 | 512 MB |
| nginx | Lastbalanserare | 192.168.56.11 | 512 MB |
| web1 | Flask + Gunicorn | 192.168.56.12 | 512 MB |
| web2 | Flask + Gunicorn | 192.168.56.13 | 512 MB |
| database | PostgreSQL | 192.168.56.14 | 768 MB |

> Totalt RAM: ca 3 GB. Du behoever minst 8 GB RAM.

### Saekerhetsdesignen foerklarad

**Varfoer har bara nginx port forwarding?**

web1, web2 och database aer helt osynliga utifraon.
En angripare kan naa nginx — men inte databasen direkt.

**Varfoer faer inte nginx prata med databasen?**

UFW paa databasservern tillaaater bara anslutningar fraan
web1 (.12) och web2 (.13). Nginx (.11) blockeras helt.
Det kallas naetverkssegmentering.

**Varfoer koer vi Ansible fraan control-VM?**

Om du koer Ansible fraan laptopen ligger SSH-nycklarna paa
samma dator daer du surfar. Control-VM aer en separat
saekerhetsdomaen — minimal och dedikerad.

### Mappstrukturen

```
vagrant-ansible-flask-lab/
|
+-- vagrant/
|   +-- Vagrantfile          # Beskriver alla 5 VMs
|   +-- secrets.yml          # GITIGNORERAD
|
+-- ansible/
|   +-- ansible.cfg          # Ansible-konfiguration
|   +-- inventory.ini        # Lista paa alla servrar
|   +-- site.yml             # Master-playbook
|   +-- secrets_example.yml  # Mall foer secrets.yml
|   |
|   +-- roles/
|   |   +-- database/        # PostgreSQL + UFW
|   |   +-- flask/           # Flask + Gunicorn
|   |   +-- nginx/           # Lastbalanseraren
|   |   +-- security_hardening/ # SSH + fail2ban + auditd
|   |
|   +-- test/
|       +-- verify.sh        # 14 tester (Linux)
|       +-- verify_host.ps1  # 4 tester (Windows)
|
+-- docs/
+-- .gitignore
+-- README.md
```

---

## Krav

Innan du borjar — se till att du har foljande installerat.

### Program du behoever installera

| Program | Version | Ladda ner fran |
|---------|---------|----------------|
| VirtualBox | 7.x | [virtualbox.org](https://www.virtualbox.org/) |
| Vagrant | 2.x | [vagrantup.com](https://www.vagrantup.com/) |
| Git | Senaste | [git-scm.com](https://git-scm.com/) |

### Hardvarukrav

| Krav | Minimum |
|------|--------|
| RAM | 8 GB (projektet anvander ca 3 GB) |
| Diskutrymme | 20 GB ledigt |
| Operativsystem | Windows 10 eller nyare |

### Verifiera att allt ar installerat

Oppna PowerShell och kor dessa kommandon ett i taget:

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

> Om nagot saknas — installera det fran lankarna ovan och kor kommandot igen.

---

## Steg-for-steg installation

> Folj varje steg i ordning. Hoppa inte over nagot.

---

### Steg 1 — Klona projektet till din dator

**Vad vi gor:** Vi laddar ner projektet fran GitHub till din dator.

**Varfor:** Alla projektfiler behoever finnas lokalt pa din dator.

Oppna PowerShell och navigera till en lamplig mapp:

```powershell
# Ga till din projektmapp
# Tips: Undvik OneDrive-mappar — de kan lasa filer mitt i vagrant up
cd F:\Projects
```

Klona projektet fran GitHub:

```powershell
# Ladda ner projektet fran GitHub
git clone https://github.com/SSM-debug/vagrant-ansible-flask-lab.git
```

Du ska se:

```
Cloning into vagrant-ansible-flask-lab...
remote: Counting objects: done.
```

Ga in i projektmappen:

```powershell
# Ga in i den nerklonade mappen
cd vagrant-ansible-flask-lab
```

Du ska nu se:

```
PS F:\Projects\vagrant-ansible-flask-lab>
```

---

### Steg 2 — Skapa din secrets-fil

**Vad vi gor:** Vi skapar en lokal fil med losenord till databasen.

**Varfor:** Losenord far aldrig ligga i koden pa GitHub.
Botar scannar GitHub konstant och hittar losenord inom minuter.
Filen secrets.yml ar gitignorerad och finns aldrig i repot.

Kopiera mallen:

```powershell
# Kopiera mallen till en riktig secrets-fil
copy ansible\secrets_example.yml vagrant\secrets.yml
```

Oppna filen i Notepad:

```powershell
# Oppna secrets-filen for redigering
notepad vagrant\secrets.yml
```

Filen ser ut sa har — byt ut platshallarna:

```yaml
# Dina databasinstaellningar
db_name: "flaskapp"
db_user: "flaskuser"
db_password: "ValjEttStarktLosenord123!"

# En hemlig nyckel for Flask
flask_secret_key: "en-lang-hemlig-nyckel-som-ingen-ska-se"
```

Spara och stang Notepad.

Kontrollera att secrets.yml inte syns i Git:

```powershell
# Kontrollera att secrets.yml ar gitignorerad
git status
# secrets.yml ska INTE synas i listan
```

---

### Steg 3 — Starta de virtuella datorerna

**Vad vi gor:** Vi startar alla 5 virtuella datorer med ett kommando.

**Varfor:** Vagrant laser Vagrantfile och skapar alla VMs automatiskt.
Forsta gangen laddas Ubuntu-systemet ner (ca 500 MB).

Ga till vagrant-mappen:

```powershell
# Ga till vagrant-mappen dar Vagrantfile ligger
cd vagrant
```

Starta alla VMs:

```powershell
# Starta alla 5 virtuella datorer
# Det har tar 10-15 minuter forsta gangen
vagrant up
```

Du ser massor av text rulla forbi — det ar normalt.
Vagrant berättar vad den gor. Nar det ar klart ser du:

```
==> control: === Ansible control node ready ===
```

Verifiera att alla VMs ar uppe:

```powershell
# Kontrollera status pa alla VMs
vagrant status
```

Du ska se:

```
control    running (virtualbox)
nginx      running (virtualbox)
web1       running (virtualbox)
web2       running (virtualbox)
database   running (virtualbox)
```

> Om en VM inte startar — kor: vagrant up <vm-namn>
> Se [Felsokning](#felsokning) for mer hjalp.

---

### Steg 4 — Konfigurera alla servrar med Ansible

**Vad vi gor:** Vi kor Ansible-playbooken som installerar och
konfigurerar Flask, nginx, PostgreSQL och sakerhetsprogramvara.

**Varfor:** Vagrant skapade servrarna men de ar tomma Ubuntu-
installationer. Ansible fyller dem med ratt program och installningar.

SSH in pa control-VM:

```powershell
# Logga in pa control-VM via SSH
vagrant ssh control
```

Du ska nu se en Linux-prompt:

```
vagrant@control:~$
```

Kor master-playbooken:

```bash
# Kor Ansible-playbooken som konfigurerar alla servrar
# Det har tar 5-10 minuter
ansible-playbook ~/ansible/site.yml
```

Du ser Ansible arbeta sig igenom varje server.
Nar det ar klart ser du PLAY RECAP:

```
database : ok=XX  failed=0
nginx    : ok=XX  failed=0
web1     : ok=XX  failed=0
web2     : ok=XX  failed=0
```

> failed=0 pa alla noder = allt gick bra!
> Om du ser failed=1 — se [Felsokning](#felsokning).

---

### Steg 5 — Verifiera att systemet fungerar

**Vad vi gor:** Vi kor ett automatiserat testskript som
kontrollerar att allt fungerar korrekt.

**Varfor:** Ansible kan saga ok utan att systemet faktiskt
fungerar. Testerna kontrollerar det verkliga utfallet.

Kvar inne pa control-VM, kor verifieringsskriptet:

```bash
# Kor alla automatiserade tester
bash ~/ansible/test/verify.sh
```

Du ska se 14 gröna PASS-rader:

```
[PASS] T01: nginx svarar pa port 80 (HTTP 200)
[PASS] T02: Lastbalanseraren returnerar svar
[PASS] T03: Round-robin verifierat
[PASS] T04: Flask /health pa web1 svarar ok
[PASS] T05: Flask /health pa web2 svarar ok
[PASS] T06: Flask pa web1 ar ansluten till PostgreSQL
[PASS] T07: web1 kan ansluta till PostgreSQL port 5432
[PASS] T08: web2 kan ansluta till PostgreSQL port 5432
[PASS] T09: UFW blockerar nginx fran PostgreSQL
[PASS] T10: SSH nyckelautentisering fungerar pa web1
[PASS] T11: fail2ban ar aktivt pa web1
[PASS] T12: auditd ar aktivt pa database-VM
[PASS] T13: Flask systemd-tjanst ar aktiv pa web1
[PASS] T14: PostgreSQL lyssnar pa 192.168.56.14

RESULTAT: 14 PASS / 0 FAIL
Alla tester godkanda!
```

Avsluta control-VM:

```bash
# Logga ut fran control-VM
exit
```

Kor Windows-testerna:

```powershell
# Kor 4 extra tester fran Windows-hosten
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

---

### Steg 6 — Testa i webblasaren

**Vad vi gor:** Vi oppnar systemet i webblasaren och ser
round-robin i aktion.

Oppna din webblasare och ga till:

```
http://localhost:8080/
```

Du ska se: Hello from web1!

Ladda om sidan (F5) — du ska nu se: Hello from web2!

Ladda om igen — Hello from web1!

> Det har ar round-robin lastbalansering i aktion!
> nginx fordelar trafiken jamnt mellan web1 och web2.

Testa de andra endpoints:

| URL | Forväntat svar |
|-----|---------------|
| http://localhost:8080/ | Hello from web1! eller web2! |
| http://localhost:8080/health | {"status": "ok", "host": "web1"} |
| http://localhost:8080/info | JSON med db_status: connected |

> Om du ser db_status: connected i /info — Flask pratar
> med PostgreSQL. Hela kedjan fungerar!

---

### Steg 7 — Testa reproducerbarhet (VG-krav)

**Vad vi gor:** Vi forstör hela miljon och bygger upp den
fran noll — for att bevisa att allt ar automatiserat.

**Varfor:** Det har ar ett av de viktigaste VG-kraven:
destroy && up ger identisk miljo. Det bevisar att
infrastrukturen verkligen ar kod — inte manuellt arbete.

Forstör alla VMs:

```powershell
# Radera alla virtuella datorer
vagrant destroy -f
```

Bygg upp allt fran noll:

```powershell
# Skapa alla VMs igen fran noll
vagrant up
```

SSH in och kor Ansible:

```powershell
# Logga in pa control-VM
vagrant ssh control
```

```bash
# Konfigurera alla servrar igen
ansible-playbook ~/ansible/site.yml

# Verifiera att allt fungerar
bash ~/ansible/test/verify.sh
```

> Om testerna visar 14/14 PASS ar infrastrukturen
> fullt reproducerbar. Det ar Infrastructure as Code!

---

## Sakerhetsatgarder

Alla sakerhetsatgarder appliceras automatiskt av Ansible-rollen
security_hardening pa samtliga 4 noder.

### SSH-hardning

Konfigurerad i ansible/roles/security_hardening/templates/sshd_config.j2

| Installning | Varde | Skyddar mot |
|------------|-------|-------------|
| PasswordAuthentication | no | Credential stuffing, brute force |
| PermitRootLogin | no | Direkt root-atkomst |
| AllowUsers | vagrant | Obehöriga konton |
| MaxAuthTries | 3 | Automatiserade inloggningsforsok |

> Med PasswordAuthentication no spelar det ingen roll om en
> angripare har miljoner stulna losenord — SSH accepterar bara nycklar.

### fail2ban — automatisk IP-blockering

Installerat pa alla 4 noder. Nar nagon misslyckas med
SSH-inloggning 5 ganger inom 10 minuter blockeras deras
IP-adress automatiskt i 10 minuter.

```
# Hur fail2ban fungerar:
Angripare forsoker logga in
  --> 5 misslyckanden inom 10 minuter
    --> IP blockeras automatiskt i 600 sekunder
      --> Angriparen maste vanta innan nasta forsok
```

### auditd — filsystemovervakning

Loggar automatiskt nar nagon laser eller andrar kansliga filer:

| Fil | Varfor den overvakas |
|-----|---------------------|
| /etc/passwd | Anvandarkonton |
| /etc/shadow | Losenordshashes |
| /etc/sudoers | Sudo-rattigheter |
| ~/.ssh/ | SSH-nycklar |

### UFW — natverksbrandvagg

```
# Regler pa database-VM:
Port 22  (SSH)        --> Tillat fran alla
Port 5432 (PostgreSQL) --> Tillat BARA fran 192.168.56.12 och .13
Allt annat            --> Blockera
```

### Principle of Least Privilege

Flask ansluter till PostgreSQL som flaskuser — inte som
postgres (superanvandaren).

```sql
-- flaskuser har BARA dessa rattigheter:
-- SELECT, INSERT, UPDATE, DELETE pa applikationens tabeller
-- Ingen CREATE, DROP, SUPERUSER eller CREATEDB
```

En SQL-injection-attack kan inte ta over hela databasservern.

### systemd-hardning

Flask/Gunicorn kor med extra sakerhetsinstallningar:

```ini
# Sakerhetsinstallningar i flask.service
Restart=always        # Startar om vid krasch
NoNewPrivileges=true  # Kan inte fa fler rattigheter
PrivateTmp=true       # Egen isolerad /tmp-mapp
```

---

## Sakerhetsanalys STRIDE

STRIDE ar ett ramverk for hotmodellering med sex kategorier.
Vi tittar pa arkitekturen fran sex vinklar och fragar:
"hur kan just det har ga sonder?"

| Hot | Var i var arkitektur | Konsekvens | Var atgard |
|-----|---------------------|------------|------------|
| S - Spoofing | SSH-nycklar pa control-VM | Angripare loggar in som admin | PasswordAuthentication no |
| T - Tampering | /opt/flask/app.py | Bakdorr i applikationen | Ansible aterstaller fran Git |
| R - Repudiation | Alla noder | Ingen kan bevisa vem som gjorde vad | journald, auditd |
| I - Information Disclosure | secrets.yml, miljovariabler | Losenord hamnar hos angripare | gitignore, 0600-rattigheter |
| D - Denial of Service | nginx (Single Point of Failure) | Hela systemet nere | systemd Restart=always |
| E - Elevation of Privilege | Flask till PostgreSQL | SQL-injection ger superuser | flaskuser utan superuser |

### Kanda kvarstaende brister

> Att kanna till sina svagheter ar lika viktigt som att implementera skydd.

| Nr | Brist | Konsekvens | Losning i produktion |
|----|-------|------------|---------------------|
| 1 | nginx ar en Single Point of Failure | Hela systemet nere vid krasch | Keepalived/VRRP for failover |
| 2 | Losenord synliga i miljovariabler | Losenord lackage via ps auxe | HashiCorp Vault |
| 3 | host-only natverk nas fran Windows | VMs inte fullt isolerade | intnet istallet for private_network |
| 4 | secrets.yml i klartext pa disk | Lasbart om disk komprometteras | ansible-vault encrypt |

---

## Verifiering

### Kor alla tester fran control-VM (14 tester)

Logga in pa control-VM:

```powershell
# SSH in pa control-VM
vagrant ssh control
```

Kor verifieringsskriptet:

```bash
# Kor alla 14 automatiserade tester
bash ~/ansible/test/verify.sh
```

Avsluta control-VM:

```bash
# Logga ut fran control-VM
exit
```

### Kor Windows-tester (4 tester)

```powershell
# Kor 4 extra tester fran Windows-hosten
powershell -ExecutionPolicy Bypass -File ansible\test\verify_host.ps1
```

### Vad testerna bevisar

| Test | Vad det bevisar |
|------|----------------|
| T01-T02 | nginx fungerar och svarar |
| T03 | Round-robin lastbalansering fungerar |
| T04-T05 | Flask koer pa bada webbservrarna |
| T06 | Flask naar PostgreSQL (hela kedjan fungerar) |
| T07-T08 | web1 och web2 naar databasen |
| T09 | UFW-segmentering fungerar (nginx blockeras) |
| T10 | SSH-hardning fungerar |
| T11-T12 | fail2ban och auditd ar aktiva |
| T13 | Flask systemd-tjanst ar igaang |
| T14 | PostgreSQL lyssnar pa ratt IP |
| T15-T18 | Interna portar inte exponerade utifran |

---

## Designval och motivering

### Varfor control-VM istallet for Ansible fran laptopen?

Ansible stods inte officiellt pa Windows. Men det finns en
viktigare sakerhetssak: om du kor Ansible fran laptopen
ligger SSH-nycklarna pa samma maskin dar du surfar och
laser e-post.

Control-VM ar en separat sakerhetsgraans — minimal,
dedikerad, kan stangas av nar den inte anvands.

### Varfor Gunicorn istallet for Flasks inbyggda server?

| | Flasks dev-server | Gunicorn |
|--|--|--|
| Anvandare samtidigt | 1 | Manga |
| Felmeddelanden | Visas i webblasaren | Loggas internt |
| Produktion | Nej | Ja |
| Automatisk omstart | Nej | Ja (via systemd) |

### Varfor dynamisk upstream i nginx?

nginx.conf genereras fran groups["webservers"] i inventory
via Jinja2-template. Att lagga till web3 kraver bara en
rad i inventory — ingen kodandring i nginx.

```ini
# Lagg till i inventory.ini for att utoka med web3:
[webservers]
web1 ansible_host=192.168.56.12
web2 ansible_host=192.168.56.13
web3 ansible_host=192.168.56.15  # <- Bara den har raden
```

Kor sedan ansible-playbook site.yml — nginx uppdateras automatiskt.

### Varfor hypervisor (VirtualBox) istallet for containers (Docker)?

| | VirtualBox (hypervisor) | Docker (containers) |
|--|--|--|
| Isolering | Eget OS per VM | Delar karnan med hosten |
| Sakerhet | Starkare isolering | Karn-exploits paverkar alla |
| Realism | Som riktiga servrar | Som applikationsplattform |

For ett sakerhetsprojekt valjer vi VirtualBox — starkare
isolering och mer realistisk representation av produktionsmiljoer.

---

## Felsokning

### Problem: vagrant up hanger sig eller kraschar

Kontrollera status pa alla VMs:

```powershell
# Se status pa alla VMs
vagrant status
```

Starta om den VM som kranglar:

```powershell
# Stanga ner en specifik VM
vagrant halt control

# Starta den igen
vagrant up control
```

### Problem: ansible-playbook misslyckas

Kontrollera att Ansible nar alla noder:

```bash
# Testa anslutning till alla noder
ansible all -m ping
# Du ska se pong fran alla 4 noder
```

### Problem: localhost:8080 svarar inte

Kor om Ansible-konfigurationen:

```bash
# Kor om hela konfigurationen
ansible-playbook ~/ansible/site.yml
```

### Problem: db_status visar error i /info

Kontrollera att PostgreSQL koer:

```bash
# Kontrollera PostgreSQL-status pa databas-VM
ssh -i ~/.ssh/control_ed25519 vagrant@192.168.56.14 "systemctl status postgresql"
```

### Karning — borja om fran noll

Det fina med IaC ar att borja om tar bara 15 minuter:

```powershell
# Radera alla VMs
vagrant destroy -f

# Bygg upp allt fran noll
vagrant up
```

```powershell
# Logga in pa control-VM
vagrant ssh control
```

```bash
# Konfigurera alla servrar
ansible-playbook ~/ansible/site.yml

# Verifiera att allt fungerar
bash ~/ansible/test/verify.sh
```

> Om testerna visar 14/14 PASS ar du tillbaka till ett fungerande system.

---

## Ordlista

> Nar du ser (se Ordlista: X) i texten — leta upp begreppet har.

---

### IaC — Infrastructure as Code

Infrastructure as Code betyder att du beskriver din infrastruktur
i kodfiler istallet for att gora det manuellt.

Fordelar:
- Reproducerbart — vem som helst kan aterskapa miljon fran koden
- Versionshanterat — du ser exakt vad som andrades och nar
- Automatiserbart — CI/CD-system kan kora det automatiskt

📖 Las mer: https://www.hashicorp.com/resources/what-is-infrastructure-as-code

---

### Idempotens

Idempotens betyder att du kan kora samma operation hur manga
ganger som helst och alltid fa samma resultat.

```
# Exempel:
Korning 1: Installerar nginx, skapar anvandare, konfigurerar brandvaggen
Korning 2: Ser att nginx redan ar installerat --> gor ingenting
Korning 3: Ser att allt ar korrekt --> gor ingenting
```

📖 Las mer: https://docs.ansible.com/ansible/latest/reference_appendices/glossary.html

---

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

📖 Las mer: https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html

---

### Jinja2

Jinja2 ar en template-motor som later dig skapa textfiler
med platshallare som fylls i automatiskt.

```
# Exempel fran nginx.conf.j2:
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

📖 Las mer: https://jinja.palletsprojects.com/en/stable/

---

### Natverkssegmentering

Natverkssegmentering delar upp natverket i zoner med olika sakerhetsnivaer.

```
# Var tre zoner:
Zon 1 -- Publik:   nginx (.11) -- nabar utifran via port 8080
Zon 2 -- App:      web1 (.12), web2 (.13) -- nabar fran nginx
Zon 3 -- Databas:  database (.14) -- nabar BARA fran web1/web2
```

📖 Las mer: https://csrc.nist.gov/glossary/term/network_segmentation

---

### Omvand proxy (Reverse Proxy)

En omvand proxy tar emot forfragningar och vidarebefordrar
dem till backend-servrar. Klienten ser bara proxyn.

```
# Flode:
Klient --> nginx (proxy) --> Flask pa web1 eller web2
```

📖 Las mer: https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/

---

### Playbook

En Ansible-playbook beskriver vad som ska goras pa vilka
servrar i vilken ordning.

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

📖 Las mer: https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_intro.html

---

### Python

Python ar ett populart programmeringssprak kant for sin
lasbarhet. Flask ar skrivet i Python.

📖 Las mer: https://docs.python.org/3/

---

### Roll (Ansible Role)

En Ansible-roll ar en samling tasks och templates med ett
specifikt ansvar.

```
# Struktur for database-rollen:
roles/database/
+-- tasks/main.yml      # Vad som ska goras
+-- handlers/main.yml   # Vad som kors vid notify
+-- defaults/main.yml   # Standardvarden
+-- templates/          # Jinja2-templates
```

📖 Las mer: https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html

---

### Round-robin

Round-robin fordelar forfragningar i turordning.

```
# Hur round-robin fungerar:
Forfraagan 1 --> web1
Forfraagan 2 --> web2
Forfraagan 3 --> web1
Forfraagan 4 --> web2
```

📖 Las mer: https://docs.nginx.com/nginx/admin-guide/load-balancer/http-load-balancer/

---

### SSH — Secure Shell

SSH ar ett protokoll for att logga in pa en annan dator
sakert over natverket. All kommunikation ar krypterad.

```
# SSH-nycklar:
Privat nyckel --> ligger pa control-VM, far ALDRIG lamna den
Publik nyckel --> installeras pa alla noder

# Analogin:
Privat nyckel = din husnyckel
Publik nyckel = ditt las
```

📖 Las mer: https://www.openssh.com/manual.html

---

### systemd

systemd hanterar tjanster i Linux som ska kora kontinuerligt.

```ini
# Sakerhetsinstallningar i var flask.service:
Restart=always        # Startar om vid krasch
NoNewPrivileges=true  # Kan inte fa fler rattigheter
PrivateTmp=true       # Egen isolerad /tmp-mapp
```

📖 Las mer: https://systemd.io/

---

### UFW — Uncomplicated Firewall

UFW bestammer vilken natverkstrafik som tillats och
vilken som blockeras.

```
# UFW-regler pa database-VM:
Port 22  --> Tillat SSH fran alla
Port 5432 --> Tillat BARA fran web1 och web2
Allt annat --> Blockera
```

📖 Las mer: https://help.ubuntu.com/community/UFW

---

*README genererad som en del av examensprojektet i kursen
Virtualiseringsteknik och automation, YH Enkoping 2026.*
