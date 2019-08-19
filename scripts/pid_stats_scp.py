#!/usr/bin/env python
# coding: utf-8

# # PID SCP Stats Report
# 
# This script runs stat totals for SCP and UCSD up to a specific date. This is requested yearly by the UCSD SCP Group.

# ### Create export from database

# #### Imports

# In[ ]:


import datetime
import collections
import getpass
import json
import os


import yaml
import pandas
import pymysql


# #### Define SQL Query

# In[ ]:


select_stmt_base = "select id, deactivated, group_id, created_at, notes from pids where created_at < '{}'"


# #### Get Connection & Credentials
# Enter database connection information. Everything is treated like a password to avoid accidental leaking into jupyter notebook.

# In[ ]:


if os.path.exists("../conf/db.yml"):
    print("Using conf/db.yml for configuration")
    db = yaml.safe_load(open("../conf/db.yml", "r"))
    host = db["db_host"]
    user = db["db_username"]
    password = db["db_password"]s
else:
    print("Could not find db conf, asking user for credentials")
    host = input("Host: ")
    user = input("Username: ")
    password = getpass.getpass("Password: ")


# In[ ]:


# create connection
conn = pymysql.connect(
    host=host,
    port=int(3306),
    user=user,
    passwd=password,
    db="pid")


# #### Running Querying 
# This is going to take awhile.

# In[ ]:


date = input("Enter a date (YYYY-MM-DD): ")


# In[ ]:


# run query to get dataframe
df = pandas.read_sql_query(select_stmt_base.format(date),
    conn)


# In[ ]:


filter_scp = df["group_id"]=="SCP"
filter_ucsd = df["group_id"]=="UCSD"
filter_scp_notes = df["notes"].str.lower().str.contains("scp")
filter_ucsd_notes = df["notes"].str.lower().str.contains("ucsd")
filter_de = df["deactivated"]==0
scp_all = df[(filter_scp)]['id'].count()
scp_de = df[(filter_scp) & (filter_de)]['id'].count()
ucsd_all = df[(filter_ucsd)]['id'].count()
ucsd_de = df[(filter_ucsd) & (filter_de)]['id'].count()

shared_de = df[((filter_ucsd & filter_scp_notes) | (filter_scp & filter_ucsd_notes)) & filter_de ]['id'].count()
shared_all = df[((filter_ucsd & filter_scp_notes) | (filter_scp & filter_ucsd_notes)) ]['id'].count()
print("SCP Total: {}".format(scp_all))
print("SCP Active: {}".format(scp_de))
print("UCSD Total: {}".format(ucsd_all))
print("UCSD Active: {}".format(ucsd_de))
print("Shared Total: {}".format(shared_all))
print("Shared Active: {}".format(shared_de))


# In[ ]:




