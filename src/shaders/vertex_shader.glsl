attribute vec3 coordinates;
uniform vec2 screen_size_in;
uniform float global_time_in;
varying vec2 screen_size_out;
varying float global_time_out;

void main(void) {
  screen_size_out = screen_size_in;
  global_time_out = global_time_in;
  gl_Position = vec4(coordinates, 1.0);
}
