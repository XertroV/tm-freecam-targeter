
bool nvgWorldPosLastVisible = false;
vec3 nvgLastWorldPos = vec3();

const vec4 cMagenta = vec4(1, 0, 1, 1);
const vec4 cCyan =  vec4(0, 1, 1, 1);
const vec4 cGreen = vec4(0, 1, 0, 1);
const vec4 cBlue =  vec4(0, 0, 1, 1);
const vec4 cRed =   vec4(1, 0, 0, 1);
const vec4 cBlack =  vec4(0,0,0, 1);
const vec4 cGray =  vec4(.5, .5, .5, 1);
const vec4 cWhite = vec4(1);

void nvgDrawCoordHelpers(mat4 &in m, float size = 10.) {
    vec3 pos =  (m * vec3()).xyz;
    vec3 up =   (m * (vec3(0,1,0))).xyz;
    vec3 left = (m * (vec3(1,0,0))).xyz;
    vec3 dir =  (m * (vec3(0,0,1))).xyz;
    nvgDrawCoordHelpers(pos, left, up, dir, size);
}

void nvgDrawCoordHelpers(vec3 pos, vec3 left, vec3 up, vec3 dir, float size = 10.) {
    vec3 beforePos = nvgLastWorldPos;
    nvgMoveToWorldPos(pos);
    nvgToWorldPos(pos + up * size, cGreen);
    nvgMoveToWorldPos(pos);
    nvgToWorldPos(pos + dir * size, cBlue);
    nvgMoveToWorldPos(pos);
    nvgToWorldPos(pos + left * size, cRed);
    nvgMoveToWorldPos(beforePos);
}

void nvgMoveToWorldPos(vec3 pos) {
    nvgLastWorldPos = pos;
    auto uv = Camera::ToScreen(pos);
    if (uv.z > 0) {
        nvgWorldPosLastVisible = false;
        return;
    }
    nvg::MoveTo(uv.xy);
    nvgWorldPosLastVisible = true;
}

void nvgToWorldPos(vec3 &in pos, vec4 &in col = vec4(1)) {
    nvgLastWorldPos = pos;
    auto uv = Camera::ToScreen(pos);
    if (uv.z > 0) {
        nvgWorldPosLastVisible = false;
        return;
    }
    if (nvgWorldPosLastVisible)
        nvg::LineTo(uv.xy);
    else
        nvg::MoveTo(uv.xy);
    nvgWorldPosLastVisible = true;
    nvg::StrokeColor(col);
    nvg::Stroke();
    nvg::ClosePath();
    nvg::BeginPath();
    nvg::MoveTo(uv.xy);
}
