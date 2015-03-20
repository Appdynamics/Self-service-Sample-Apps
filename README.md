#Usage

##Linux 

You will need to run the script with sudo permissions.  The script expects The controller url and the port at a minimum to get started:

```
sudo sh AppDemo.sh -c <controller> -p <port> [-s <ssl>] [-u <account>] [-k <key>] [-n <node port>] [-a <axis port>] [-m <mysql port>]

Arguments:
  -c        Host Name / IP Address of the AppDynamics Controller
  -p        Port Number of the AppDynamics Controller
  -s        <true/false> if the connection to the controller is made via SSL (defaults to false)
  -u        The account name to connect to the controller (for multi-tenant controllers or the SaaS controller)
  -k        The account access key to connect to the controller (for multi-tenant controllers or the SaaS controller)
  -n        The port number the created Node Server will bind to (defaults to $NODE_PORT)
  -a        The port number the created Axis Server will bind to (defaults to $AXIS_PORT)
  -m        The port number the create MySql Server will bind to (defaults to $MYSQL_PORT)
  -y        Automatic yes to prompts
  -z        Prompt on each install request
  -d        Remove the sample application and exit
  -h        Print Help (this message) and exit
```

Example:
```bash
sudo sh AppDemo.sh -c paidxxx.appdynamics.com -p 443 -s true -u myUsername -k myKey
```

####Dependencies
  - Apache Axis
  - Apache Ant
  - NodeJS (with Expression, Request, and xml2js)
  - MySql
  - Java JDK
  - AppDynamics Machine Agent
  - AppDynamics Database Agent
  - AppDynamics App Server Agent
  - wget
  - unzip
  - gzip
  - curl
  - libaio
