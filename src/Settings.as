[Setting category="General" name="Enabled"]
bool S_Enabled = false;

[Setting category="General" name="Randomize Period (seconds)"]
float S_RandomizePeriod = 5.0;

enum CamChoice {
    Cam1, Cam1Alt,
    Cam2, Cam2Alt,
    Cam3, Cam3Alt,
    Cam7, Cam7Drivable,
    CamBackwards,
}

[Setting category="General" name="Include Cam 1"]
bool S_Cam1 = true;
[Setting category="General" name="Include Cam 1 Alt"]
bool S_Cam1Alt = true;
[Setting category="General" name="Include Cam 2"]
bool S_Cam2 = true;
[Setting category="General" name="Include Cam 2 Alt"]
bool S_Cam2Alt = true;
[Setting category="General" name="Include Cam 3"]
bool S_Cam3 = true;
[Setting category="General" name="Include Cam 3 Alt"]
bool S_Cam3Alt = true;
[Setting category="General" name="Include Cam 7"]
bool S_Cam7 = false;
[Setting category="General" name="Include Cam 7 Drivable"]
bool S_Cam7Drivable = false;
[Setting category="General" name="Include Backwards Cam"]
bool S_CamBackwards = false;
