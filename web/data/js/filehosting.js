var FileHosting= new function () {

	this.DataSource= new function () {

		this.read= function (args, callback) {
			$.getJSON("/raw/json/"+args.join("/"), callback);
		}

		this.tags= function (callback) {
			this.read(["tags"], callback);
		}

		this.guess_tag= function (tag, callback) {
			this.read(["guess_tag", tag], callback);
		}

	}();

	var start_focus_priority= Infinity;

	this.iWantStartFocus= function (priority, IWant) {
		if (priority < start_focus_priority) {
			start_focus_priority= priority;
			IWant.focus();
		}
	}

}();
