var FileHosting= new Object();
FileHosting.DataSource= new Object();

FileHosting.DataSource.read= function (args, callback) {
	$.getJSON("/raw/json/"+args.join("/"), callback);
}

FileHosting.DataSource.tags= function (callback) {
	this.read(["tags"], callback);
}

FileHosting.DataSource.guess_tag= function (tag, callback) {
	this.read(["guess_tag", tag], callback);
}
