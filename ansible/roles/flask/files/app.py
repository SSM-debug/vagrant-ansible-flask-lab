import os
import socket
from flask import Flask, jsonify
from datetime import datetime
import psycopg2

app = Flask(__name__)

DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_NAME = os.environ.get("DB_NAME", "flaskapp")
DB_USER = os.environ.get("DB_USER", "flaskuser")
DB_PASS = os.environ.get("DB_PASS", "changeme")

@app.route("/")
def index():
    return f"Hello from {socket.gethostname()}!"

@app.route("/health")
def health():
    return jsonify({"status": "ok", "host": socket.gethostname()})

@app.route("/info")
def info():
    try:
        conn = psycopg2.connect(
            host=DB_HOST, dbname=DB_NAME,
            user=DB_USER, password=DB_PASS
        )
        conn.close()
        db_status = "connected"
    except Exception as e:
        db_status = f"error: {str(e)}"

    return jsonify({
        "host": socket.gethostname(),
        "timestamp": datetime.utcnow().isoformat(),
        "db_status": db_status
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)