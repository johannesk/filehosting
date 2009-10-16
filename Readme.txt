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
		The file Storage uses the filesystem to store data. Whenever
		the storage format becomes incompatible with old ones, the
		version number for the filestorage is increased. If you need
		to update your stored data from old versions, look at the
		skripts in skripts.

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
	copy it (and modify if you like) to either /etc/filehostingrc,
	~/.filehostingrc, ./filehostingrc or any of this locations. Local
	settings are always more important than global settings.

User
----
	There is a standard user called 'anonymous' and a standard user called
	'root'. Root is is allowed to do everything. It is recomended to change
	root's password.

Rules
-----
	The following rule sets are available. "user" => User is alway
	available as data for the rule. Additional data is specified here.
	- search {}
		deny access to searches
	- search_post {"tags" => [String]}
		deny acess to searches depending on search tags
	- search_filter {"file" => FileInfo}
		Filter search results. true results in filtering.
	- tags {}
		deny access to tags
	- tages_write {}
		deny acess to tag changes
	- file {}
		deny access to all file methods
	- file_withdata {"file" => FileInfo}
		deny access to all file methods
	- file_info {"file" => FileInfo}
		deny access to fileinfo
	- file_data {"file" => FileInfo}
		deny access to filedata
	- file_add {}
		deny access to add_file
	- file_add_post {"file" => FileInfo}
		deny access to add_file
	- file_update {"file" => FileInfo}
		deny access to update_file
	- file_update_post {"newfile" => FileInfo, "file" => FileInfo}
		deny access to update_file
	- file_replace {"file" => FileInfo}
		deny access to update_filedata
	- file_remove {"file" => FileInfo}
		deny access to remove_file
	- user {}
		deny access to all user methods
	- user_withdata {"user2" => User }
		deny access to all user methods
	- user_read {"user2" => User }
		deny access to user
	- user_add {}
		deny access to add_user
	- user_add_post {"user2" => User }
		deny access to add_user
	- user_update {"user2" => User }
		deny access to update_user
	- user_update_post {"newuser" => User, "user2" => User}
		deny access to update_user
	- history {"age" => (0..(1.0/0))}
		deny access to all history methods
	- history_file {"age" => (0..(1.0/0)), "file" => FileInfo}
		deny access to history_file
	- history_user{"age" => (0..(1.0/0)), "user2" => User }
		deny access to history_user
	- rules {}
		deny access to all rule methods
	- rules_withdata {"ruleset" => SpecialType.new(:rulesets)}}
		deny access to rule methods of the given rulesets
	- rules_read {"ruleset" => SpecialType.new(:rulesets)}}
		deny access to rules
	- rules_add {"ruleset" => SpecialType.new(:rulesets)}}
		deny access to add_rule
	- rules_add_post" {"ruleset" => SpecialType.new(:rulesets), "rule" => Rule, "position" => (0..(1.0/0))}
	- rules_remove {"ruleset" => SpecialType.new(:rulesets)}}
		deny access to remove_rule
