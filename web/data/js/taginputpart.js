FileHosting.TagInputPart= function (dom) {

	var obj= this;

	$(dom).wrap("<div class=\"tag_input\"></div>");
	$(dom).after("<div class=\"autocomplete\"></div>");
	dom= $(dom).parent();

	function input() {
		return $("input", dom)
	}

	input().attr("autocomplete", "off");

	this.setTag= function(newtag) {
		var cursor= input()[0].selectionStart;
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
		input().attr("value", new_tags.join(" "));
		input()[0].selectionStart= new_cursor;
		input()[0].selectionEnd= new_cursor;
		update_guessed(newtag);
		change();
	}

	this.tags= function () {
		return input().attr("value").split(" ");
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

	var get_current_tag= function () {
		var cursor= input()[0].selectionStart;
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
	input().keyup(check_for_guessed);
	input().mouseup(check_for_guessed);
	input().focus(check_for_guessed);
	input().blur( function() {
		update_guessed("");
		last_tag= ""
	});

	input().keydown( function(key) {
		var current= $("div.autocomplete div.selected", dom);
		switch(key.keyCode) {
			case 38: // up
				if (current.length == 0) {
					$("div.autocomplete div:last", dom).addClass("selected");
				} else {
					current.prev().addClass("selected");
					current.removeClass("selected");
				}
				return false;
				break;
			case 40: // down
				if (current.length == 0) {
					$("div.autocomplete div:first", dom).addClass("selected");
				} else {
					current.next().addClass("selected");
					current.removeClass("selected");
				}
				return false;
				break;
			case 13: // enter
				if (current.length == 1) {
					current.removeClass("selected")
					obj.setTag(current.text());
					return false;
				}
				break;
		}
		return true;
	} );

}

FileHosting.all_TagInputPart= [];
$(document).ready( function () {
	$("input.tag_input").each( function (i, dom) {
		FileHosting.all_TagInputPart.push(new FileHosting.TagInputPart(dom));
	} );
} );
