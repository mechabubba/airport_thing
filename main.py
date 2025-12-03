import configparser
import html
import os
import sys
from functools import wraps
import uuid

import bcrypt
from flask import Flask, render_template, request, jsonify
import mysql.connector

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATE_DIR = os.path.join(BASE_DIR, "templates")
STATIC_DIR = os.path.join(BASE_DIR, "static")

# whats one more global to the fray
SESSIONS = {}

# role hierarchy (making everything worse)
ROLE_LEVEL = {
    "Guest": 0,
    "Customer": 1,
    "Staff": 2
}

def require_session(required=None):
    """
    required = None        → any logged-in user OR Guest
    required = "Customer"  → Customer or Staff
    required = "Staff"     → Staff only
    """
    def decorator(view):
        @wraps(view)
        def wrapper(*args, **kwargs):
            sid = request.cookies.get("session_id")

            # If no session cookie, treat user as Guest
            if not sid or sid not in SESSIONS:
                user_role = "Guest"
                user_id = None
            else:
                user_id = SESSIONS[sid]

                # Fetch role from DB
                sql = """
                SELECT type
                FROM Users
                WHERE userID = %s
                LIMIT 1
                """
                rows = execute_sql(sql, [user_id])

                user_role = rows[0]["type"] if rows else "Guest"

            # Guests can access ANY page
            if user_role == "Guest":
                return view(*args, **kwargs)

            # If no required role for this page, allow
            if required is None:
                return view(*args, **kwargs)

            # Compare hierarchical access level
            if ROLE_LEVEL[user_role] < ROLE_LEVEL[required]:
                return "Forbidden", 403

            return view(*args, **kwargs)

        return wrapper
    return decorator

# find local config file.
config = configparser.ConfigParser()
config.read(f"{BASE_DIR}/config.ini")
db_cfg = config["db"]

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

app = Flask(__name__, static_folder=STATIC_DIR, template_folder=TEMPLATE_DIR)

@app.route("/")
def home():
    return render_template("index.html")

@app.get("/customer")
@require_session(required="Customer")
def customer_page():
    return render_template("customer.html")

@app.get("/staff")
@require_session(required="Staff")
def staff_page():
    return render_template("staff.html")

@app.get("/signup")
def signup_page():
    return render_template("signup.html")

@app.get("/login")
def login_page():
    return render_template("login.html")

# dumb way of doing things
# regrettable choice, but don't really want to touch it now...
for filename in os.listdir(os.path.join(TEMPLATE_DIR, "demos")):
    if filename.endswith(".html"):
        route_name = "/" + filename[:-5] + "/" # strip the ".html"
        if route_name == "layout":
            continue

        def make_view(template_name):
            @require_session(required="Staff")
            def view():
                return render_template(template_name)
            return view

        app.add_url_rule(
            route_name,
            endpoint=route_name,
            view_func=make_view(f"demos/{filename}") # relative paths only?
        )

def table_it(rows):
    """
    formats a set of sql rows into an html table. 
    """
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

    # we built this table on raw html
    return "".join(parts)

def execute_sql(sql, params=[]):
    """
    executes a sql string
    - automatically applies placeholder parameters if they're needed
    """
    sql = sql.strip()
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



######################
### flight routing ###
######################
# (air traffic control)

def _flights(id=None):
    sql = """
    SELECT * FROM Flights;
    """
    result = execute_sql(sql)
    return result

# this is unused but still helpful
@app.get("/flights/")
def getFlights():
    return jsonify(_flights())

# utilizes a join between the FlightStatus view and UserFlights table to get the flight statuses for a given user
def _flight_statuses(id=None):
    if not id:
        return 400, "Endpoint requires user ID" 

    sql = """
    SELECT uf.flightID, fs.status
    FROM UserFlights AS uf
    JOIN FlightStatuses AS fs
        ON uf.flightID = fs.flightID
    WHERE uf.userID = %s;
    """
    params = [int(id)]

    result = execute_sql(sql, params)
    return result

@app.post("/flights/status")
def getFlightStatuses():
    data = request.get_json()
    return table_it(_flight_statuses(data["id"]))

# helpful visual
@app.get("/flights/table")
def getFlightsTable(id=None):
    return table_it(_flights(id))



#############
### users ###
#############

@app.post("/users/rewards")
def getUserRewards():
    data = request.get_json()
    _id = data["id"]

    sql = """
    SELECT 
        r.rewardID,
        r.rewardTier,
        r.requiredPoints AS pointCost,
        r.rewardDescription
    FROM CustomerRewards AS cr
    JOIN Rewards AS r
        ON cr.rewardID = r.rewardID
    JOIN Customers AS c
        ON cr.userID = c.userID
    WHERE cr.userID = %s
        AND r.requiredPoints <= c.points;
    """
    params = [int(_id)]

    result = execute_sql(sql, params)
    return table_it(result)


@app.post("/users/create")
def createUser():
    data = request.get_json()
    pw = data["password"].encode('utf-8')
    pw_hashed = bcrypt.hashpw(pw, bcrypt.gensalt())

    sql = """
    INSERT INTO Users (name, email, password, type) VALUES (%s, %s, %s, "Staff")
    """
    params = [data["name"], data["email"], pw_hashed]

    result = execute_sql(sql, params)
    return jsonify(result)

@app.get("/users/me")
@require_session
def get_current_user():
    session_id = request.cookies.get("session_id")
    user_id = SESSIONS.get(session_id)

    sql = """
    SELECT userID, name, email, dateCreated, type
    FROM Users
    WHERE userID = %s
    LIMIT 1
    """
    rows = execute_sql(sql, [user_id])

    if not rows:
        return "User not found", 404

    return jsonify(rows[0])

"""
notes
- left join to keep all users, dump unrecognized rewards
"""
@app.get("/users/")
def getUsers():
    sql = """
    SELECT
        u.userID,
        u.name,
        u.email,
        u.dateCreated,
        u.type,
        COUNT(cr.rewardID) AS rewardCount
    FROM Users AS u
    LEFT JOIN CustomerRewards AS cr
    ON u.userID = cr.userID
    GROUP BY 
        u.userID,
        u.name,
        u.email,
        u.dateCreated,
        u.type;
    """
    result = execute_sql(sql)
    return table_it(result)



###
### sessions???
###

@app.post("/sessions/create")
def create_session():
    data = request.get_json()
    email = data["email"]
    password = data["password"].encode("utf-8")

    # fetch stored hashed password
    sql = "SELECT userID, password, type FROM Users WHERE email = %s LIMIT 1"
    rows = execute_sql(sql, [email])
    if not rows:
        return "Invalid credentials", 401

    user = rows[0]
    stored_hash = user["password"].encode("utf-8")

    if not bcrypt.checkpw(password, stored_hash):
        return "Invalid credentials", 401

    # create session
    session_id = uuid.uuid4().hex
    SESSIONS[session_id] = user["userID"]

    resp = jsonify({"success": True, "type": user["type"]})
    resp.set_cookie("session_id", session_id, httponly=True, samesite="Strict")
    return resp

###############
### tickets ###
###############

@app.get("/tickets/")
def getTickets():
    sql = """
    SELECT 
        t.ticketID,
        t.flightID,
        t.firstClassPrice,
        t.businessClassPrice,
        t.economyPrice
    FROM TicketPrices AS t
    ORDER BY t.flightID, t.ticketID;
    """
    rows = execute_sql(sql, [])
    return rows

@app.post("/tickets/purchase")
def purchaseTickets():
    data = request.get_json()
    try:
        cur = conn.cursor(dictionary=True)

        # Call the stored procedure
        cur.callproc("purchaseTicket", [
            data["userID"],
            data["flightID"],
            data["ticketID"],
            data["class"]
        ])

        # Get SELECT result from the procedure (purchaseSuccess)
        results = None
        for result in cur.stored_results():
            results = result.fetchall()

        # If success, send "1"
        if results and "purchaseSuccess" in results[0]:
            return str(results[0]["purchaseSuccess"])

        return "0"
    except mysql.connector.Error:
        return "0"
    finally:
        cur.close()

###
### Emplyoee Button
###
@app.post("/employees/add")
def addEmployee():
    data = request.get_json()
    user_id = data["userID"]
    salary = data["salary"]
    position = data["position"]

    try:
        cur = conn.cursor(dictionary=True)

        # Check if employee already exists
        check_sql = "SELECT userID FROM Employees WHERE userID = %s LIMIT 1"
        cur.execute(check_sql, (user_id,))
        existing = cur.fetchone()

        if existing:
            # Update existing employee record
            update_sql = """
            UPDATE Employees
            SET salary = %s,
                position = %s
            WHERE userID = %s
            """
            cur.execute(update_sql, (salary, position, existing["userID"]))
            return "Employee updated. :)"

        else:
            # Insert new employee
            insert_sql = """
            INSERT INTO Employees (userID, salary, startDate, position)
            VALUES (%s, %s, NOW(), %s)
            """
            cur.execute(insert_sql, (user_id, salary, position))
            return "New employee added. :)"

    except mysql.connector.Error as e:
        return f"Error: {e.msg}"
    finally:
        cur.close()




###
### ROCK AND ROLL
###
if __name__ == "__main__":
    app.run(debug=True)
