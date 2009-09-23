FileHosting.TagSearchPart= function (dom) {

	var obj= this;

	this.old_tags= function () {
		return $.map($("input[name=tags]", dom).attr("value").split(" "), function (tag) { return $.trim(tag) });
	}

	this.newtag= function () {
		return $("input[name=newtags]", dom).attr("value")
	}

	this.set_newtag= function(tag) {
		$("input[name=newtags]", dom).attr("value", tag);
		update_guessed(tag);
		change();
	}

	this.tags= function () {
		var res= obj.old_tags();
		var add= obj.newtag();
		if (add.length > 0) {
			res.push(add);
		}
		return res
	}

	var change_callbacks= [];

	this.change= function(callback) {
		change_callbacks.push(callback);
	}

	var change= function() {
		$.each(change_callbacks, function (i, callback) {
			callback();
		} );
	}

	var update_count= 0;

	var update_guessed= function (tag) {
		update_count++;
		var local_count= update_count;
		if (tag.length == 0) {
			$("div.tag_box form", dom).nextAll().remove();
		} else {
			FileHosting.DataSource.guess_tag(tag, function (tags) {
				if (local_count == update_count) {
					var current= $("div.tag_box a.selected").text();
					$("div.tag_box form", dom).nextAll().remove();
					$("div.tag_box form", dom).after($.map(tags, function (tag) {
						if (tag == current) {
							return "<a class=\"guessed_tag selected\">"+tag+"</a>";
						} else {
							return "<a class=\"guessed_tag\">"+tag+"</a>";
						}
					} ).join(""));
				}
			});
		}
	};
	update_guessed(this.newtag());
  $("div.tag_box input[type=text]").attr("autocomplete", "off");

	var last_newtag= this.newtag();
	
	$("input[name=newtags]", dom).keyup( function () {
		var newtag= obj.newtag();
		if (last_newtag != newtag) {
			last_newtag= newtag;
			update_guessed(newtag);
			change();
		}
		return true;
	} );

	$("input[name=newtags]", dom).keydown( function(key) {
		var current= $("div.tag_box a.selected");
		switch(key.keyCode) {
			case 38: // up
				if (current.length == 0) {
					$("div.tag_box a:last").addClass("selected");
				} else {
					current.prev().addClass("selected");
					current.removeClass("selected");
				}
				break;
			case 40: // down
				if (current.length == 0) {
					$("div.tag_box form + a").addClass("selected");
				} else {
					current.next().addClass("selected");
					current.removeClass("selected");
				}
				break;
			case 13: // enter
				if (current.length == 1) {
					obj.set_newtag(current.text());
				}
				break;
		}
		return true;
	} );

}

FileHosting.all_TagSearchPart= [];
$(document).ready( function () {
	$("div.search_tags").each( function (i, dom) {
		FileHosting.all_TagSearchPart.push(new FileHosting.TagSearchPart(dom));
	} );
} );
