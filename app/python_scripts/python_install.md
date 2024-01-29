
## Install python (install root python3)
`sudo yum install python36`
must call by python3 (python is default 2.6.9)

## Install pip (installs in .local)
`curl -O https://bootstrap.pypa.io/get-pip.py`
`python3 get-pip.py --user`
called with pip or pip3

## Put them in your path
`export PATH=/apps/pid/.local/bin:$PATH`
`source .bash_profile`

## Install packages
`pip install pymysql --user`
`pip install pyaml --user`
`pip install pandas --user`
