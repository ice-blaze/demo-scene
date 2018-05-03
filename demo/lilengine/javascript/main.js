var canvas_play = true
var animate = undefined
var first_loop = 0

const main=function() {
  const CANVAS=document.getElementById("demo_canvas")
  const COUNTER=document.getElementById("counter")
  CANVAS.width = 320
  CANVAS.height = 240

  let GL
  try {
    GL = CANVAS.getContext("experimental-webgl", {antialias: true})
  } catch (e) {
    alert("You are not webgl compatible :(")
    return false
  }

  const vertices = [
    -.4,-.4, 0.0,
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

  const create_framebuffer = function(width, height){
    // Framebuffer part
    let buffer = GL.createFramebuffer();
    GL.bindFramebuffer(GL.FRAMEBUFFER, buffer);
    buffer.width = width;
    buffer.height = height;
    let texture = GL.createTexture();
    GL.bindTexture(GL.TEXTURE_2D, texture);
    GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
    GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
    GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
    GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
    GL.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, buffer.width, buffer.height, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);
    GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, texture, 0);
    GL.bindTexture(GL.TEXTURE_2D, null);
    GL.bindFramebuffer(GL.FRAMEBUFFER, null);

    return {buffer:buffer, texture:texture}
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
  const MANDELBOX_PROGRAM=GL.createProgram()
  GL.attachShader(MANDELBOX_PROGRAM, shader_vertex)
  GL.attachShader(MANDELBOX_PROGRAM, shader_fragment)
  GL.linkProgram(MANDELBOX_PROGRAM)

  let bufftex = create_framebuffer(CANVAS.width, CANVAS.height)

  let screen_size_in
  let global_time
  let coord

  let time_old=0
  let counter_list = []
  let last_mean = 0

  let temp_var


  animate=function(time) {
    window.requestAnimationFrame(animate)
    if(!canvas_play && first_loop>1){ //need to do two times the loop for an image
      COUNTER.innerHTML = 0
      return
    }

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

    const draw_mandlebox = function(){
      // Pass the screen size to the shaders as uniform and quad coordinates as attribute
      screen_size_in = GL.getUniformLocation(MANDELBOX_PROGRAM, "screen_size_in")
      global_time = GL.getUniformLocation(MANDELBOX_PROGRAM, "global_time_in")
      coord = GL.getAttribLocation(MANDELBOX_PROGRAM, "coordinates")
      GL.enableVertexAttribArray(coord)

      GL.viewport(0.0, 0.0, CANVAS.width, CANVAS.height)
      GL.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT)

      GL.uniform2f(screen_size_in, CANVAS.width, CANVAS.height)
      GL.uniform1f(global_time, time/1000)

      GL.bindBuffer(GL.ARRAY_BUFFER, vertex_buffer)
      GL.vertexAttribPointer(coord, 3, GL.FLOAT, false, 0, 0)
      GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, index_buffer)

      GL.drawElements(GL.TRIANGLES, indices.length, GL.UNSIGNED_SHORT,0)
      GL.flush()
    }

    GL.useProgram(MANDELBOX_PROGRAM)

    GL.bindFramebuffer(GL.FRAMEBUFFER, null)

    draw_mandlebox()

    first_loop++;
  }
  animate(0)
}
