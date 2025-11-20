import configparser
import os
import sys

from flask import Flask, render_template
import mysql.connector

# step one: find ya config
config_path = os.path.join(os.path.dirname(__file__), "config.ini")
config = configparser.ConfigParser()
config.read(config_path)
db_cfg = config["db"]

# step two: log in
try:
    conn = mysql.connector.connect(
        host=db_cfg["host"],
        user=db_cfg["user"],
        password=db_cfg["password"],
        database=db_cfg["database"]
    )
except mysql.connector.Error as e:
    print("Database connection failed!")
    print(e)
    sys.exit(1)

# step three: ignition
app = Flask(__name__, static_folder="static", template_folder="templates")

@app.route("/")
def home():
    return render_template("index.html")

if __name__ == "__main__":
    app.run(debug=True)
