import bcrypt
import configparser
import mysql.connector
import os
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
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

cur = conn.cursor(dictionary=True)

cur.execute("SELECT userID FROM Users")
rows = cur.fetchall()

pw = "test1".encode("utf-8")

for row in rows:
    uid = row["userID"]
    pw_hashed = bcrypt.hashpw(pw, bcrypt.gensalt())
    cur.execute(
        "UPDATE Users SET password = %s WHERE userID = %s",
        (pw_hashed, uid)
    )

print("Updated all user passwords.")
cur.close()
conn.close()
