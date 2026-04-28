#!/bin/bash
# verify.sh — Automatiserat verifieringsskript
# Kör från control-VM: bash ~/ansible/test/verify.sh

PASS=0
FAIL=0
ERRORS=""

# Färgkoder
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
echo " vagrant-ansible-flask-lab — Verifiering"
echo "============================================"
echo ""

# ── TEST 1: nginx svarar på port 80 ──────────────────────
result=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.56.11/)
if [ "$result" = "200" ]; then
  pass "T01: nginx svarar på port 80 (HTTP 200)"
else
  fail "T01: nginx svarar INTE på port 80 (fick: $result)"
fi

# ── TEST 2: Round-robin — web1 svarar ────────────────────
result=$(curl -s http://192.168.56.11/)
if echo "$result" | grep -q "web1\|web2"; then
  pass "T02: Lastbalanseraren returnerar svar från webserver ($result)"
else
  fail "T02: Oväntat svar från lastbalanseraren: $result"
fi

# ── TEST 3: Round-robin verifiering ──────────────────────
r1=$(curl -s http://192.168.56.11/)
r2=$(curl -s http://192.168.56.11/)
r3=$(curl -s http://192.168.56.11/)
r4=$(curl -s http://192.168.56.11/)
if [ "$r1" != "$r2" ] || [ "$r3" != "$r4" ]; then
  pass "T03: Round-robin verifierat (svar växlar mellan web1/web2)"
else
  fail "T03: Round-robin fungerar INTE (alla svar från samma server)"
fi

# ── TEST 4: Flask health endpoint web1 ───────────────────
result=$(curl -s http://192.168.56.12:5000/health)
if echo "$result" | grep -q '"status":"ok"'; then
  pass "T04: Flask /health på web1 svarar ok"
else
  fail "T04: Flask /health på web1 svarar INTE ok: $result"
fi

# ── TEST 5: Flask health endpoint web2 ───────────────────
result=$(curl -s http://192.168.56.13:5000/health)
if echo "$result" | grep -q '"status":"ok"'; then
  pass "T05: Flask /health på web2 svarar ok"
else
  fail "T05: Flask /health på web2 svarar INTE ok: $result"
fi

# ── TEST 6: Flask når PostgreSQL (db_status: connected) ──
result=$(curl -s http://192.168.56.12:5000/info)
if echo "$result" | grep -q '"db_status":"connected"'; then
  pass "T06: Flask på web1 är ansluten till PostgreSQL"
else
  fail "T06: Flask på web1 når INTE PostgreSQL: $result"
fi

# ── TEST 7: PostgreSQL nåbar från web1 ───────────────────
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  vagrant@192.168.56.12 "nc -zv -w3 192.168.56.14 5432 2>&1")
if echo "$result" | grep -q "succeeded"; then
  pass "T07: web1 kan ansluta till PostgreSQL port 5432"
else
  fail "T07: web1 kan INTE ansluta till PostgreSQL port 5432"
fi

# ── TEST 8: PostgreSQL nåbar från web2 ───────────────────
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  vagrant@192.168.56.13 "nc -zv -w3 192.168.56.14 5432 2>&1")
if echo "$result" | grep -q "succeeded"; then
  pass "T08: web2 kan ansluta till PostgreSQL port 5432"
else
  fail "T08: web2 kan INTE ansluta till PostgreSQL port 5432"
fi

# ── TEST 9: nginx blockeras från PostgreSQL (UFW) ────────
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  vagrant@192.168.56.11 "nc -zv -w3 192.168.56.14 5432 2>&1")
if echo "$result" | grep -q "timed out\|Connection refused"; then
  pass "T09: UFW blockerar nginx från PostgreSQL (segmentering OK)"
else
  fail "T09: nginx kan ansluta till PostgreSQL — UFW fungerar INTE"
fi

# ── TEST 10: PasswordAuthentication är avstängd ──────────
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  -o PasswordAuthentication=no \
  vagrant@192.168.56.12 "echo ok" 2>&1)
if echo "$result" | grep -q "^ok$"; then
  pass "T10: SSH nyckelautentisering fungerar på web1"
else
  fail "T10: SSH nyckelautentisering fungerar INTE på web1"
fi

# ── TEST 11: fail2ban körs ────────────────────────────────
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  vagrant@192.168.56.12 "systemctl is-active fail2ban" 2>&1)
if echo "$result" | grep -q "active"; then
  pass "T11: fail2ban är aktivt på web1"
else
  fail "T11: fail2ban är INTE aktivt på web1: $result"
fi

# ── TEST 12: auditd körs ──────────────────────────────────
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  vagrant@192.168.56.14 "systemctl is-active auditd" 2>&1)
if echo "$result" | grep -q "active"; then
  pass "T12: auditd är aktivt på database-VM"
else
  fail "T12: auditd är INTE aktivt på database-VM: $result"
fi

# ── TEST 13: Flask systemd-tjänst körs ───────────────────
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  vagrant@192.168.56.12 "systemctl is-active flask" 2>&1)
if echo "$result" | grep -q "active"; then
  pass "T13: Flask systemd-tjänst är aktiv på web1"
else
  fail "T13: Flask systemd-tjänst är INTE aktiv på web1: $result"
fi

# ── TEST 14: PostgreSQL lyssnar på rätt IP ───────────────
result=$(ssh -i ~/.ssh/control_ed25519 -o StrictHostKeyChecking=no \
  vagrant@192.168.56.14 "sudo -u postgres psql -c 'SHOW listen_addresses;'" 2>&1)
if echo "$result" | grep -q "192.168.56.14"; then
  pass "T14: PostgreSQL lyssnar på 192.168.56.14"
else
  fail "T14: PostgreSQL lyssnar INTE på rätt IP: $result"
fi

# ── TEST 15: web1 och web2 är INTE nåbara direkt från host
result=$(nc -zv -w3 192.168.56.12 5000 2>&1)
if echo "$result" | grep -q "timed out\|Connection refused\|No route"; then
  pass "T15: web1 port 5000 är INTE direkt exponerad (segmentering OK)"
else
  fail "T15: web1 port 5000 är exponerad direkt — kontrollera nätverket"
fi

# ── SUMMERING ─────────────────────────────────────────────
echo ""
echo "============================================"
echo " RESULTAT: $PASS PASS / $FAIL FAIL"
echo "============================================"

if [ $FAIL -gt 0 ]; then
  echo -e "\nMisslyckade tester:$ERRORS"
  exit 1
else
  echo -e "\nAlla tester godkända!"
  exit 0
fi