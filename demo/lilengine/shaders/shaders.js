// Load synchronously the shaders. It's slower(0.5s) but code is more readable

function loadTextFile(url) {
  const request = new XMLHttpRequest()
  request.open('GET', url, false)
  request.send()
  return request.responseText
}

const shader_fragment_source = loadTextFile("shaders/fragment_shader.glsl");
const shader_vertex_source = loadTextFile("shaders/vertex_shader.glsl");
