folder list files for constructing web

```
wpSBOOT ( web )
|   
└───  src ( script files using in app.py )
|   
└───  templates ( html )
|   
└───  static ( static data )
        |   
        └───  uploads ( alignment input )
        |
        └───  UserData ( concatenated results )
```

Enviroment configure :  pip install -r requirements.txt
startup.sh is used to start server.
cleanUp.sh is used to clean uploads file.( Only files in uploads folder )

--- note: makesure all parameters below are correct. ---
virtual env. is named as venv in startup.sh 
default path : /home/ubuntu/wpSBOOT/ in app.py. 
