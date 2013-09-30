kolist
======

Todo list based on Kossy

#TUTORIAL

Change MySQL username and password in KoList/config.pm.

Create database and table.

	> mysqladmin -uYourUserName create kolist -p
	> mysql -uYourUserName kolist < sqls/users.sql -p
	> mysql -uYourUserName kolist < sqls/todos.sql -p

Install modules and execute

	> carton install
	> carton exec -- plackup app.psgi
