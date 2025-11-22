# airport_thing
the airport thing

## Installation and launching
Install prerequisite requirements; `pip install -r requirements.txt`

> [!NOTE]  
> If pip yells at you and says you're in an externally managed environment, you might need to create a python virtual environment. Follow [this guide](https://packaging.python.org/en/latest/guides/installing-using-pip-and-virtual-environments/) to do that.

Create a `config.ini` file with your database credentials, in this format;
```ini
[db]
host = localhost
user = root
password = password
database = Team10_Deliverable5
```
...fill those four fields in.

Create the database you listed in this file with the schema and (optionally) the seed data in the `sql/` folder.

Finally, run `python main.py`. :)


