attribute vec3 coordinates;
uniform vec2 screen_size_in;
uniform float global_time_in;
varying vec2 vScreenSize;
varying float vGlobalTime;

void main(void) {
  vScreenSize = screen_size_in;
  vGlobalTime = global_time_in;
  gl_Position = vec4(coordinates, 1.0);
}
