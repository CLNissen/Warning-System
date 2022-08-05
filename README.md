# Warning-System

!warn - Command creates a menu with !gwarn, !rwarn, !swarn and !dis commands to be selected.


!gwarn - Command creates a menu with a list of all online players. Choosing a player will let you choose a warning reason to add to MySQL database.<br/>

!rwarn - Command creates a menu with a list of all online players. Choosing a player will let you remove a warning from MySQL database.<br/>

!swarn - Command creates a menu with a list of all online players. Choosing a player will show all warnings associated with selected player from MySQL database.<br/>

!dis - Command creates a menu with a list of all recently disconnected players. Choosing a player will let you choose a warning reason to add to MySQL database.<br/>

## Requirements
MySQL Database

Configuration of MySQL database in database config

## Versions
v.1.0 = Initial release

v.1.1 = Added !dis command. Bug fixes to !rwarn and !swarn. Added function to put a players steamID into database when joining if not already in database, in order for !dis to work properly.

v.1.2 = All commands are now accessible via !warn instead of eachh function having to be accessed via their own command. Bug fixes.
