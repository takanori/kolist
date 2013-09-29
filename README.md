kolist
======

Todo list based on Kossy

#TUTORIAL

Change MySQL username and password in KossyNote/lib/KoList/Web.pm.

Create database and table.

	> mysqladmin -uYourUserName create kolist -p
	> mysql -uYourUserName kolist < sqls/notes.sql -p

Install modules and execute

	> carton install
	> carton exec -- plackup app.psgi
