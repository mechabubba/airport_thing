import configparser
import os
import sys

from flask import Flask, render_template, request, jsonify
import mysql.connector

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATE_DIR = os.path.join(BASE_DIR, "templates")
STATIC_DIR = os.path.join(BASE_DIR, "static")

# step one: find ya config
config = configparser.ConfigParser()
config.read(f"{BASE_DIR}/config.ini")
db_cfg = config["db"]

# step two: log in to ya server
try:
    conn = mysql.connector.connect(
        host=db_cfg["host"],
        user=db_cfg["user"],
        password=db_cfg["password"],
        database=db_cfg["database"]
    )
except mysql.connector.Error as e:
    print("Error: Database connection failed!")
    print(e)
    sys.exit(1)

# step three: ignition
app = Flask(__name__, static_folder=STATIC_DIR, template_folder=TEMPLATE_DIR)

@app.route("/")
def home():
    return render_template("index.html")

# dumb way of doing things
for filename in os.listdir(os.path.join(TEMPLATE_DIR, "demos")):
    if filename.endswith(".html"):
        route_name = "/" + filename[:-5] + "/" # strip the ".html"

        def make_view(template_name):
            return lambda: render_template(template_name)

        app.add_url_rule(
            route_name,
            endpoint=route_name,
            view_func=make_view(f"demos/{filename}") # relative paths only?
        )

def execute_sql(sql, params):
    sql = sql.strip()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(sql, params)
        return cur.fetchall()
    except mysql.connector.Error as e:
        print(f"Error retrieving elections: {e}")
        return []
    finally:
        cur.close()
        #conn.close()

# alright, anyway
# trying not to continue to think too hard about this

@app.post("/demo1/query")
def demo1_query():
    data = request.get_json()
    sql = data["sql"].strip()
    params = data["params"]
    print(sql, params)
    result = execute_sql(sql, params)
    print(result)
    return jsonify(result)

@app.post("/demo1/query")
def demo2_query():
    data = request.get_json()
    sql = data["sql"].strip()
    params = data["params"]
    result = execute_sql(sql, params)
    return jsonify(result)

@app.post("/demo1/query")
def demo3_query():
    data = request.get_json()
    sql = data["sql"].strip()
    params = data["params"]
    result = execute_sql(sql, params)
    return jsonify(result)

@app.post("/demo1/query")
def demo4_query():
    data = request.get_json()
    sql = data["sql"].strip()
    params = data["params"]
    result = execute_sql(sql, params)
    return jsonify(result)

@app.post("/demo1/query")
def demo5_query():
    data = request.get_json()
    sql = data["sql"].strip()
    params = data["params"]
    result = execute_sql(sql, params)
    return jsonify(result)

if __name__ == "__main__":
    app.run(debug=True)
