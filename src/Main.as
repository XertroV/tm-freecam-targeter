void Main() {
}
void OnDestroyed() { }
void OnDisabled() { OnDestroyed(); }

const string PluginIcon = Icons::Car + Icons::Crosshairs;
const string MenuName = PluginIcon + "\\$z " + Meta::ExecutingPlugin().Name;

/** Render function called every frame intended only for menu items in `UI`.
*/
void RenderMenu() {
    if (UI::MenuItem(MenuName, "", S_Enabled)) {
        S_Enabled = !S_Enabled;
    }
}

// [Setting hidden]
// bool ShowWindow = true;

void Render() {
    if (!S_Enabled) return;
    // if (!ShowWindow) return;

    UI::SetNextWindowSize(300, 400, UI::Cond::Appearing);
    if (UI::Begin(MenuName, S_Enabled, UI::WindowFlags::NoCollapse)) {
        auto app = GetApp();
        if (app.CurrentPlayground is null) {
            UI::Text("Please load a map.");
            UI::End();
            return;
        }

        UI::BeginTabBar("tb");
        if (UI::BeginTabItem("About")) {
            DrawAbout();
            UI::EndTabItem();
        }
        if (UI::BeginTabItem("Options")) {
            DrawOptions();
            UI::EndTabItem();
        }
        if (UI::BeginTabItem("Players")) {
            if (UI::BeginChild("Players")) {
                DrawListPlayers();
            }
            UI::EndChild();
            UI::EndTabItem();
        }
        if (UI::BeginTabItem("Ghosts")) {
            if (UI::BeginChild("Ghosts")) {
                DrawListGhosts();
            }
            UI::EndChild();
            UI::EndTabItem();
        }
        UI::EndTabBar();
    }
    UI::End();
}


void DrawAbout() {
    UI::TextWrapped("Clicking a player/ghost will change to Cam 7 in targeted mode focused on your selection.");
    UI::TextWrapped("Cam 7 has 2 modes: normal, and drivable. (Changing to cam7 multiple times will toggle beween these modes.)");
    UI::TextWrapped("In normal mode: alt + left click to target a player/ghost. alt + right click to exit targeted mode.");
    UI::Separator();
    UI::TextWrapped("\\$888Following Vis ID: " + Text::Format("%08x", lastVisIdFollowing));
    UI::TextWrapped("\\$888" + debugText);
}

[Setting hidden]
bool S_FollowWhenTargeted = false;

[Setting hidden]
float S_FollowDist = 15.0;

[Setting hidden]
float S_FollowVAngle = 20;

[Setting hidden]
vec3 S_FollowOffset = vec3(0, 2, 0);

void DrawOptions() {
    S_FollowWhenTargeted = UI::Checkbox("Lock Camera to Target", S_FollowWhenTargeted);
    S_FollowDist = UI::SliderFloat("Follow Distance", S_FollowDist, 1.0, 100.0, "%.1f");
    S_FollowVAngle = UI::SliderFloat("Follow V Angle", S_FollowVAngle, -90., 90.0, "%.1f");
    S_FollowOffset = UI::SliderFloat3("Follow Offset (x,y,z)", S_FollowOffset, -10., 10., "%.1f");
}


void DrawListPlayers() {
    CSmPlayer@ player;
    auto cp = cast<CSmArenaClient>(GetApp().CurrentPlayground);
    UI::ListClipper clip(cp.Players.Length);
    while (clip.Step()) {
        for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
            auto player = cast<CSmPlayer>(cp.Players[i]);
            auto visId = Dev::GetOffsetUint32(player, GetOffset(player, "EdClan") + 0x4c);
            bool noVis = visId == 0x0FF00000 || player.SpawnIndex < 0;
            UI::BeginDisabled(noVis);
            if (UI::Button("" + i + ". ["+Text::Format("%08x", visId)+"] " + player.ScriptAPI.User.Name)) {
                visIdToLoad = visId;
                startnew(RunSetFreeCamTargetToChosen);
            }
            UI::EndDisabled();
        }
    }
}

uint visIdToLoad;

void DrawListGhosts() {
    auto mgr = GhostClipsMgr::Get(GetApp());
    UI::ListClipper clip(mgr.Ghosts.Length);
    while (clip.Step()) {
        for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
            auto @g = mgr.Ghosts[i];
            auto visId = Dev::GetOffsetUint32(g, 0x0);
            bool noVis = visId == 0x0FF00000;
            UI::BeginDisabled(noVis);
            if (UI::Button("" + i + ". ["+Text::Format("%08x", visId)+"] " + g.GhostModel.GhostNickname + " (" + Time::Format(g.GhostModel.RaceTime) + ")")) {
                visIdToLoad = visId;
                startnew(RunSetFreeCamTargetToChosen);
            }
            UI::EndDisabled();
        }
    }
}

void RunSetFreeCamTargetToChosen() {
    auto status = GetCameraStatus();
    if (status.currCam != uint(CameraType::FreeCam)) {
        SetCamChoice(CamChoice::Cam7);
        yield();
    }
    auto cam = GetFreeCamControls(GetApp());
    if (cam is null) {
        UI::ShowNotification("Failed to get camera free :(");
    } else {
        FreeCamSetTargetId(cam, visIdToLoad);
        // radius defaults to 0 which is not a great experience
        cam.m_Radius = 40;
        startnew(FollowCamTargetLoop);
    }
}

bool followLoopRunning = false;
uint lastVisIdFollowing;

string debugText;

void FollowCamTargetLoop() {
    if (followLoopRunning) return;
    followLoopRunning = true;
    try {
        auto cam = GetFreeCamControls(GetApp());
        while (S_FollowWhenTargeted && (@cam = GetFreeCamControls(GetApp())) !is null) {
            cam.m_TargetIsEnabled = false;
            cam.m_ClampPitch = false;
            debugText = "";
            auto visId = FreeCamGetTargetId(cam);
            lastVisIdFollowing = visId;
            auto vis = FindVisById(visId);
            cam.m_TargetPos = vis.AsyncState.Position;
            cam.m_RelativeFollowedPos = S_FollowOffset;
            cam.m_Radius = S_FollowDist;
            // vis.AsyncState.WorldCarUp;
            // vis.AsyncState.WorldVel;
            debugText += vis.AsyncState.Left.ToString() + "\n" + vis.AsyncState.Up.ToString() + "\n" + vis.AsyncState.Dir.ToString();
            auto rotExtra = mat4::Inverse(mat4::Rotate(Math::ToRad(S_FollowVAngle), vis.AsyncState.Left));
            // auto rotExtra = mat4::Identity();
            auto camDir = (rotExtra * vis.AsyncState.Dir).xyz;
            auto camUp = (rotExtra * vis.AsyncState.Up).xyz;
            auto left = vis.AsyncState.Left;
            auto rot = mat4(
                // vec4(left.x, camUp.x, camDir.x, 0),
                // vec4(left.y, camUp.y, camDir.z, 0),
                // vec4(left.z, camUp.z, camDir.y, 0),
                vec4(left, 0),
                vec4(camUp, 0),
                vec4(camDir, 0),
                vec4(0, 0, 0, 1)
            );
            // auto camAngles = DirToAngles(camDir, camUp, vis.AsyncState.Left);
            auto pos = vis.AsyncState.Position + camDir * S_FollowDist * -1.;
            auto camAngles = PitchYawRollFromRotationMatrix(rot);
            // cam.m_Pitch = 0.2;
            cam.m_Pitch = camAngles.x + 0.05; // + Math::ToRad(S_FollowVAngle);
            // cam.m_Pitch *= -1.;
            cam.m_Yaw = camAngles.y;
            // cam.m_Yaw *= -1.;
            cam.m_Roll = camAngles.z;
            cam.m_FreeVal_Loc_Translation = pos;
            nvg::Reset();
            nvgDrawCoordHelpers(vis.AsyncState.Position, vis.AsyncState.Left, vis.AsyncState.Up, vis.AsyncState.Dir);
            yield();
        }
    } catch {
        warn("Exception in FollowCamTargetLoop: " + getExceptionInfo());
    }
    followLoopRunning = false;
    trace('follow loop ended');
}


// from threejs Euler.js -- order XZY then *-1 at the end
shared vec3 PitchYawRollFromRotationMatrix(mat4 m) {
    float m11 = m.xx, m12 = m.xy, m13 = m.xz,
          m21 = m.yx, m22 = m.yy, m23 = m.yz,
          m31 = m.zx, m32 = m.zy, m33 = m.zz
    ;
    vec3 e = vec3();
    e.z = Math::Asin( - Math::Clamp( m12, -1.0, 1.0 ) );
    if ( Math::Abs( m12 ) < 0.9999999 ) {
        e.x = Math::Atan2( m32, m22 );
        e.y = Math::Atan2( m13, m11 );
    } else {
        e.x = Math::Atan2( - m23, m33 );
        e.y = 0;
    }
    return e * -1.;
}


vec3 DirToAngles(vec3 dir, vec3 up, vec3 left) {
    vec3 e = vec3();
    e.z = Math::Asin( - Math::Clamp( up.x, -1.0, 1.0 ) );
    if ( Math::Abs( up.x ) < 0.9999999 ) {
        e.x = Math::Atan2( up.z, up.y );
        e.y = Math::Atan2( dir.x, left.x );
    } else {
        e.x = Math::Atan2( - dir.y, dir.z );
        e.y = 0;
    }
    return e * -1.;

}

CSceneVehicleVis@ FindVisById(uint visId) {
    auto gs = GetApp().GameScene;
    // NSceneVehicleVis_SMgr@ mgr = Dev::ForceCast<NSceneVehicleVis_SMgr@>(Dev::GetOffsetNod(gs, 0x70)).Get();
    auto allVis = VehicleState::GetAllVis(gs);
    for (uint i = 0; i < allVis.Length; i++) {
        if (Dev::GetOffsetUint32(allVis[i], 0) == visId) {
            return allVis[i];
        }
    }
    return null;
}


void SetCamChoice(CamChoice cam) {
    bool alt = cam == CamChoice::Cam1Alt || cam == CamChoice::Cam2Alt || cam == CamChoice::Cam3Alt;
    bool drivable = cam != CamChoice::Cam7;
    CameraType setTo = cam == CamChoice::Cam1 || cam == CamChoice::Cam1Alt
        ? CameraType::Cam1
        : cam == CamChoice::Cam2 || cam == CamChoice::Cam2Alt
            ? CameraType::Cam2
            : cam == CamChoice::Cam3 || cam == CamChoice::Cam3Alt
                ? CameraType::Cam3
                : cam == CamChoice::Cam7 || cam == CamChoice::Cam7Drivable
                    ? CameraType::FreeCam
                    : cam == CamChoice::CamBackwards
                        ? CameraType::Backwards
                        : CameraType::Cam1
        ;
    auto app = GetApp();
    SetAltCamFlag(app, alt);
    SetDrivableCamFlag(app, drivable);
    SetCamType(app, setTo);
}
