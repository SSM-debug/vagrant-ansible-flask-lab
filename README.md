# 🖥️ vagrant-ansible-flask-lab

![Status](https://img.shields.io/badge/Status-Klar-brightgreen)
![VMs](https://img.shields.io/badge/VMs-5-blue)
![Tests](https://img.shields.io/badge/Tester-18%2F18_PASS-brightgreen)
![Ansible](https://img.shields.io/badge/Ansible-2.10-red)
![Vagrant](https://img.shields.io/badge/Vagrant-2.4-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-orange)
![Kurs](https://img.shields.io/badge/YH_Enköping-IT--säkerhet-purple)

> Föreställ dig att du ska sätta upp fem servrar på ett företag — installera operativsystem, konfigurera nätverk, installera program och ställa in säkerhet. Traditionellt tar det dagar och massor av manuellt arbete. Om något går fel börjar du om från noll.
>
> Det här projektet gör allt det automatiskt. Du skriver **ett kommando**, och på 20 minuter har du en komplett, säkerhetsgranskad webbservermiljö med fem virtuella datorer — precis som i ett riktigt företag.

**⏱️ Tid att sätta upp:** ca 20-30 minuter
**👨‍💻 Författare:** Sushanta Shekhar Modak och Farhad Norman
**🎓 Kurs:** Virtualiseringsteknik och automation, YH Enköping

---

## 📋 Innehållsförteckning

| # | Sektion |
|---|---------|
| 1 | [🔧 Vad är verktygen?](#-vad-är-verktygen) |
| 2 | [🏗️ Arkitektur](#️-arkitektur) |
| 3 | [⚙️ Krav](#️-krav) |
| 4 | [🚀 Steg-för-steg installation](#-steg-för-steg-installation) |
| 5 | [🔒 Säkerhetsåtgärder](#-säkerhetsåtgärder) |
| 6 | [🛡️ Säkerhetsanalys STRIDE](#️-säkerhetsanalys-stride) |
| 7 | [✅ Verifiering](#-verifiering) |
| 8 | [💡 Designval och motivering](#-designval-och-motivering) |
| 9 | [🆘 Felsökningsguide](#-felsökningsguide) |
| 10 | [📖 Ordlista](#-ordlista) |

---

## ✨ Vad du får när projektet är klart

| ✅ | Funktion |
|----|----------|
| ✅ | En webbapplikation som körs på två servrar och lastbalanseras automatiskt |
| ✅ | En isolerad databasserver som bara applikationsservrarna når |
| ✅ | Automatisk säkerhetshärdning på alla servrar |
| ✅ | 18 automatiserade tester som bevisar att allt fungerar |


## 🔧 Vad är verktygen?

> 💡 Hoppa gärna förbi det här om du redan vet vad verktygen gör. Alla tekniska begrepp som dyker upp i README förklaras i [📖 Ordlistan](#-ordlista).

### 🖥️ VirtualBox — din "dator i datorn"

VirtualBox låter dig skapa virtuella datorer inuti din riktiga dator. Tänk dig att du har fem laptops inuti din laptop — var och en med eget operativsystem, eget nätverk och egna program.

Vi använder VirtualBox för att skapa fem virtuella Ubuntu-servrar som pratar med varandra via ett privat nätverk.

### 📦 Vagrant — automatisk skapare av virtuella datorer

Istället för att klicka ihop virtuella datorer manuellt i VirtualBox, beskriver du dem i en textfil som heter Vagrantfile. Vagrant läser filen och skapar allt automatiskt.

**🍳 Analogin:** Vagrant är som ett recept. VirtualBox är köket. Du följer receptet och får samma rätt varje gång — oavsett vem som lagar den.

| | Utan Vagrant | Med Vagrant |
|--|--|--|
| Tid | 45 min manuellt per server | vagrant up — klart på 15 min |
| Repeterbarhet | Olika varje gång | Identiskt varje gång |
| Felsökning | Börja om manuellt | vagrant destroy && vagrant up |

Det här kallas **IaC (Infrastructure as Code)** *(→ [Ordlista: IaC](#iac--infrastructure-as-code))* — infrastruktur beskriven som kod istället för manuella steg.

### 🤖 Ansible — automatisk serverkonfigurerare

När dina virtuella datorer är skapade behöver de konfigureras — installera program, skapa användare, ställa in brandväggen. Ansible gör det automatiskt via **SSH** *(→ [Ordlista: SSH](#ssh--secure-shell))*.

Du skriver vad du vill ha (inte hur), och Ansible räknar ut hur det ska göras — och gör det på alla servrar samtidigt. Det kallas **idempotens** *(→ [Ordlista: Idempotens](#idempotens))*.

> 🔑 **Viktigt:** Ansible organiserar sitt arbete i **roller** *(→ [Ordlista: Roll](#roll-ansible-role))* och **playbooks** *(→ [Ordlista: Playbook](#playbook))*.

**🔧 Analogin:** Ansible är som en servicetekniker som följer en checklista. Du ger hen checklistan, hen fixar allt på alla maskiner — utan att du behöver vara med.

| | Utan Ansible | Med Ansible |
|--|--|--|
| Metod | Logga in på 5 servrar manuellt | Ett kommando |
| Tid | Timmar | 5 minuter |
| Risk | Lätt att missa något | Alltid identiskt |

### 🐍 Flask — webbapplikationen

Flask är ett minimalt **Python** *(→ [Ordlista: Python](#python))*-webbramverk. Vår applikation tar emot webbförfrågningar, hämtar data från databasen och svarar tillbaka.

**Vår app har tre endpoints:**

| Endpoint | Vad den gör |
|----------|------------|
| / | Returnerar Hello from web1! eller Hello from web2! |
| /health | Returnerar status ok — används av nginx |
| /info | Returnerar JSON med databas-status och timestamp |

### ⚡ Gunicorn — produktionswebbservern

Flask har en inbyggd webbserver, men den är bara för utveckling — den hanterar en användare i taget och visar felmeddelanden i webbläsaren.

Gunicorn är en riktig produktionsserver som hanterar många användare samtidigt. Vi kör Gunicorn som en **systemd** *(→ [Ordlista: systemd](#systemd))*-tjänst.

| | Flasks dev-server | Gunicorn |
|--|--|--|
| Användare samtidigt | 1 | Många (flera workers) |
| Felmeddelanden | Visas i webbläsaren ⚠️ | Loggas internt ✅ |
| Vid krasch | Stannar nere | Startar om automatiskt ✅ |

**🪑 Analogin:** Flasks dev-server är en hemmasnickrad pall. Gunicorn är stolen som tål att stå i ett kafé hela dagen.

### 🔀 nginx — lastbalanseraren

nginx (uttalas "engine-x") fungerar som en trafikpolis för webbtrafik.

**Som lastbalanserare:** nginx tar emot all trafik utifrån och bestämmer vilken server som ska svara — web1 eller web2 via **round-robin** *(→ [Ordlista: Round-robin](#round-robin))*.

**Som omvänd proxy** *(→ [Ordlista: Omvänd proxy](#omvänd-proxy-reverse-proxy))*: nginx vidarebefordrar förfrågningar från port 80 till Flask på port 5000.

nginx-konfigurationen genereras automatiskt från en **Jinja2-template** *(→ [Ordlista: Jinja2](#jinja2))*.

**🏥 Analogin:** Tänk på nginx som receptionen på ett sjukhus. Alla patienter går in genom receptionen. Receptionen bestämmer vilken läkare som tar nästa patient.

### 🗄️ PostgreSQL — databasen

PostgreSQL är en relationsdatabas där vår applikation sparar och hämtar data. Den körs på en helt separat server och är bara nåbar från web1 och web2.

---

## 🏗️ Arkitektur — så här ser systemet ut

> 💡 Läs igenom den här sektionen innan du börjar installera — då förstår du varför varje steg görs.

\Din Windows-laptop
       |
       | Port 8080 — enda ingångspunkten utifrån
       |
+------+--------------------------------------------+
|         Privat nätverk 192.168.56.0/24             |
|                                                     |
|   +--------------------+                           |
|   |  🔀 nginx          |  192.168.56.11            |
|   |  Lastbalanserare   |  <- All trafik hit först  |
|   +--------+-----------+                           |
|            |                                       |
|            | Fördelar jämnt (round-robin)           |
|      +-----+------+                                |
|      v            v                                |
|  +-------+    +-------+                            |
|  |🐍 web1|    |🐍 web2|                            |
|  | .12   |    | .13   |                            |
|  | Flask |    | Flask |                            |
|  +---+---+    +---+---+                            |
|      +-----------+                                 |
|            |                                       |
|            | Bara web1 och web2 får ansluta        |
|   +--------v-----------+                           |
|   |  🗄️ database       |  192.168.56.14            |
|   |  PostgreSQL        |  🔒 UFW blockerar andra   |
|   +--------------------+                           |
|                                                    |
|   +--------------------+                           |
|   |  🤖 control        |  192.168.56.10            |
|   |  Ansible-kontroll  |  Hanterar alla noder      |
|   +--------------------+                           |
+----------------------------------------------------+
\
### 🔄 Vad händer när du besöker http://localhost:8080/?

\Steg 1: Din webbläsare skickar förfrågan till port 8080 på din laptop
Steg 2: Port forwarding vidarebefordrar den till nginx port 80
Steg 3: nginx bestämmer — web1 eller web2? (round-robin)
Steg 4: Vald server kör Flask och frågar databasen om det behövs
Steg 5: Svaret åker tillbaka samma väg och visas i webbläsaren
\
> ⚡ Hela resan tar under en millisekund.

### 📊 IP-adresser och resurser

| VM | Roll | IP-adress | RAM |
|---|---|---|---|
| 🤖 control | Ansible-kontroll | 192.168.56.10 | 512 MB |
| 🔀 nginx | Lastbalanserare | 192.168.56.11 | 512 MB |
| 🐍 web1 | Flask + Gunicorn | 192.168.56.12 | 512 MB |
| 🐍 web2 | Flask + Gunicorn | 192.168.56.13 | 512 MB |
| 🗄️ database | PostgreSQL | 192.168.56.14 | 768 MB |

> 💾 **Totalt RAM-användning:** ~3 GB. Du behöver minst 8 GB RAM.

### 🔒 Säkerhetsdesignen förklarad

**Varför har bara nginx port forwarding?**
web1, web2 och database är helt osynliga utifrån. En angripare kan nå nginx — men inte databasen direkt.

**Varför får inte nginx prata med databasen?**
**UFW** *(→ [Ordlista: UFW](#ufw--uncomplicated-firewall))* på databasservern tillåter bara anslutningar från web1 (.12) och web2 (.13). Det kallas **nätverkssegmentering** *(→ [Ordlista: Nätverkssegmentering](#nätverkssegmentering))*.

**Varför kör vi Ansible från control-VM?**
Om du kör Ansible från laptopen ligger SSH-nycklarna på samma dator där du surfar och läser e-post. Control-VM är en separat säkerhetsdomän.

<details>
<summary>📁 Klicka här för att se mappstrukturen</summary>

\vagrant-ansible-flask-lab/
│
├── 📂 vagrant/
│   ├── Vagrantfile          <- Beskriver alla 5 VMs
│   └── secrets.yml          <- GITIGNORERAD — dina lösenord
│
├── 📂 ansible/
│   ├── ansible.cfg          <- Ansible-konfiguration
│   ├── inventory.ini        <- Lista på alla servrar
│   ├── site.yml             <- Master-playbook
│   ├── secrets_example.yml  <- Mall för secrets.yml
│   │
│   ├── 📂 roles/
│   │   ├── database/        <- PostgreSQL + UFW
│   │   ├── flask/           <- Flask + Gunicorn
│   │   ├── nginx/           <- Lastbalanseraren
│   │   └── security_hardening/ <- SSH + fail2ban + auditd
│   │
│   └── 📂 test/
│       ├── verify.sh        <- 14 tester (Linux)
│       └── verify_host.ps1  <- 4 tester (Windows)
│
├── 📂 docs/
├── .gitignore
└── README.md
\
</details>

---

## ⚙️ Krav

Innan du börjar — se till att du har följande installerat på din Windows-dator.

### 📥 Program du behöver installera

| Program | Version | Ladda ner från |
|---------|---------|----------------|
| VirtualBox | 7.x | [virtualbox.org](https://www.virtualbox.org/) |
| Vagrant | 2.x | [vagrantup.com](https://www.vagrantup.com/) |
| Git | Senaste | [git-scm.com](https://git-scm.com/) |

### 💻 Hårdvarukrav

| Krav | Minimum |
|------|---------|
| RAM | 8 GB (projektet använder ~3 GB) |
| Diskutrymme | 20 GB ledigt |
| Operativsystem | Windows 10 eller nyare |

### ✅ Verifiera att allt är installerat

Öppna PowerShell och kör dessa kommandon ett i taget:

\\powershell
VBoxManage --version
\Du ska se något i stil med: 7.x.x

\\powershell
vagrant --version
\Du ska se: Vagrant 2.x.x

\\powershell
git --version
\Du ska se: git version 2.x.x

> ⚠️ **Om något saknas** — installera det från länkarna ovan och kör kommandot igen.

---

## 🚀 Steg-för-steg installation

> 💡 Följ varje steg i ordning. Hoppa inte över något — varje steg beror på det föregående.

---

### 📥 Steg 1 — Klona projektet till din dator

**Vad vi gör:** Vi laddar ner projektet från GitHub till din dator. Det kallas att "klona" ett repo.

**Varför:** Alla projektfiler — Vagrantfile, Ansible-roller, tester — behöver finnas lokalt på din dator.

Öppna PowerShell och navigera till en lämplig mapp. Vi rekommenderar:

\\powershell
cd F:\Projects
\
> ⚠️ **Undvik OneDrive-mappar!** OneDrive synkar filer i bakgrunden och kan låsa filer mitt i en vagrant up, vilket ger konstiga fel.

Klona projektet:

\\powershell
git clone https://github.com/SSM-debug/vagrant-ansible-flask-lab.git
\
Du ska se något i stil med:
\Cloning into vagrant-ansible-flask-lab...
remote: Counting objects: done.
\
Gå in i projektmappen:

\\powershell
cd vagrant-ansible-flask-lab
\
Du ska nu se:
\PS F:\Projectsagrant-ansible-flask-lab>
\
---

### 🔐 Steg 2 — Skapa din secrets-fil

**Vad vi gör:** Vi skapar en lokal fil med lösenord till databasen.

**Varför:** Lösenord får aldrig ligga i koden på GitHub — botar scannar GitHub konstant och hittar lösenord inom minuter. Filen secrets.yml är gitignorerad och finns aldrig i repot.

Kopiera mallen:

\\powershell
copy ansible\secrets_example.yml vagrant\secrets.yml
\
Öppna filen i Notepad:

\\powershell
notepad vagrant\secrets.yml
\
Filen ser ut så här — byt ut platshållarna mot riktiga värden:

\\yaml
db_name: "flaskapp"
db_user: "flaskuser"
db_password: "ValjEttStarktLosenord123!"
flask_secret_key: "en-lang-hemlig-nyckel-som-ingen-ska-se"
\
Spara och stäng Notepad.

> ✅ **Kontrollera:** secrets.yml ska INTE synas när du kör git status. Om den syns — stoppa och kontakta oss.

---

### 🖥️ Steg 3 — Starta de virtuella datorerna

**Vad vi gör:** Vi startar alla 5 virtuella datorer med ett enda kommando.

**Varför:** Vagrant läser Vagrantfile och skapar alla VMs automatiskt. Första gången laddas Ubuntu-systemet ner (~500 MB).

Gå till vagrant-mappen:

\\powershell
cd vagrant
\
Starta alla VMs:

\\powershell
vagrant up
\
> ⏱️ **Det här tar 10-15 minuter** första gången. Du ser massor av text rulla förbi — det är normalt. Vagrant berättar vad den gör.

När det är klart ser du:
\==> control: === Ansible control node ready ===
\
Verifiera att alla VMs är uppe:

\\powershell
vagrant status
\
Du ska se:
\control    running (virtualbox)
nginx      running (virtualbox)
web1       running (virtualbox)
web2       running (virtualbox)
database   running (virtualbox)
\
> ⚠️ **Om en VM inte startar** — kör agrant up <vm-namn> för att starta bara den som krånglar. Se [Felsökningsguide](#-felsökningsguide) för mer hjälp.

---

### 🤖 Steg 4 — Konfigurera alla servrar med Ansible

**Vad vi gör:** Vi kör Ansible-playbooken som installerar och konfigurerar Flask, nginx, PostgreSQL och säkerhetsprogramvara på rätt servrar.

**Varför:** Vagrant skapade servrarna — men de är tomma Ubuntu-installationer. Ansible fyller dem med rätt program och inställningar.

SSH in på control-VM — den server som kör Ansible:

\\powershell
vagrant ssh control
\
Du ska nu se en Linux-prompt:
\vagrant@control:~$
\
Kör master-playbooken *(→ [Ordlista: Playbook](#playbook))*:

\\ash
ansible-playbook ~/ansible/site.yml
\
> ⏱️ **Det här tar 5-10 minuter.** Du ser Ansible arbeta sig igenom varje server — installera program, konfigurera tjänster, ställa in brandväggen.

När det är klart ser du PLAY RECAP:
\database : ok=XX  failed=0
nginx    : ok=XX  failed=0
web1     : ok=XX  failed=0
web2     : ok=XX  failed=0
\
> ✅ **ailed=0 på alla noder = allt gick bra!**
> ⚠️ **Om du ser ailed=1** — läs felmeddelandet och se [Felsökningsguide](#-felsökningsguide).

---

### ✅ Steg 5 — Verifiera att systemet fungerar

**Vad vi gör:** Vi kör ett automatiserat testskript som kontrollerar att allt fungerar korrekt.

**Varför:** Ansible kan säga "ok" utan att systemet faktiskt fungerar. Testerna kontrollerar det verkliga utfallet — att nginx svarar, att Flask når databasen, att brandväggen blockerar rätt trafik.

Kvar inne på control-VM, kör verifieringsskriptet:

\\ash
bash ~/ansible/test/verify.sh
\
Du ska se 14 gröna PASS-rader:
\[PASS] T01: nginx svarar på port 80 (HTTP 200)
[PASS] T02: Lastbalanseraren returnerar svar
[PASS] T03: Round-robin verifierat
...
RESULTAT: 14 PASS / 0 FAIL
Alla tester godkända!
\
Avsluta control-VM:

\\ash
exit
\
Kör Windows-testerna:

\\powershell
powershell -ExecutionPolicy Bypass -File ..nsible	esterify_host.ps1
\
Du ska se:
\[PASS] T15: nginx reachable via port forwarding :8080
[PASS] T16: nginx port 80 NOT exposed on host
[PASS] T17: PostgreSQL NOT exposed via port forwarding
[PASS] T18: Flask port 5000 NOT exposed via port forwarding
RESULT: 4 PASS / 0 FAIL
\
---

### 🌐 Steg 6 — Testa i webbläsaren

**Vad vi gör:** Vi öppnar systemet i webbläsaren och ser round-robin i aktion.

Öppna din webbläsare och gå till:

\http://localhost:8080/
\
Du ska se: Hello from web1!

Ladda om sidan (F5) — du ska nu se: Hello from web2!

Ladda om igen — Hello from web1!

> 🎉 **Det här är round-robin lastbalansering i aktion!** nginx fördelar trafiken jämnt mellan web1 och web2.

**Testa de andra endpoints:**

| URL | Förväntat svar |
|-----|---------------|
| http://localhost:8080/ | Hello from web1! eller web2! |
| http://localhost:8080/health | {"status": "ok", "host": "web1"} |
| http://localhost:8080/info | JSON med db_status: connected |

> ✅ **Om du ser "db_status": "connected" i /info** — Flask pratar med PostgreSQL. Hela kedjan fungerar!

---

### 🔄 Steg 7 — Testa reproducerbarhet (VG-krav)

**Vad vi gör:** Vi förstör hela miljön och bygger upp den från noll — för att bevisa att allt är automatiserat.

**Varför:** Det här är ett av de viktigaste VG-kraven: "destroy && up ger identisk miljö". Det bevisar att infrastrukturen verkligen är kod — inte manuellt arbete.

\\powershell
vagrant destroy -f
\
Du ser att alla VMs stängs av och raderas.

Bygg upp allt från noll:

\\powershell
vagrant up
\
SSH in och kör Ansible igen:

\\powershell
vagrant ssh control
\
\\ash
ansible-playbook ~/ansible/site.yml
bash ~/ansible/test/verify.sh
\
> ✅ **Om du ser 14/14 PASS igen** — infrastrukturen är fullt reproducerbar. Det är Infrastructure as Code i praktiken.

---

## 🔒 Säkerhetsåtgärder

Alla säkerhetsåtgärder appliceras automatiskt av Ansible-rollen security_hardening på samtliga 4 noder.

### 🛡️ SSH-härdning

Konfigurerad i nsible/roles/security_hardening/templates/sshd_config.j2

| Inställning | Värde | Vad det skyddar mot |
|------------|-------|---------------------|
| PasswordAuthentication | no | Credential stuffing, brute force |
| PermitRootLogin | no | Direkt root-åtkomst |
| AllowUsers | vagrant | Obehöriga konton |
| MaxAuthTries | 3 | Automatiserade inloggningsförsök |

> 🔑 Med PasswordAuthentication no spelar det ingen roll om en angripare har en lista med miljoner stulna lösenord — SSH accepterar bara nycklar.

### 🚫 fail2ban — automatisk IP-blockering

Installerat på alla 4 noder. När någon misslyckas med SSH-inloggning **5 gånger inom 10 minuter** blockeras deras IP-adress automatiskt i 10 minuter.

\Angripare försöker logga in → 5 misslyckanden → IP blockeras i 600 sekunder
\
### 📋 auditd — filsystemövervakning

Loggar automatiskt när någon läser eller ändrar känsliga filer:

| Fil | Varför den övervakas |
|-----|---------------------|
| /etc/passwd | Användarkonton |
| /etc/shadow | Lösenordshashes |
| /etc/sudoers | Sudo-rättigheter |
| ~/.ssh/ | SSH-nycklar |

### 🔥 UFW — nätverksbrandvägg

*(→ [Ordlista: UFW](#ufw--uncomplicated-firewall))*

\På database-VM:
✅ Port 22  (SSH)        → Tillåt från alla
✅ Port 5432 (PostgreSQL) → Tillåt BARA från 192.168.56.12 och .13
❌ Allt annat            → Blockera
\
### 🎯 Principle of Least Privilege

Flask ansluter till PostgreSQL som laskuser — inte som postgres (superanvändaren).

\\sql
-- flaskuser har BARA dessa rättigheter:
GRANT SELECT, INSERT, UPDATE, DELETE ON applikationens tabeller TO flaskuser;
-- Ingen CREATE, DROP, SUPERUSER, CREATEDB
\
En SQL-injection-attack kan inte ta över hela databasservern — bara läsa/skriva i Flasks egna tabeller.

### ⚙️ systemd-härdning

Flask/Gunicorn körs med extra säkerhetsinställningar:

\\ini
NoNewPrivileges=true  # Kan inte skaffa sig fler rättigheter
PrivateTmp=true       # Egen isolerad /tmp-mapp
Restart=always        # Startar om automatiskt vid krasch
\
---

## 🛡️ Säkerhetsanalys STRIDE

STRIDE är ett ramverk för hotmodellering med sex kategorier. Vi tittar på arkitekturen från sex vinklar och frågar: *"hur kan just det här gå sönder?"*

| Hot | Var i vår arkitektur | Konsekvens | Vår åtgärd |
|-----|---------------------|------------|------------|
| 🎭 S - Spoofing | SSH-nycklar på control-VM | Angripare loggar in som legitim admin | PasswordAuthentication no, AllowUsers vagrant |
| ✏️ T - Tampering | /opt/flask/app.py på web1/web2 | Bakdörr eller omdirigering av trafik | Ansible återställer från Git, NoNewPrivileges |
| 🙈 R - Repudiation | Alla noder, särskilt control | Ingen kan bevisa vem som gjorde vad | journald, auditd, PostgreSQL audit-logging |
| 👁️ I - Information Disclosure | secrets.yml, miljövariabler | Lösenord hamnar hos angripare | secrets.yml gitignorerad, 0600-rättigheter |
| 💥 D - Denial of Service | nginx (Single Point of Failure) | Hela systemet nere vid nginx-krasch | systemd Restart=always, rate limiting |
| ⬆️ E - Elevation of Privilege | Flask → PostgreSQL via SQL-injection | Angripare får superuser → OS-access | flaskuser utan superuser-rättigheter |

### ⚠️ Kända kvarvarande brister

> Att känna till sina svagheter är lika viktigt som att implementera skydd.

| # | Brist | Konsekvens | Lösning i produktion |
|---|-------|------------|---------------------|
| 1 | nginx är en Single Point of Failure | Hela systemet nere vid krasch | Keepalived/VRRP för automatisk failover |
| 2 | Lösenord synliga i miljövariabler (ps auxe) | Lösenord läcker via processlistning | HashiCorp Vault för runtime-injection |
| 3 | host-only nätverk nås från Windows-hosten | VMs inte fullt isolerade | intnet istället för private_network |
| 4 | secrets.yml i klartext på disk | Lösenord läsbart om disk komprometteras | ansible-vault encrypt secrets.yml |

---

## ✅ Verifiering

### 🖥️ Kör alla tester från control-VM (14 tester)

SSH in på control-VM:

\\powershell
vagrant ssh control
\
Kör verifieringsskriptet:

\\ash
bash ~/ansible/test/verify.sh
\
Du ska se:
\[PASS] T01: nginx svarar på port 80 (HTTP 200)
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
\
Avsluta control-VM:

\\ash
exit
\
### 💻 Kör Windows-tester (4 tester)

\\powershell
powershell -ExecutionPolicy Bypass -File ansible	esterify_host.ps1
\
Du ska se:
\[PASS] T15: nginx reachable via port forwarding :8080
[PASS] T16: nginx port 80 NOT exposed on host
[PASS] T17: PostgreSQL NOT exposed via port forwarding
[PASS] T18: Flask port 5000 NOT exposed via port forwarding

RESULT: 4 PASS / 0 FAIL
\
### 📊 Vad testerna bevisar

| Test | Vad det bevisar |
|------|----------------|
| T01-T02 | nginx fungerar och svarar |
| T03 | Round-robin lastbalansering fungerar |
| T04-T05 | Flask körs på båda webbservrarna |
| T06 | Flask når PostgreSQL (hela kedjan fungerar) |
| T07-T08 | web1 och web2 når databasen |
| T09 | UFW-segmentering fungerar (nginx blockeras) |
| T10 | SSH-härdning fungerar |
| T11-T12 | fail2ban och auditd är aktiva |
| T13 | Flask systemd-tjänst är igång |
| T14 | PostgreSQL lyssnar på rätt IP |
| T15-T18 | Interna portar inte exponerade utifrån |

---

## 💡 Designval och motivering

### Varför control-VM istället för Ansible från laptopen?

Ansible stöds inte officiellt på Windows. Men det finns en viktigare säkerhetsorsak: om du kör Ansible från laptopen ligger SSH-nycklarna på samma maskin där du surfar och läser e-post.

Control-VM är en separat säkerhetsdomän — minimal, dedikerad, kan stängas av när den inte används. Om laptopen hackades når angriparen inte servrarna automatiskt.

### Varför Gunicorn istället för Flasks inbyggda server?

| | Flasks dev-server | Gunicorn |
|--|--|--|
| Användare samtidigt | 1 | Många |
| Felmeddelanden | Visas i webbläsaren ⚠️ | Loggas internt ✅ |
| Produktion | Nej | Ja |
| Automatisk omstart | Nej | Ja (via systemd) |

### Varför dynamisk upstream i nginx?

nginx.conf genereras från groups["webservers"] i inventory via Jinja2-template. Att lägga till web3 kräver bara en rad i inventory — ingen kodändring i nginx.

\\ini
# Lägg till i inventory.ini:
[webservers]
web1 ansible_host=192.168.56.12
web2 ansible_host=192.168.56.13
web3 ansible_host=192.168.56.15  # <- Bara den här raden
\
Kör sedan nsible-playbook site.yml — nginx uppdateras automatiskt.

### Varför hypervisor (VirtualBox) istället för containers (Docker)?

| | VirtualBox (hypervisor) | Docker (containers) |
|--|--|--|
| Isolering | Eget OS per VM | Delar kärnan med hosten |
| RAM-användning | Mer | Lite |
| Säkerhet | Starkare isolering | Kärn-exploits påverkar alla |
| Realism | Som riktiga servrar | Som applikationsplattform |

För ett säkerhetsprojekt väljer vi VirtualBox — starkare isolering och mer realistisk representation av produktionsmiljöer.

---

## 🆘 Felsökningsguide

### Problem: vagrant up hänger sig eller kraschar

**Symptom:** En VM startar inte eller tar för lång tid.

Kontrollera status:
\\powershell
vagrant status
\
Starta om den VM som krånglar:
\\powershell
vagrant halt <vm-namn>
vagrant up <vm-namn>
\
### Problem: ansible-playbook misslyckas

**Symptom:** Du ser ailed=1 i PLAY RECAP.

Kontrollera att alla VMs är uppe:
\\ash
ansible all -m ping
\
Du ska se pong från alla 4 noder. Om inte — gå tillbaka till PowerShell och kör agrant status.

### Problem: curl localhost:8080 svarar inte

**Symptom:** Ingen respons från nginx.

Kör om Ansible-konfigurationen:
\\ash
ansible-playbook ~/ansible/site.yml
\
### Problem: db_status visar "error" i /info

**Symptom:** Flask når inte PostgreSQL.

Kontrollera att PostgreSQL körs:
\\ash
ssh -i ~/.ssh/control_ed25519 vagrant@192.168.56.14 "systemctl status postgresql"
\
### 🔄 Kärnlösning — börja om från noll

Det fina med IaC är att börja om tar bara 15 minuter:

\\powershell
cd vagrant
vagrant destroy -f
vagrant up
\
\\ash
vagrant ssh control
ansible-playbook ~/ansible/site.yml
bash ~/ansible/test/verify.sh
\
> ✅ Om testerna visar 14/14 PASS är du tillbaka till ett fungerande system.

---

## 📖 Ordlista

> 💡 När du ser *(→ Ordlista: X)* i texten — leta upp begreppet här.

---

### IaC — Infrastructure as Code

Infrastructure as Code betyder att du beskriver din infrastruktur i kodfiler istället för att göra det manuellt.

**Fördelar:**
- ♻️ Reproducerbart — vem som helst kan återskapa miljön från koden
- 📝 Versionshanterat — du ser exakt vad som ändrades och när
- 🤖 Automatiserbart — CI/CD-system kan köra det automatiskt

📖 **Läs mer:** [What is Infrastructure as Code? — HashiCorp](https://www.hashicorp.com/resources/what-is-infrastructure-as-code)

---

### Idempotens

Idempotens betyder att du kan köra samma operation hur många gånger som helst och alltid få samma resultat.

\Körning 1: Installerar nginx, skapar användare, konfigurerar brandväggen
Körning 2: Ser att nginx redan är installerat → gör ingenting
Körning 3: Ser att allt är korrekt → gör ingenting
\
📖 **Läs mer:** [Ansible — Idempotency](https://docs.ansible.com/ansible/latest/reference_appendices/glossary.html)

---

### Inventory

En Ansible inventory-fil listar alla servrar och organiserar dem i grupper.

\\ini
[lb]
nginx ansible_host=192.168.56.11

[webservers]
web1 ansible_host=192.168.56.12
web2 ansible_host=192.168.56.13

[db]
database ansible_host=192.168.56.14
\
📖 **Läs mer:** [Ansible Inventory](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html)

---

### Jinja2

Jinja2 är en template-motor som låter dig skapa textfiler med platshållare som fylls i automatiskt.

\upstream backend {
{% for host in groups["webservers"] %}
    server {{ hostvars[host]["ansible_host"] }}:5000;
{% endfor %}
}
\
Genererar automatiskt rätt konfiguration baserat på inventory.

📖 **Läs mer:** [Jinja2 dokumentation](https://jinja.palletsprojects.com/en/stable/)

---

### Nätverkssegmentering

Nätverkssegmentering delar upp nätverket i zoner med olika säkerhetsnivåer.

\Zon 1 — Publik:      nginx (.11) — nåbar utifrån
Zon 2 — App:         web1 (.12), web2 (.13) — nåbar från nginx
Zon 3 — Databas:     database (.14) — nåbar BARA från web1/web2
\
📖 **Läs mer:** [Network Segmentation — NIST](https://csrc.nist.gov/glossary/term/network_segmentation)

---

### Omvänd proxy (Reverse Proxy)

En omvänd proxy tar emot förfrågningar och vidarebefordrar dem till backend-servrar. Klienten ser bara proxyn.

\Klient → nginx (proxy) → Flask på web1 eller web2
\
📖 **Läs mer:** [nginx Reverse Proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)

---

### Playbook

En Ansible-playbook beskriver vad som ska göras på vilka servrar i vilken ordning.

\\yaml
- name: Configure database server
  hosts: db
  roles:
    - database
\
📖 **Läs mer:** [Ansible Playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_intro.html)

---

### Python

Python är ett populärt programmeringsspråk. Flask är skrivet i Python.

📖 **Läs mer:** [Python dokumentation](https://docs.python.org/3/)

---

### Roll (Ansible Role)

En Ansible-roll är en samling tasks och templates med ett specifikt ansvar.

\roles/database/
├── tasks/main.yml      <- Vad som ska göras
├── handlers/main.yml   <- Vad som körs vid notify
├── defaults/main.yml   <- Standardvärden
└── templates/          <- Jinja2-templates
\
📖 **Läs mer:** [Ansible Roles](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html)

---

### Round-robin

Round-robin fördelar förfrågningar i turordning.

\Förfrågan 1 → web1
Förfrågan 2 → web2
Förfrågan 3 → web1
Förfrågan 4 → web2
\
📖 **Läs mer:** [nginx Load Balancing](https://docs.nginx.com/nginx/admin-guide/load-balancer/http-load-balancer/)

---

### SSH — Secure Shell

SSH är ett protokoll för att logga in på en annan dator säkert. All kommunikation är krypterad.

\Privat nyckel → ligger på control-VM, får ALDRIG lämna den
Publik nyckel → installeras på alla noder
\
📖 **Läs mer:** [OpenSSH dokumentation](https://www.openssh.com/manual.html)

---

### systemd

systemd hanterar tjänster i Linux som ska köras kontinuerligt.

\\ini
Restart=always        # Startar om vid krasch
NoNewPrivileges=true  # Kan inte få fler rättigheter
PrivateTmp=true       # Egen isolerad /tmp-mapp
\
📖 **Läs mer:** [systemd dokumentation](https://systemd.io/)

---

### UFW — Uncomplicated Firewall

UFW bestämmer vilken nätverkstrafik som tillåts och vilken som blockeras.

\✅ Port 22  → Tillåt SSH från alla
✅ Port 5432 → Tillåt BARA från web1 och web2
❌ Allt annat → Blockera
\
📖 **Läs mer:** [UFW — Ubuntu dokumentation](https://help.ubuntu.com/community/UFW)

---

*README genererad som en del av examensprojektet i kursen Virtualiseringsteknik och automation, YH Enköping 2026.*
