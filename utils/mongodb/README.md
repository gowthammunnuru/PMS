### How to setup/initalize mongodb

Run the following as root
```
%> sudo ./init /usr/bin/mongo localhost:9090
```


#### Sample Output

The following output shows a successful initialization
```
[1/10]: Setting up the database path
[2/10]: Initializing the database
MongoDB shell version: 2.2.0
connecting to: localhost:9090/test
{
    "user" : "admin",
    "readOnly" : false,
    "pwd" : "2975959861b72d417b41a2c115cca1d2",
    "_id" : ObjectId("54b8fc8add5276f146925e8c")
}
addUser succeeded, but cannot wait for replication since we no longer have auth
{
    "user" : "admin",
    "readOnly" : false,
    "pwd" : "2975959861b72d417b41a2c115cca1d2",
    "_id" : ObjectId("54b8fc8add5276f146925e8d")
}
```

If you get the following, that means mongodb hasnt started fully. Wait for a few secs, and try again
```
MongoDB shell version: 2.2.0
connecting to: localhost:9090/test
Fri Jan 16 17:25:56 Error: couldn't connect to server localhost:9090 src/mongo/shell/mongo.js:93
exception: connect failed
```

The following means things are already setup. You dont need to do the intialization again.
```
[1/10]: Setting up the database path
[2/10]: Initializing the database
MongoDB shell version: 2.2.0
connecting to: localhost:9090/test
Fri Jan 16 17:28:02 uncaught exception: error {
    "$err" : "unauthorized db:admin ns:admin.system.users lock type:1 client:127.0.0.1",
    "code" : 10057
}
failed to load: /tmp/tmp4uBKuP.init.js
```
