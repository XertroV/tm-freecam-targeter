Dev::HookInfo@ g_hook;

auto startTime = Time::Now;

void Main() {
    MLHook::RegisterPlaygroundMLExecutionPointCallback(onMLExec);
    startnew(loopSetShadows).WithRunContext(Meta::RunContext::NetworkAfterMainLoop);
    // startnew(onBeforeScripts).WithRunContext(Meta::RunContext::BeforeScripts);
    // startnew(onAfterScripts).WithRunContext(Meta::RunContext::AfterScripts);
    // startnew(onGameLoop).WithRunContext(Meta::RunContext::GameLoop);
    // startnew(onSceneUpdate).WithRunContext(Meta::RunContext::UpdateSceneEngine);
    // startnew(onMain).WithRunContext(Meta::RunContext::Main);
    // startnew(onAfterMainLoop).WithRunContext(Meta::RunContext::AfterMainLoop);
    // startnew(onMainLoop).WithRunContext(Meta::RunContext::MainLoop);
    // startnew(onNetworkAfterMainLoop).WithRunContext(Meta::RunContext::NetworkAfterMainLoop);

    auto app = cast<CTrackMania>(GetApp());

    return;

// 48 8B 46 28 4D 8D 76 08 48 8B 88 60060000 49 8B 44 0E F8 0F10 80 80010000 0F10 88 90010000 0F11 80 A0010000 0F11 88 B0010000 48 83 EA 01 75 CA 8B 54 24 50 48 8D 4C 24 40 E8 0CDDE9FE 48 83 C4 78 41 5E 5E
    // end of AfterPhsyics
    // auto pattern = "48 8D 4C 24 40 E8 0C DD E9 FE 48 83 C4 78 41 5E 5E";
    // CSmArenaClient::UpdatePhysics
    // auto pattern = "40 55 57 41 54 41 55 41 56 48 8D AC 24 70 FE FF FF 48 81 EC 90 02 00 00";
    // UpdatePlayersInputs -- didn't work
    // Players_EndFrame
    // auto pattern = "44 89 44 24 18 56 41 56 48 83 EC 78 48 8B F1 4C 89 6C 24 68 44 8B EA 48 8D 4C 24 40 45 33 F6";
    // NScenePys::StartFrame
    // auto pattern = "40 55 48 83 EC 40 48 89 5C 24 50 48 8B E9 48 8B DA 48 89 7C 24 60 33 FF";
    // UpdateAsync_PostCameraVisibility -- start and end -> crashes
    // auto pattern = "8B 55 90 48 8D 4D 80 E8 ?? ?? ?? ?? 48 8B 4D B0 48 33 CC";
    // Update2_AfterAnim
    // auto pattern = "4C 8B DC 55 41 56 49 8D AB 68 FC FF FF 48 81 EC 88 04 00 00";
    // Update2_AfterAnim in for loop
    auto pattern = "49 39 79 08 74 19 45 3B FB 0F 83 ?? ?? ?? ?? 41 FF C7 44 89 7C 24 74 41 8D 47 FF 4C 89 0C";
    auto ptr = Dev::FindPattern(pattern);
    print(Text::FormatPointer(ptr));
    @g_hook = Dev::Hook(ptr, 1, "AfterPhysics", Dev::PushRegisters::SSE);

    while (Time::Now - startTime < 1000) {
        yield();
        print('Main ' + Time::Now);
    }
}

void AfterPhysics(uint64 r9) {
    if (Time::Now - startTime > 1000) return;
    print('AfterPhysics ' + GetApp().TimeSinceInitMs);
    print('r9: ' + Text::FormatPointer(r9));
    IO::SetClipboard(Text::FormatPointer(r9));
}

void OnDestroyed() {
    MLHook::UnregisterMLHooksAndRemoveInjectedML();
    visIdToLoad = 0;
    if (g_hook !is null)
        Dev::Unhook(g_hook);
}
void OnDisabled() { OnDestroyed(); }

const string PluginIcon = Icons::Car + Icons::Crosshairs;
const string MenuName = PluginIcon + "\\$z " + Meta::ExecutingPlugin().Name;

[Setting hidden]
bool S_Enabled = false;

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

    UI::SetNextWindowSize(400, 430, UI::Cond::FirstUseEver);
    if (UI::Begin(MenuName, S_Enabled, UI::WindowFlags::NoCollapse)) {
        auto app = GetApp();
        if (app.CurrentPlayground is null || app.GameScene is null) {
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
    // UI::TextWrapped("\\$888" + debugText);
    if (UI::Button("Reset")) {
        visIdToLoad = 0;
    }
}

enum FollowMethod { Target_Only, TargetMode_JustYaw, TargetMode_JustPitchYaw, Locked_PitchYawRoll, XXX_Last }

[Setting hidden]
FollowMethod S_FollowMethod = FollowMethod::TargetMode_JustPitchYaw;

[Setting hidden]
float S_FollowDist = 15.0;

[Setting hidden]
float S_FollowVAngle = 20;

[Setting hidden]
float S_FollowFov = 75;

[Setting hidden]
vec3 S_FollowOffset = vec3(0, 2, 2);

void DrawOptions() {
    S_FollowMethod = DrawComboFollowMethod("Follow Method", S_FollowMethod);
    S_FollowDist = UI::SliderFloat("Follow Distance", S_FollowDist, 1.0, 100.0, "%.1f");
    S_FollowVAngle = UI::SliderFloat("Follow V Angle", S_FollowVAngle, -90., 90.0, "%.1f");
    S_FollowFov = UI::SliderFloat("Follow FoV", S_FollowFov, 10., 150.0, "%.1f");
    S_FollowOffset = UI::SliderFloat3("Follow Offset (x,y,z)", S_FollowOffset, -10., 10., "%.1f");

    auto cam = GetFreeCamControls(GetApp());
    if (cam is null) return;

    UI::Separator();

    cam.m_TargetIsEnabled = UI::Checkbox("TargetIsEnabled", cam.m_TargetIsEnabled);
    cam.m_TargetPos = UI::InputFloat3("Target Position", cam.m_TargetPos);
    cam.m_FreeVal_Loc_Translation = UI::InputFloat3("Non-target Position", cam.m_FreeVal_Loc_Translation);
    cam.m_Fov = UI::SliderFloat("FoV", cam.m_Fov, 10., 150., "%.1f");
    UI::Text("Pos: " + cam.Pos.ToString());
    // cam.m_Pitch = UI::SliderFloat("Pitch", cam.m_Pitch, 10., 150., "%.1f");
    // cam.m_Yaw = UI::SliderFloat("Yaw", cam.m_Yaw, 10., 150., "%.1f");
    // cam.m_Roll = UI::SliderFloat("Roll", cam.m_Roll, 10., 150., "%.1f");

    UI::Separator();

    if (UI::Button("Reset FreeCam (if it gets stuck)")) {
        cam.m_TargetPos = vec3(500, 80, 500);
        cam.m_FreeVal_Loc_Translation = vec3(500, 80, 500);
        cam.m_Radius = 30.;
        cam.m_Pitch = 0;
        cam.m_Yaw = 0;
        cam.m_Roll = 0;
        FreeCamSetTargetId(cam, 0, false);
    }
    AddSimpleTooltip("If it repeatedly gets stuck, manually target something with alt + left click in cam7 and try again.");
#if SIG_DEVELOPER
    if (UI::Button(Icons::Cube + " Explore FreeCam Controls Nod")) {
        ExploreNod("FreeCam Controls", cam);
    }
    AddSimpleTooltip("Warning: don't keep this tab open when you leave the map! It can crash the game.");
#endif
}



shared funcdef string EnumToStringF(int);

shared int DrawArbitraryEnum(const string &in label, int val, int nbVals, EnumToStringF@ eToStr) {
    if (UI::BeginCombo(label, eToStr(val))) {
        for (int i = 0; i < nbVals; i++) {
            if (UI::Selectable(eToStr(i), val == i)) {
                val = i;
            }
        }
        UI::EndCombo();
    }
    return val;
}
FollowMethod DrawComboFollowMethod(const string &in label, FollowMethod val) {
    return FollowMethod(
        DrawArbitraryEnum(label, int(val), int(FollowMethod::XXX_Last), function(int v) {
            return tostring(FollowMethod(v));
        })
    );
}





void DrawListPlayers() {
    auto cp = cast<CSmArenaClient>(GetApp().CurrentPlayground);
    if (cp is null) return;
    UI::ListClipper clip(cp.Players.Length);
    while (clip.Step()) {
        for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
            auto player = cast<CSmPlayer>(cp.Players[i]);
            auto visId = Dev::GetOffsetUint32(player, GetOffset(player, "EdClan") + 0x4c);
            bool noVis = visId == 0x0FF00000; // || player.SpawnIndex < 0;
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
    if (mgr is null) return;
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



// GetPerformance
uint logged = 0;
void onMLExec(ref@ p) {
        auto vp = GetApp().Viewport;
        vp.RenderShadows = 0;

    if (logged < 2) {
        logged++;
        trace('onMLExec ' + Time::Now);
    }
    SetCameraVisIdTarget();
}

void onBeforeScripts() {
    while (true) {
        callbackLog("onBeforeScripts");
        yield();
        SetCameraVisIdTarget();
    }
}
void onAfterScripts() {
    while (true) {
        callbackLog("onAfterScripts");
        yield();
        SetCameraVisIdTarget();
    }
}
void onSceneUpdate() {
    while (true) {
        callbackLog("onSceneUpdate");
        yield();
        SetCameraVisIdTarget();
    }
}
void onMain() {
    while (true) {
        callbackLog("onMain");
        yield();
        SetCameraVisIdTarget();
    }
}
void onGameLoop() {
    while (true) {
        callbackLog("onGameLoop");
        yield();
        SetCameraVisIdTarget();
    }
}
void onAfterMainLoop() {
    while (true) {
        callbackLog("onAfterMainLoop");
        yield();
        SetCameraVisIdTarget();
    }
}
void onMainLoop() {
    while (true) {
        callbackLog("onMainLoop");
        yield();
        SetCameraVisIdTarget();
    }
}

void loopSetShadows() {
    while (true) {
        yield();
        auto vp = GetApp().Viewport;
        vp.RenderShadows = 0;
    }
}
void onNetworkAfterMainLoop() {
    while (true) {
        callbackLog("onNetworkAfterMainLoop");
        yield();
        SetCameraVisIdTarget();
    }
}

Json::Value@ namedCbCounter = Json::Object();
void callbackLog(const string &in name) {
    int count = namedCbCounter.Get(name, 0);
    if (count < 3) {
        trace(tostring(Time::Now) + " Callback Context: " + name);
        namedCbCounter[name] = count + 1;
    }
}

void SetCameraVisIdTarget() {
    CMwNod@ gamecam;
    if (visIdToLoad > 0 && visIdToLoad != 0x0FF00000 && (@gamecam = GetGameCameraNod(GetApp())) !is null) {
        // vehicle id for drawing (shadows; not setting this makes player invis)
        Dev::SetOffset(gamecam, 0x44, visIdToLoad);
        // Dev::SetOffset(gamecam, 0x44 + 0x18, visIdToLoad);
        // Dev::SetOffset(gamecam, 0x44 + 0x98, visIdToLoad);

        // these changed
        // vehicle id to target
        // Dev::SetOffset(gamecam, 0x48, visIdToLoad);
        // vehicle id something to do with motion blur calcs or something
        // Dev::SetOffset(gamecam, 0x4c, visIdToLoad);



        // these are all vehicle ent ids, but don't seem to do much
        // Dev::SetOffset(gamecam, 0xc4, visIdToLoad);
        // Dev::SetOffset(gamecam, 0x2a0, visIdToLoad);
        // Dev::SetOffset(gamecam, 0x29c, visIdToLoad);
        // Dev::SetOffset(gamecam, 0x5a0, visIdToLoad);
        // Dev::SetOffset(gamecam, 0x59c, visIdToLoad);

        // auto forcedCam = Dev::GetOffsetNod(gamecam, 0xd0);
        // if (forcedCam !is null)
        //     Dev::SetOffset(forcedCam, 0x0, visIdToLoad);
    } else {
        visIdToLoad = 0;
    }
}

enum CamChoice {
    Cam1, Cam1Alt,
    Cam2, Cam2Alt,
    Cam3, Cam3Alt,
    Cam7, Cam7Drivable,
    CamBackwards,
}


void RunSetFreeCamTargetToChosen() {
    // auto status = GetCameraStatus();
    SetCamChoice(CamChoice::Cam7);
    yield();
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
        while ((@cam = GetFreeCamControls(GetApp())) !is null) {
            /**
             * Hmm, wrt angles:
             * while in drivable cam7, we cannot update the free cam outside of target mode (then just PY)
             * while in nondrivable cam7, target mode: only PY, non-target: PYR
             */
            cam.m_TargetIsEnabled = S_FollowMethod < FollowMethod::Locked_PitchYawRoll;
            cam.m_RelativeFollowedPos = S_FollowOffset;
            cam.m_ClampPitch = false;
            cam.m_Fov = S_FollowFov;
            debugText = "";
            auto visId = FreeCamGetTargetId(cam);
            lastVisIdFollowing = visId;
            auto vis = FindVisById(visId);
            cam.m_RelativeFollowedPos = S_FollowOffset;
            cam.m_Radius = S_FollowDist;
            debugText += vis.AsyncState.Left.ToString() + "\n" + vis.AsyncState.Up.ToString() + "\n" + vis.AsyncState.Dir.ToString();
            auto rotExtra = (mat4::Rotate(Math::ToRad(S_FollowVAngle), vis.AsyncState.Left));
            // auto rotExtra = mat4::Identity();
            auto camDir = (rotExtra * vis.AsyncState.Dir).xyz;
            auto camUp = (rotExtra * vis.AsyncState.Up).xyz;
            auto left = vis.AsyncState.Left;
            auto rot = mat4(
                vec4(left, 0),
                vec4(camUp, 0),
                vec4(camDir, 0),
                vec4(0, 0, 0, 1)
            );
            auto targetPos = vis.AsyncState.Position + (rot * S_FollowOffset).xyz;
            cam.m_TargetPos = targetPos;
            auto pos = targetPos + camDir * S_FollowDist * -1.;
            auto camAngles = PitchYawRollFromRotationMatrix(rot);

            if (S_FollowMethod > FollowMethod::Target_Only) {
                cam.m_Yaw = camAngles.y;
            }
            if (S_FollowMethod > FollowMethod::TargetMode_JustYaw) {
                cam.m_Pitch = Math::Abs(camAngles.x);
                if (S_FollowMethod > FollowMethod::TargetMode_JustPitchYaw) {
                    cam.m_Pitch = camAngles.x;
                    cam.m_Roll = camAngles.z;
                }
            }
            cam.m_FreeVal_Loc_Translation = pos;
            // nvg::Reset();
            // nvgDrawCoordHelpers(vis.AsyncState.Position, vis.AsyncState.Left, vis.AsyncState.Up, vis.AsyncState.Dir);
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
    bool drivable = cam == CamChoice::Cam7Drivable;
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

shared void AddSimpleTooltip(const string &in msg) {
    if (UI::IsItemHovered()) {
        UI::SetNextWindowSize(400, 0, UI::Cond::Appearing);
        UI::BeginTooltip();
        UI::TextWrapped(msg);
        UI::EndTooltip();
    }
}
