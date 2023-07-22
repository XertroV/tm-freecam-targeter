class CameraStatus {
    bool isAlt;
    bool canDrive;
    uint currCam;
    CameraStatus(bool isAlt, bool canDrive, uint currCam) {
        this.isAlt = isAlt;
        this.canDrive = canDrive;
        this.currCam = currCam;
    }
    CameraStatus() {}
}

CameraStatus@ GetCameraStatus() {
    auto gt = GetGameTerminal(GetApp());
    if (gt is null) return CameraStatus();
	bool alt = Dev::GetOffsetUint16(gt, 0x30) == 0x0;
	auto canDrive = Dev::GetOffsetUint32(gt, 0x60) == 0x0;
	auto currCam = Dev::GetOffsetUint32(gt, 0x34);
    return CameraStatus(alt, canDrive, currCam);
}

CGameTerminal@ GetGameTerminal(CGameCtnApp@ app) {
	if (app.CurrentPlayground is null) return null;
	if (app.CurrentPlayground.GameTerminals.Length == 0) return null;
	auto gt = app.CurrentPlayground.GameTerminals[0];
    return gt;
}

void SetAltCamFlag(CGameCtnApp@ app, bool isAlt) {
    auto gt = GetGameTerminal(app);
    if (gt is null) return;
    Dev::SetOffset(gt, 0x30, isAlt ? 0x1 : 0x0);
}

void SetDrivableCamFlag(CGameCtnApp@ app, bool canDrive) {
    auto gt = GetGameTerminal(app);
    if (gt is null) return;
    Dev::SetOffset(gt, 0x60, canDrive ? 0x0 : 0x1);
}

// crashes on 0x8, 0x9, and 0x1e or greater
// 3,4,5,6 are some kind of default cams where you need to toggle free cam drivable to drive
enum CameraType {
    FreeCam = 0x2,
    WeirdDefault = 0x5,
    Intro7Mb = 0x7,
    Intro10Mb = 0x10,
    FreeCam2 = 0x11,
    Cam1 = 0x12,
    Cam2 = 0x13,
    Cam3 = 0x14,
    Backwards = 0x15,
    Intro16Mb = 0x16,
    // same repeated up to 0x1d
    // Intro1dMb = 0x1d,
}

void SetCamType(CGameCtnApp@ app, CameraType cam) {
    auto gt = GetGameTerminal(app);
    if (gt is null) return;
	auto setCamNod = Dev::GetOffsetNod(gt, 0x50);
    Dev::SetOffset(setCamNod, 0x4, uint(cam));
}
