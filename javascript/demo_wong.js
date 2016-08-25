var main=function() {
  var CANVAS=document.getElementById("demo_canvas");
  CANVAS.width=window.innerWidth;
  CANVAS.height=window.innerHeight;

  var GL;
  try {
    GL = CANVAS.getContext("experimental-webgl", {antialias: true});
  } catch (e) {
    alert("You are not webgl compatible :(");
    return false;
  }

  const vertices = [
    -1.0,-1.0, 0.0,
     1.0, 1.0, 0.0,
    -1.0, 1.0, 0.0,
     1.0,-1.0, 0.0,
  ];
  const indices = [0,1,2,0,1,3];

  const get_shader=function(source, type, typeString) {
    const shader = GL.createShader(type);
    GL.shaderSource(shader, source);
    GL.compileShader(shader);
    if (!GL.getShaderParameter(shader, GL.COMPILE_STATUS)) {
      alert("ERROR IN "+typeString+ " SHADER : " + GL.getShaderInfoLog(shader));
      return false;
    }
    return shader;
  };

  // Link the vertex and fragment shader
  const vertex_buffer = GL.createBuffer();
  GL.bindBuffer(GL.ARRAY_BUFFER, vertex_buffer);
  GL.bufferData(GL.ARRAY_BUFFER, new Float32Array(vertices), GL.STATIC_DRAW);
  const index_buffer = GL.createBuffer();
  GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, index_buffer);
  GL.bufferData(GL.ELEMENT_ARRAY_BUFFER, new Uint16Array(indices), GL.STATIC_DRAW);

  const shader_vertex=get_shader(shader_vertex_source, GL.VERTEX_SHADER, "VERTEX");
  const shader_fragment=get_shader(shader_fragment_source, GL.FRAGMENT_SHADER, "FRAGMENT");

  const SHADER_PROGRAM=GL.createProgram();
  GL.attachShader(SHADER_PROGRAM, shader_vertex);
  GL.attachShader(SHADER_PROGRAM, shader_fragment);
  GL.linkProgram(SHADER_PROGRAM);
  GL.useProgram(SHADER_PROGRAM);

  // Pass the screen size to the shaders as uniform and quad coordinates as attribute
  const screen_size_in = GL.getUniformLocation(SHADER_PROGRAM, "screen_size_in");
  const global_time = GL.getUniformLocation(SHADER_PROGRAM, "global_time_in");
  const coord = GL.getAttribLocation(SHADER_PROGRAM, "coordinates");
  GL.enableVertexAttribArray(coord);

  var time_old=0;
  var animate=function(time) {
    var dt=time-time_old;
    time_old=time;

    GL.viewport(0.0, 0.0, CANVAS.width, CANVAS.height);
    GL.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);

    GL.uniform2f(screen_size_in, CANVAS.width, CANVAS.height);
    GL.uniform1f(global_time, time_old/1000);

    GL.bindBuffer(GL.ARRAY_BUFFER, vertex_buffer);
    GL.vertexAttribPointer(coord, 3, GL.FLOAT, false, 0, 0);
    GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, index_buffer);

    GL.drawElements(GL.TRIANGLES, indices.length, GL.UNSIGNED_SHORT,0);

    GL.flush();

    window.requestAnimationFrame(animate);
  };
  animate(0);
};
