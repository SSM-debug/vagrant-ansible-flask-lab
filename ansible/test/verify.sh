#!/bin/bash
# verify.sh â€” Automatiserat verifieringsskript
# KÃ¶r frÃ¥n control-VM: bash ~/ansible/test/verify.sh

PASS=0
FAIL=0
ERRORS=""

# FÃ¤rgkoder
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  - $1"
}

echo "============================================"
echo " vagrant-ansible-flask-lab â€” Verifiering"
echo "============================================"
echo ""

# â”€â”€ TEST 1: nginx svarar pÃ¥ port 80 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
result=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.56.11/)
if [ "$result" = "200" ]; then
  pass "T01: nginx svarar pÃ¥ port 80 (HTTP 200)"
else
  fail "T01: nginx svarar INTE pÃ¥ port 80 (fick: $result)"
fi

# â”€â”€ TEST 2: Round-robin â€” web1 svarar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
result=$(curl -s http://192.168.56.11/)
if echo "$result" | grep -q "web1\|web2"; then
  pass "T02: Lastbalanseraren returnerar svar frÃ¥n webserver ($result)"
else
  fail "T02: OvÃ¤ntat svar frÃ¥n lastbalanseraren: $result"
fi

# â”€â”€ TEST 3: Round-robin verifiering â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
r1=$(curl -s http://192.168.56.11/)
r2=$(curl -s http://192.168.56.11/)
r3=$(curl -s http://192.168.56.11/)
r4=$(curl -s http://192.168.56.11/)
if [ "$r1" != "$r2" ] || [ "$r3" != "$r4" ]; then
  pass "T03: Round-robin verifierat (svar vÃ¤xlar mellan web1/web2)"
else
  fail "T03: Round-robin fungerar INTE (alla svar frÃ¥n samma server)"
fi

# â”€â”€ TEST 4: Flask health endpoint web1 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
result=$(curl -s http://192.168.56.12:5000/health)
if echo "$result" | grep -q '"status":"ok"'; then
  pass "T04: Flask /health pÃ¥ web1 svarar ok"
else
  fail "T04: Flask /health pÃ¥ web1 svarar INTE ok: $result"
fi

# â”€â”€ TEST 5: Flask health endpoint web2 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
result=$(curl -s http://192.168.56.13:5000/health)
if echo "$result" | grep -q '"status":"ok"'; then
  pass "T05: Flask /health pÃ¥ web2 svarar ok"
else
  fail "T05: Flask /health pÃ¥ web2 svarar INTE ok: $result"
fi

# â”€â”€ TEST 6: Flask nÃ¥r PostgreSQL (db_status: connected) â”€â”€
result=$(curl -s http://192.168.56.12:5000/info)
if echo "$result" | grep -q '"db_status":"connected"'; then
  pass "T06: Flask pÃ¥ web1 Ã¤r ansluten till PostgreSQL"
else
  fail "T06: Flask pÃ¥ web1 nÃ¥r INTE PostgreSQL: $result"
fi

# â”€â”€ TEST 7: PostgreSQL nÃ¥bar frÃ¥n web1 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  vagrant@192.168.56.12 "nc -zv -w3 192.168.56.14 5432 2>&1")
if echo "$result" | grep -q "succeeded"; then
  pass "T07: web1 kan ansluta till PostgreSQL port 5432"
else
  fail "T07: web1 kan INTE ansluta till PostgreSQL port 5432"
fi

# â”€â”€ TEST 8: PostgreSQL nÃ¥bar frÃ¥n web2 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  vagrant@192.168.56.13 "nc -zv -w3 192.168.56.14 5432 2>&1")
if echo "$result" | grep -q "succeeded"; then
  pass "T08: web2 kan ansluta till PostgreSQL port 5432"
else
  fail "T08: web2 kan INTE ansluta till PostgreSQL port 5432"
fi

# â”€â”€ TEST 9: nginx blockeras frÃ¥n PostgreSQL (UFW) â”€â”€â”€â”€â”€â”€â”€â”€
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  vagrant@192.168.56.11 "nc -zv -w3 192.168.56.14 5432 2>&1")
if echo "$result" | grep -q "timed out\|Connection refused"; then
  pass "T09: UFW blockerar nginx frÃ¥n PostgreSQL (segmentering OK)"
else
  fail "T09: nginx kan ansluta till PostgreSQL â€” UFW fungerar INTE"
fi

# â”€â”€ TEST 10: PasswordAuthentication Ã¤r avstÃ¤ngd â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  -o PasswordAuthentication=no \
  vagrant@192.168.56.12 "echo ok" 2>&1)
if echo "$result" | grep -q "^ok$"; then
  pass "T10: SSH nyckelautentisering fungerar pÃ¥ web1"
else
  fail "T10: SSH nyckelautentisering fungerar INTE pÃ¥ web1"
fi

# â”€â”€ TEST 11: fail2ban kÃ¶rs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  vagrant@192.168.56.12 "systemctl is-active fail2ban" 2>&1)
if echo "$result" | grep -q "active"; then
  pass "T11: fail2ban Ã¤r aktivt pÃ¥ web1"
else
  fail "T11: fail2ban Ã¤r INTE aktivt pÃ¥ web1: $result"
fi

# â”€â”€ TEST 12: auditd kÃ¶rs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  vagrant@192.168.56.14 "systemctl is-active auditd" 2>&1)
if echo "$result" | grep -q "active"; then
  pass "T12: auditd Ã¤r aktivt pÃ¥ database-VM"
else
  fail "T12: auditd Ã¤r INTE aktivt pÃ¥ database-VM: $result"
fi

# â”€â”€ TEST 13: Flask systemd-tjÃ¤nst kÃ¶rs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  vagrant@192.168.56.12 "systemctl is-active flask" 2>&1)
if echo "$result" | grep -q "active"; then
  pass "T13: Flask systemd-tjÃ¤nst Ã¤r aktiv pÃ¥ web1"
else
  fail "T13: Flask systemd-tjÃ¤nst Ã¤r INTE aktiv pÃ¥ web1: $result"
fi

# â”€â”€ TEST 14: PostgreSQL lyssnar pÃ¥ rÃ¤tt IP â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  vagrant@192.168.56.14 "sudo -u postgres psql -c 'SHOW listen_addresses;'" 2>&1)
if echo "$result" | grep -q "192.168.56.14"; then
  pass "T14: PostgreSQL lyssnar pÃ¥ 192.168.56.14"
else
  fail "T14: PostgreSQL lyssnar INTE pÃ¥ rÃ¤tt IP: $result"
fi


# â”€â”€ SUMMERING â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
echo ""
echo "============================================"
echo " RESULTAT: $PASS PASS / $FAIL FAIL"
echo "============================================"

if [ $FAIL -gt 0 ]; then
  echo -e "\nMisslyckade tester:$ERRORS"
  exit 1
else
  echo -e "\nAlla tester godkÃ¤nda!"
  exit 0
fi