const is_mouse_right = function(e){
	e = e || window.event;

	if ("which" in e)  // Gecko (Firefox), WebKit (Safari/Chrome) & Opera
		return e.which == 3;
	else if ("button" in e)  // IE, Opera
		return e.button == 2;
}

const main=function() {
	const CANVAS=document.getElementById("demo_canvas")
	const COUNTER=document.getElementById("counter")
	CANVAS.width=window.innerWidth
	CANVAS.height=window.innerHeight

	let GL
	try {
		GL = CANVAS.getContext("experimental-webgl", {antialias: true})
	} catch (e) {
		alert("You are not webgl compatible :(")
		return false
	}

	const vertices = [
		-1.0,-1.0, 0.0,
		 1.0, 1.0, 0.0,
		-1.0, 1.0, 0.0,
		 1.0,-1.0, 0.0,
	]
	const indices = [0,1,2,0,1,3]

	const get_shader=function(source, type, typeString) {
		const shader = GL.createShader(type)
		GL.shaderSource(shader, source)
		GL.compileShader(shader)
		if (!GL.getShaderParameter(shader, GL.COMPILE_STATUS)) {
			console.log("ERROR IN "+typeString+ " SHADER : " + GL.getShaderInfoLog(shader))
			return false
		}
		return shader
	}

	// Link the vertex and fragment shader
	const vertex_buffer = GL.createBuffer()
	GL.bindBuffer(GL.ARRAY_BUFFER, vertex_buffer)
	GL.bufferData(GL.ARRAY_BUFFER, new Float32Array(vertices), GL.STATIC_DRAW)
	const index_buffer = GL.createBuffer()
	GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, index_buffer)
	GL.bufferData(GL.ELEMENT_ARRAY_BUFFER, new Uint16Array(indices), GL.STATIC_DRAW)

	const shader_vertex=get_shader(shader_vertex_source, GL.VERTEX_SHADER, "VERTEX")
	const shader_fragment=get_shader(shader_fragment_source, GL.FRAGMENT_SHADER, "FRAGMENT")

	const SHADER_PROGRAM=GL.createProgram()
	GL.attachShader(SHADER_PROGRAM, shader_vertex)
	GL.attachShader(SHADER_PROGRAM, shader_fragment)
	GL.linkProgram(SHADER_PROGRAM)
	GL.useProgram(SHADER_PROGRAM)

	// Pass the screen size to the shaders as uniform and quad coordinates as attribute
	const screen_size_in = GL.getUniformLocation(SHADER_PROGRAM, "screen_size_in")
	const global_time = GL.getUniformLocation(SHADER_PROGRAM, "global_time_in")
	const coord = GL.getAttribLocation(SHADER_PROGRAM, "coordinates")
	var uni_min_re = GL.getUniformLocation(SHADER_PROGRAM, "min_re")
	var uni_max_re = GL.getUniformLocation(SHADER_PROGRAM, "max_re")
	var uni_min_im = GL.getUniformLocation(SHADER_PROGRAM, "min_im")
	var uni_max_im = GL.getUniformLocation(SHADER_PROGRAM, "max_im")

	var min_re = -2.0;
	var max_re =  1.0;
	var min_im = -1.2;
	var max_im =  1.0;

	GL.enableVertexAttribArray(coord)

	function zoom_window_size(xpercent, ypercent){
		let re_diff = Math.abs(max_re - min_re)/4
		let im_diff = Math.abs(max_im - min_im)/4
		max_re -= re_diff * (1.0 - xpercent);
		min_re += re_diff * xpercent;
		max_im -= im_diff * (1.0 - ypercent);
		min_im += im_diff * ypercent;
	}
	function unzoom_window_size(xpercent, ypercent){
		let re_diff = Math.abs(max_re - min_re)/4
		let im_diff = Math.abs(max_im - min_im)/4
		max_re += re_diff * xpercent;
		min_re -= re_diff * (1.0 - xpercent);
		max_im += im_diff * ypercent;
		min_im -= im_diff * (1.0 - ypercent);
	}

	function on_click(event)
	{
		let isRightMB = is_mouse_right(event)

		let x = event.x + 1;
		let y = event.y + 1;

		x -= CANVAS.offsetLeft;
		y -= CANVAS.offsetTop;

		xpercent = x/CANVAS.width;
		ypercent = y/CANVAS.height;

		if( is_mouse_right(event) ){
			unzoom_window_size(xpercent, ypercent)
		} else {
			zoom_window_size(xpercent, ypercent)
		}
	}
	CANVAS.addEventListener("mousedown", on_click, false);

	let time_old=0
	const counter_list = []
	let last_mean = 0

	// main loop
	const animate=function(time) {
		let dt=time-time_old
		counter_list.push(dt)
		floor_time = Math.floor(time/1000)
		if( last_mean < floor_time){
			mean = counter_list.reduce((a, b) => a + b, 0)/counter_list.length;
			COUNTER.innerHTML = Math.round(mean*100)/100
			last_mean = floor_time
			counter_list.length = 0
		}
		time_old=time

		GL.viewport(0.0, 0.0, CANVAS.width, CANVAS.height)
		GL.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT)

		GL.uniform2f(screen_size_in, CANVAS.width, CANVAS.height)
		GL.uniform1f(global_time, time/1000)

		GL.uniform1f(uni_min_re, min_re)
		GL.uniform1f(uni_max_re, max_re)
		GL.uniform1f(uni_min_im, min_im)
		GL.uniform1f(uni_max_im, max_im)

		GL.bindBuffer(GL.ARRAY_BUFFER, vertex_buffer)
		GL.vertexAttribPointer(coord, 3, GL.FLOAT, false, 0, 0)
		GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, index_buffer)

		GL.drawElements(GL.TRIANGLES, indices.length, GL.UNSIGNED_SHORT,0)

		GL.flush()

		window.requestAnimationFrame(animate)
	}
	animate(0)
}
