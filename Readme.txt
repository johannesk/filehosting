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
	There is a standard user called 'anonymous' and a standard user called
	'root'. Root is is allowed to do eveything. It is recomended to change
	root's password.

Rules
-----
	The following rule sets are available
	- search_filter
		Filter search results. true results in filtering.
	- search
		deny access to searches
	- tags
		deny access to tags
	- file
		deny access to all file methods
	- file_info
		deny access to fileinfo
	- file_data
		deny access to filedata
	- file_add
		deny access to add_file
	- file_update
		deny access to update_file
	- file_replace
		deny access to update_filedata
	- file_remove
		deny access to remove_file
	- user
		deny access to all user methods
	- user_read
		deny access to user
	- user_add
		deny access to add_user
	- user_update
		deny access to update_user
	- history
		deny access to all history methods
	- history_file
		deny access to history_file
	- history_user
		deny access to history_user
	- rules
		deny access to all rule methods
	- rules_read
		deny access to rules
	- rules_add
		deny access to add_rule
	- rules_remove
		deny access to remove_rule
