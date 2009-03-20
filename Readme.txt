FileHosting Readme
==================

backend
-------
	There is no real backend yet. The only available backend always
	returns some random data.

bin
---
	The tools in bin must be called from inside bin , otherwise some
	librarys won't be found.

cgi
---
	The cgi directory contains cgi scripts for an http server. There
	should be a /etc/filehostingrc.cgi for configuration of this cgi
	scripts. Both symlinks filehosting and templates should be made
	inaccessible by the http server.

filehostingrc
-------------
	There is a sample filehostingrc in config/filehostingrc. You should
	copy it (and modify if you like) to either /etc/filehostingrc or
	~/.filehostingrc or both locations. I that case settings made in
	~/.filehostingrc override the ones made in /etc/filehostingrc.
