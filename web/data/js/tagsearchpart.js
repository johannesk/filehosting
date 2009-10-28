FileHosting.TagSearchPart= function (dom) {

	var obj= this;

	this.oldTags= function () {
		return $.map($("input[name=tags]", dom).attr("value").split(" "), function (tag) { return $.trim(tag) });
	}

	this.newTag= function () {
		return $("input[name=newtags]", dom).attr("value")
	}

	this.setNewTag= function(tag) {
		$("input[name=newtags]", dom).attr("value", tag);
		update_guessed(tag);
		change();
	}

	this.tags= function () {
		var res= obj.oldTags();
		var add= obj.newTag();
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
					var current= $("div.tag_box a.selected", dom).text();
					$("div.tag_box form", dom).nextAll().remove();
					var url= $("div.tag_box form", dom).attr("action") + obj.oldTags().join(" ") + " "
					$("div.tag_box form", dom).after($.map(tags, function (tag) {
						if (tag == current) {
							return "<a class=\"guessed_tag selected\" href=\"" + url + tag + "\">" + tag + "</a>";
						} else {
							return "<a class=\"guessed_tag\" href=\"" + url + tag + "\">" + tag + "</a>";
						}
					} ).join(""));
				}
			});
		}
	};
	update_guessed(this.newTag());
	$("div.tag_box input[name=newtags]", dom).attr("autocomplete", "off");

	var last_newtag= this.newTag();
	
	$("input[name=newtags]", dom).keyup( function () {
		var newtag= obj.newTag();
		if (last_newtag != newtag) {
			last_newtag= newtag;
			update_guessed(newtag);
			change();
		}
		return true;
	} );

	$("input[name=newtags]", dom).keydown( function(key) {
		var current= $("div.tag_box a.selected", dom);
		switch(key.keyCode) {
			case 38: // up
				if (current.length == 0) {
					if ($("div.tag_box form + a", dom).length != 0) {;
						$("div.tag_box a:last", dom).addClass("selected");
					}
				} else {
					current.prev().addClass("selected");
					current.removeClass("selected");
				}
				return false;
				break;
			case 40: // down
				if (current.length == 0) {
					$("div.tag_box form + a", dom).addClass("selected");
				} else {
					current.next().addClass("selected");
					current.removeClass("selected");
				}
				return false;
				break;
			case 13: // enter
				if (current.length == 1) {
					obj.setNewTag(current.text());
				}
				break;
		}
		return true;
	} );

	FileHosting.iWantStartFocus(1, $("div.tag_box input[name=newtags]"));

}

FileHosting.all_TagSearchPart= [];
$(document).ready( function () {
	$("div.search_tags").each( function (i, dom) {
		FileHosting.all_TagSearchPart.push(new FileHosting.TagSearchPart(dom));
	} );
} );
