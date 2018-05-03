precision highp float;

uniform sampler2D image1;
uniform vec2 screen_size_in;
const mat3 kernel = mat3(
    vec3(1.0/14.0, 2.0/14.0, 1.0/14.0),     // 1st column
    vec3(2.0/14.0, 2.0/14.0, 2.0/14.0), // 2nd column
    vec3(1.0/14.0, 2.0/14.0, 1.0/14.0)      // 3rd column
);

//TODO two passes gaussian
void main(void) {
    vec2 pix = vec2(1.)/screen_size_in; //pixel size
    vec2 pos = gl_FragCoord.xy/screen_size_in;
    vec4 origin_dist = texture2D(image1, pos);
    vec3 color = vec3(0.);

    float center_pix = 1. - 10.1;
    float neigh_pix = (1. - center_pix)/8.;

    color += texture2D(image1, vec2(pos.x - pix.x, pos.y - pix.y)).xyz      * neigh_pix      ;                                           // upper  left
    color += texture2D(image1, vec2(pos.x - pix.x, pos.y)).xyz              * neigh_pix              ;                                   // center left
    color += texture2D(image1, vec2(pos.x - pix.x, pos.y + pix.y)).xyz      * neigh_pix      ;                                           // bottom left
    color += texture2D(image1, vec2(pos.x, pos.y - pix.y)).xyz              * neigh_pix              ;                                   // upper  center
    color += texture2D(image1, pos).xyz                                     * center_pix               ;               // center center
    color += texture2D(image1, vec2(pos.x, pos.y + pix.y)).xyz              * neigh_pix              ;                                   // bottom center
    color += texture2D(image1, vec2(pos.x + pix.x, pos.y - pix.y)).xyz      * neigh_pix      ;                                           // upper  right
    color += texture2D(image1, vec2(pos.x + pix.x, pos.y)).xyz              * neigh_pix              ;                                   // center right
    color += texture2D(image1, vec2(pos.x + pix.x, pos.y + pix.y)).xyz      * neigh_pix      ;                                           // bottom right

    gl_FragColor = vec4(color.xyz, 1.0);
}
