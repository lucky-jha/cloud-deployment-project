from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.get("/")
def home():
    return jsonify(
        message="Hello from lucky jha using flask",
        platform="Github Actions",
        runtime="Docker + Flask"
    )

@app.get("/health")
def health():
    return jsonify(status="healthy"), 200

@app.get("/version")
def version():
    return jsonify(
        version=os.environ.get("APP_VERSION", "dev"),
        build=os.environ.get("BUILD_SHA", "unknown")
    )

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))