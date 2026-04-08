from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def hello():
    return "Hello, World! – ADB SAFEGATE DevOps Engineer Assignment"


@app.route("/health")
def health():
    """
    Health check endpoint for Kubernetes liveness and readiness probes.
    Returns HTTP 200 with JSON status when the app is healthy.
    """
    return jsonify({"status": "ok", "service": "hello-app"}), 200


if __name__ == "__main__":
    # host=0.0.0.0 required – exposes port outside the container
    # debug=False enforced – Werkzeug debugger is a critical security risk in production
    app.run(host="0.0.0.0", port=5000, debug=False)
