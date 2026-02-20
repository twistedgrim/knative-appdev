from datetime import datetime, timezone
from flask import Flask, jsonify, send_from_directory
import os

app = Flask(__name__, static_folder="static")
counter = 0


@app.get("/api/message")
def message():
    global counter
    counter += 1
    return jsonify(
        {
            "message": "Hello from Python backend",
            "counter": counter,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
    )


@app.get("/")
def index():
    return send_from_directory("static", "index.html")


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
