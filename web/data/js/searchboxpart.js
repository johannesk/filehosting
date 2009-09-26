FileHosting.SearchBoxPart= function (dom) {

	var obj= this;

	this.setTag= function(newtag) {
		var cursor= $("input[name=tags]", dom)[0].selectionStart;
		var new_cursor= 0;
		var tags= obj.tags();
		var new_tags= [];
		var tag= tags.shift();
		cursor-= tag.length;
		while (cursor > 0) {
			new_tags.push(tag);
			new_cursor+= tag.length+1
			tag= tags.shift();
			cursor-= tag.length+1;
		}
		new_tags.push(newtag);
		new_cursor+= newtag.length;
		new_tags= new_tags.concat(tags);
		$("input[name=tags]", dom).attr("value", new_tags.join(" "));
		$("input[name=tags]", dom)[0].selectionStart= new_cursor;
		$("input[name=tags]", dom)[0].selectionEnd= new_cursor;
		update_guessed(newtag);
		change();
	}

	this.tags= function () {
		return $("input[name=tags]", dom).attr("value").split(" ");
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
			$("div.autocomplete div", dom).remove();
		} else {
			FileHosting.DataSource.guess_tag(tag, function (tags) {
				if (local_count == update_count) {
					var current= $("div.autocomplete div.selected", dom).text();
					$("div.autocomplete div", dom).remove();
					$("div.autocomplete", dom).append($.map(tags, function (tag) {
						if (tag == current) {
							return "<div class=\"selected\">" + tag + "</div>";
						} else {
							return "<div>" + tag + "</div>";
						}
					} ).join(""));
					$("div.autocomplete div").each( function (i, div) {
						$(div).mousedown( function () {
							obj.setTag($(div).text());
							return false;
						});
					}); 
				}
			});
		}
	};
	$("input[name=tags]").attr("autocomplete", "off");

	var get_current_tag= function () {
		var cursor= $("input[name=tags]", dom)[0].selectionStart;
		var tags= obj.tags();
		var tag= tags.shift();
		cursor-= tag.length;
		while (cursor > 0) {
			tag= tags.shift();
			if (tag == undefined) {
				return "";
			}
			cursor-= tag.length+1;
		}
		return tag;
	}

	var last_tag= "";

	var check_for_guessed= function () {
		tag= get_current_tag();
		if (last_tag != tag) {
			last_tag= tag;
			update_guessed(tag);
			change();
		}
	};
	$("input[name=tags]", dom).keyup(check_for_guessed);
	$("input[name=tags]", dom).mouseup(check_for_guessed);
	$("input[name=tags]", dom).focus(check_for_guessed);
	$("input[name=tags]", dom).blur( function() {
		update_guessed("");
		last_tag= ""
	});

	$("input[name=tags]", dom).keydown( function(key) {
		var current= $("div.autocomplete div.selected", dom);
		switch(key.keyCode) {
			case 38: // up
				if (current.length == 0) {
					$("div.autocomplete div:last", dom).addClass("selected");
				} else {
					current.prev().addClass("selected");
					current.removeClass("selected");
				}
				break;
			case 40: // down
				if (current.length == 0) {
					$("div.autocomplete div:first", dom).addClass("selected");
				} else {
					current.next().addClass("selected");
					current.removeClass("selected");
				}
				break;
			case 13: // enter
				if (current.length == 1) {
					obj.setTag(current.text());
					return false;
				}
				break;
		}
		return true;
	} );
	
	if ($("input[type=submit]", dom).length == 1) {
		FileHosting.iWantStartFocus(1, $("input[name=tags]", dom));
	} else {
		FileHosting.iWantStartFocus(2, $("input[name=tags]", dom));
	}
	$("input[name=tags]", dom).wrap("<div class=\"text_input\"></div>");
	$("input[name=tags]", dom).after("<div class=\"autocomplete\"></div>");

}

FileHosting.all_SearchBoxPart= [];
$(document).ready( function () {
	$("div.search_box").each( function (i, dom) {
		FileHosting.all_SearchBoxPart.push(new FileHosting.SearchBoxPart(dom));
	} );
} );
