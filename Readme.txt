FileHosting Readme
==================

Datasource
----------
	- empty
		The empty Datasource always returns nothing.
	- sample
		The sample Datasource always returns some random data.
	- storage
		The storage Datasource uses the storage to store data.

Storage
-------
	- empty
		The empty Storage alway returns nothing.
	- file
		The file Storage uses the filesystem to store data.

bin
---
	The tools in bin must be called from inside bin , otherwise some
	librarys won't be found.

cgi
---
	bin/cgi can be used for a httpserver

filehostingrc
-------------
	There is a sample filehostingrc in config/filehostingrc. You should
	copy it (and modify if you like) to either /etc/filehostingrc or
	~/.filehostingrc or both locations. I that case settings made in
	~/.filehostingrc override the ones made in /etc/filehostingrc.

User
----
	There is a standard user called 'anonymous'. It is not recomended to
	change this users password.
