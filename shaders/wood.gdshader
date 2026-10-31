shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(0.58, 0.36, 0.20, 1.0);
varying vec3 local_pos;
void vertex() { local_pos = VERTEX; }
void fragment() {
    float grain = sin(local_pos.z * 110.0 + sin(local_pos.x * 2.2) * 3.0);
    float grain2 = sin(local_pos.z * 261.0 + sin(local_pos.x * 4.0));
    ALBEDO = tint.rgb * (0.96 + 0.025 * grain + 0.017 * grain2);
    ROUGHNESS = 0.78;
}
