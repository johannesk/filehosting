FileHosting.SearchBoxPart= function (dom) {

	var obj= this;

	if ($("input[type=submit]", dom).length == 1) {
		FileHosting.iWantStartFocus(1, $("input[name=tags]", dom));
	} else {
		FileHosting.iWantStartFocus(2, $("input[name=tags]", dom));
	}

}

FileHosting.all_SearchBoxPart= [];
$(document).ready( function () {
	$("div.search_box").each( function (i, dom) {
		FileHosting.all_SearchBoxPart.push(new FileHosting.SearchBoxPart(dom));
	} );
} );
