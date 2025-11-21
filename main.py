import configparser
import html
import os
import sys

import bcrypt
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
        database=db_cfg["database"],
        autocommit=True
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
        if route_name == "layout":
            continue

        def make_view(template_name):
            return lambda: render_template(template_name)

        app.add_url_rule(
            route_name,
            endpoint=route_name,
            view_func=make_view(f"demos/{filename}") # relative paths only?
        )

def table_it(rows):
    if not rows:
        return "<table class=\"table\"><tr><td>No data</td></tr></table>"

    if isinstance(rows[0], dict):
        columns = list(rows[0].keys())
        get_val = lambda row, col: row.get(col, "")
    else:
        if columns is None:
            raise ValueError("Column names required when rows are tuples.")
        get_val = lambda row, idx: row[idx]

    # we built this table
    parts = ["<table class=\"table\">"]
    parts.append("<thead><tr>" + "".join(f"<th>{html.escape(str(c))}</th>" for c in columns) + "</tr></thead>")
    parts.append("<tbody>")
    for row in rows:
        parts.append("<tr>" + "".join(
            f"<td>{html.escape(str(get_val(row, c if isinstance(row, dict) else i)))}</td>"
            for i, c in enumerate(columns)
        ) + "</tr>")
    parts.append("</tbody></table>")

    return "".join(parts)

def execute_sql(sql, params=[]):
    sql = sql.strip()
    print(sql)
    print(params)
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(sql, params)
        return cur.fetchall()
    except mysql.connector.Error as e:
        print("Error code:", e.errno)        # error number
        print("SQLSTATE value:", e.sqlstate) # SQLSTATE value
        print("Error message:", e.msg)       # error message
        print("Error:", e)                   # errno, sqlstate, msg values
        return []
    finally:
        cur.close()
        #conn.close()

###############
### flights ###
###############
# eventually: get by user id

def _flights(id=None):
    sql = """
    SELECT * FROM Flights;
    """
    result = execute_sql(sql)
    return result

@app.get("/flights/")
def getFlights(id=None):
    return jsonify(_flights(id))

# helpful visual
@app.get("/flights/table")
def getFlightsTable(id=None):
    return table_it(_flights(id))

#############
### users ###
#############

@app.post("/users/create")
def createUser():
    data = request.get_json()
    pw = data["password"].encode('utf-8')
    pw_hashed = bcrypt.hashpw(pw, bcrypt.gensalt())

    sql = """
    INSERT INTO Users (name, email, password) VALUES (%s, %s, %s)
    """
    params = [data["name"], data["email"], pw_hashed]
    result = execute_sql(sql, params)
    return jsonify(result)

@app.get("/users/:id")
def getUser():
    pass

if __name__ == "__main__":
    app.run(debug=True)
