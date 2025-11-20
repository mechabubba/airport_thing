from flask import Flask, render_template
import configparser
import os

config_path = os.path.join(os.path.dirname(__file__), "file", "config.ini")
config = configparser.ConfigParser()
config.read(config_path)

app = Flask(__name__, static_folder='static', template_folder='templates')

@app.route("/")
def home():
    return render_template("home.html")

if __name__ == "__main__":
    app.run(debug=True)
