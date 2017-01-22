demo_canvas = document.getElementById("demo_canvas");

min_width  = 320;
min_height = 240;
med_width  = 640;
med_height = 480;

function play(){
	canvas_play = !canvas_play
}
document.getElementById("btn_play").onclick = play

function small_res(){
	demo_canvas.width  = min_width
	demo_canvas.height = min_height
}
document.getElementById("btn_small").onclick = small_res

function medium_res() {
	demo_canvas.width  = med_width
	demo_canvas.height = med_height
	console.log(demo_canvas.fullscreenEnabled)
}
document.getElementById("btn_medium").onclick = medium_res

document.getElementById("btn_fullscreen").onclick = function(){
	demo_canvas.width  = screen.width
	demo_canvas.height = screen.height
	if (navigator.userAgent.search("Firefox") > -1) {
		demo_canvas.mozRequestFullScreen();
	} else {
		demo_canvas.webkitRequestFullScreen(Element.ALLOW_KEYBOARD_INPUT);
	}
}

function onFullScreenChange(){
	if (
		document.fullscreenElement ||
		document.webkitFullscreenElement ||
		document.mozFullScreenElement ||
		document.msFullscreenElement
	) {
	} else {
		small_res()
	}
}

document.addEventListener("fullscreenchange", onFullScreenChange);
document.addEventListener("webkitfullscreenchange", onFullScreenChange);
document.addEventListener("mozfullscreenchange", onFullScreenChange);
document.addEventListener("MSFullscreenChange", onFullScreenChange);
